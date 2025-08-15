# main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import logging
import os as _os
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
import itertools
import os
from dotenv import load_dotenv
from config import settings
from tequila_client import fetch_price_for_date
from cache_db import init as init_cache, get as cache_get, set_cache as cache_set, clear_all

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("gelidonia")
try:
    _log_path = _os.path.join(_os.path.dirname(__file__), "server.log")
    _fh = logging.FileHandler(_log_path, encoding="utf-8")
    _fh.setLevel(logging.INFO)
    _fh.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
    logger.addHandler(_fh)
except Exception:
    # file logging is best-effort
    pass

init_cache(settings.CACHE_DB)

app = FastAPI(title="Gelidonia Backend - Kiwi Tequila")

# CORS middleware for web interface
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Web development - you can restrict this in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- Helper models ----------
class RequestPayload(BaseModel):
    start_range_start: str  # YYYY-MM-DD
    start_range_end: str    # YYYY-MM-DD
    trip_length_days: int
    start_airport: str      # IATA code, e.g., IST
    end_airport: Optional[str] = None  # if None, same as start
    cities: List[str]       # list of cities as IATA codes to visit (without start)
    equal_days: bool = True # if true, distribute days equally across cities; else allow flexible
    max_candidates: Optional[int] = 30  # cap number of start dates to try (safety)


# ---------- Utility ----------
def daterange(start_date: datetime, end_date: datetime):
    for n in range(int((end_date - start_date).days) + 1):
        yield start_date + timedelta(n)

def safe_date_parse(s: str):
    return datetime.strptime(s, "%Y-%m-%d")

def build_days_distribution(total_days: int, n_places: int, equal: bool):
    """
    returns list of integers = days per city (length n_places)
    If equal==True: distribute floor/ceil to match total_days.
    If equal==False: produce one reasonable default distribution (first places get +1) — for MVP.
    """
    if n_places <= 0:
        return []
    base = total_days // n_places
    rem = total_days % n_places
    if equal:
        dist = [base + (1 if i < rem else 0) for i in range(n_places)]
        return dist
    else:
        # flexible: give first half slightly longer (simple heuristic)
        dist = [base for _ in range(n_places)]
        i = 0
        # distribute remainder cyclically
        while rem > 0:
            dist[i % n_places] += 1
            i += 1
            rem -= 1
        return dist

def extract_min_price_from_tp_response(tp_resp):
    """
    Travelpayouts v3 returns 'data' list with offer dicts containing 'price'. 
    We'll return the minimum price numeric value; if none, return None.
    """
    if not tp_resp or "data" not in tp_resp:
        return None
    prices = []
    for item in tp_resp.get("data", []):
        try:
            price = item.get("price")
            if isinstance(price, (int, float)):
                prices.append(price)
        except:
            continue
    if not prices:
        return None
    return min(prices)

# ---------- Core route-finding logic ----------
@app.post("/find-route")
def find_route(payload: RequestPayload):
    """
    Main endpoint.
    Steps:
      - iterate candidate start dates between start_range_start and start_range_end
      - for each candidate start date s:
          - create a schedule of dates for each leg based on trip_length_days and distribution
          - for every permutation of cities (visit order), form legs [start -> c1, c1->c2, ..., cN->end]
          - query cached Travelpayouts price for each leg's departure date; sum min prices
      - keep best (lowest total price) across candidates and permutations
    NOTE: This is brute-force and may be slow for many permutations and many start dates. Use max_candidates to limit.
    """
    logger.info("/find-route called with payload=%s", payload.model_dump())
    try:
        start_range_start = safe_date_parse(payload.start_range_start)
        start_range_end = safe_date_parse(payload.start_range_end)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid date format: {e}")

    if payload.end_airport is None:
        payload.end_airport = payload.start_airport

    n_cities = len(payload.cities)
    if n_cities == 0:
        raise HTTPException(status_code=400, detail="At least one city must be provided in 'cities'")

    # Candidate start dates list (cap to max_candidates)
    all_dates = list(daterange(start_range_start, start_range_end))
    # We need that start_date + trip_length_days -1 <= start_range_end
    feasible_starts = []
    for d in all_dates:
        if d + timedelta(days=payload.trip_length_days - 1) <= start_range_end:
            feasible_starts.append(d)
    if not feasible_starts:
        logger.warning("No feasible start dates. start=%s end=%s trip_len=%s", start_range_start, start_range_end, payload.trip_length_days)
        raise HTTPException(status_code=400, detail="No feasible start dates in the given window for trip length")

    # cap candidate count (sample evenly if too many)
    # Cap candidate days hard to limit upstream calls (configurable via env)
    hard_cap = 2
    try:
        hard_cap = int(_os.getenv("MAX_CANDIDATES_HARD_CAP", "2"))
    except Exception:
        hard_cap = 2
    max_cand = min(payload.max_candidates or 30, max(1, hard_cap))
    logger.info("Feasible starts count=%d dates=%s", len(feasible_starts), [d.strftime('%Y-%m-%d') for d in feasible_starts])
    if len(feasible_starts) > max_cand:
        step = max(1, len(feasible_starts)//max_cand)
        feasible_starts = feasible_starts[::step][:max_cand]

    best_overall = None
    alternatives = []

    # Import here to avoid startup crash if optional deps/env are missing
    # --- FORCE TEQUILA CLIENT ---
    try:
        from tequila_client import fetch_price_for_date
        logger.info("Using forced Kiwi Tequila client")
    except ImportError as e:
        logger.error(f"FATAL: Could not import mandatory Tequila client: {e}")
        raise HTTPException(status_code=500, detail=f"Could not load Tequila client: {e}")

    # iterate candidate starts
    for start_dt in feasible_starts:
        # compute days per city
        days_per_city = build_days_distribution(payload.trip_length_days, n_cities, payload.equal_days)
        logger.info("Evaluating candidate start=%s days_per_city=%s perms=%d", start_dt.strftime("%Y-%m-%d"), days_per_city, len(list(itertools.permutations(payload.cities))))
        # for each permutation of visit order
        # Limit permutations if city count is large to avoid explosion
        perms_iter = itertools.permutations(payload.cities)
        if n_cities > 3:
            perms_iter = itertools.islice(perms_iter, 6)
        for perm in perms_iter:
            # build route: start -> perm[0] -> perm[1] -> ... -> perm[-1] -> end
            route = [payload.start_airport] + list(perm) + [payload.end_airport]
            # compute departure dates for each leg
            leg_departure_dates = []
            # initial day: start_dt (we assume user departs on the start_dt morning)
            current_date = start_dt
            # Leg 0: start -> first city on current_date
            leg_departure_dates.append(current_date.strftime("%Y-%m-%d"))
            # Then we stay in city0 for days_per_city[0] days, then fly to city1 on date = current_date + days_per_city[0]
            for i in range(0, n_cities-1):
                current_date = current_date + timedelta(days=days_per_city[i])
                leg_departure_dates.append(current_date.strftime("%Y-%m-%d"))
            # last leg: from last city back to end_airport
            # depart after staying last city's days
            current_date = current_date + timedelta(days=days_per_city[-1])
            # but note: that would be one day after finishing; we want return flight departure date = start_dt + sum(days_per_city)
            # However current_date at this point equals start_dt + sum(days_per_city). That's correct for return leg.
            leg_departure_dates.append(current_date.strftime("%Y-%m-%d"))

            # sanity: len(leg_departure_dates) should be len(route)-1
            if len(leg_departure_dates) != len(route)-1:
                # adjust if mismatch
                # fallback: set all legs the same start date (safer)
                leg_departure_dates = [start_dt.strftime("%Y-%m-%d")] * (len(route)-1)
            logger.info("Route=%s legs=%s", route, leg_departure_dates)

            total_price = 0
            valid = True
            leg_details = []

            # for each leg, fetch price
            for i in range(len(route)-1):
                o = route[i]
                dpt = route[i+1]
                dep_date = leg_departure_dates[i]
                # call pricing client (cached)
                logger.info("Leg fetch start %s-%s %s", o, dpt, dep_date)
                tp_resp = fetch_price_for_date(o, dpt, dep_date)
                logger.info("Leg fetch done %s-%s %s resp_type=%s resp_preview=%s",
                            o, dpt, dep_date, type(tp_resp).__name__,
                            (str(tp_resp)[:240] if tp_resp is not None else None))
                # Support both legacy Travelpayouts-style response and Amadeus simple dict
                min_price = None
                if isinstance(tp_resp, dict) and tp_resp.get("rate_limited"):
                    logger.warning("Rate limited while fetching %s-%s %s; aborting with 503", o, dpt, dep_date)
                    raise HTTPException(status_code=503, detail="Upstream rate limited. Please retry shortly.")
                if isinstance(tp_resp, dict) and "price" in tp_resp:
                    try:
                        min_price = float(tp_resp.get("price"))
                    except Exception:
                        min_price = None
                else:
                    min_price = extract_min_price_from_tp_response(tp_resp)
                if min_price:
                    logger.info("Leg price %s-%s %s = %.2f", o, dpt, dep_date, min_price)
                if min_price is None:
                    logger.info("No price for leg %s-%s on %s; skipping candidate. Raw resp=%s",
                                o, dpt, dep_date, (str(tp_resp)[:240] if tp_resp is not None else None))
                    valid = False
                    # break on missing price - you could instead treat as very expensive
                    break
                total_price += min_price
                # enrich with carrier/duration if available from client
                airline = None
                duration = None
                flight_number = None
                currency = None
                departure_time = None
                flight_link = None
                actual_departure_date = dep_date  # default to requested date
                if isinstance(tp_resp, dict):
                    airline = tp_resp.get("airline")
                    duration = tp_resp.get("duration")
                    flight_number = tp_resp.get("flight_number")
                    currency = tp_resp.get("currency")
                    departure_time = tp_resp.get("departure_time")
                    flight_link = tp_resp.get("flight_link")
                    actual_departure_date = tp_resp.get("actual_departure_date", dep_date)
                leg_details.append({
                    "origin": o,
                    "destination": dpt,
                    "departure_date": dep_date,  # istenen tarih
                    "actual_departure_date": actual_departure_date,  # gerçek tarih
                    "min_price": min_price,
                    "airline": airline,
                    "duration": duration,
                    "flight_number": flight_number,
                    "currency": currency,
                    "departure_time": departure_time,
                    "flight_link": flight_link,
                })

            if not valid:
                continue

            candidate_price = round(total_price, 2)
            if best_overall is None or candidate_price < best_overall["total_price"]:
                if best_overall:
                    alternatives.append(best_overall)
                best_overall = {
                    "route": route,
                    "leg_details": leg_details,
                    "total_price": candidate_price,
                    "start_date": start_dt.strftime("%Y-%m-%d"),
                    "days_per_city": days_per_city
                }
            else:
                # if price close to best (within 20 EUR) or top 5 cheapest, append
                alternatives.append({
                    "route": route,
                    "leg_details": leg_details,
                    "total_price": candidate_price,
                    "start_date": start_dt.strftime("%Y-%m-%d"),
                    "days_per_city": days_per_city
                })

    # sort alternatives by price and limit to 5
    alternatives_sorted = sorted(alternatives, key=lambda x: x["total_price"])[:5]

    if not best_overall:
        logger.warning("No valid routes found. Tried starts=%d cities=%s trip_len=%d", len(feasible_starts), payload.cities, payload.trip_length_days)
        raise HTTPException(status_code=404, detail="No valid routes found within constraints")

    return {
        "best_route": best_overall,
        "alternatives": alternatives_sorted
    }

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/cache/clear")
def clear_cache():
    clear_all()
    return {"status": "ok", "message": "cache cleared"}

@app.post("/cache/disable")
def disable_cache():
    try:
        from .config import settings as _settings
        object.__setattr__(_settings, "DISABLE_CACHE", True)
        return {"status": "ok", "disabled": True}
    except Exception as e:
        return {"status": "error", "error": str(e)}

@app.post("/cache/enable")
def enable_cache():
    try:
        from .config import settings as _settings
        object.__setattr__(_settings, "DISABLE_CACHE", False)
        return {"status": "ok", "disabled": False}
    except Exception as e:
        return {"status": "error", "error": str(e)}

@app.get("/tequila/health")
def tequila_health():
    try:
        from .tequila_client import probe as tequila_probe
        return {"tequila": tequila_probe()}
    except Exception as e:
        return {"ok": False, "error": str(e)}
