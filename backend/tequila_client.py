import time
import logging
import requests
from datetime import datetime, timezone
from collections import deque
from typing import Optional, Dict, Any, Tuple

from config import settings
from cache_db import get as cache_get, set_cache


logger = logging.getLogger("gelidonia")


API_BASE = "https://api.tequila.kiwi.com"
SEARCH_ENDPOINT = f"{API_BASE}/v2/search"
LOCATIONS_ENDPOINT = f"{API_BASE}/locations/query"

# If a RapidAPI key is configured, we will call Kiwi via RapidAPI instead of direct Tequila.
# Host can vary by product. Common examples:
#   kiwi-com-cheap-flights.p.rapidapi.com
#   tequila-kiwi-com.p.rapidapi.com
def _is_rapid() -> bool:
    return bool(getattr(settings, "RAPIDAPI_KEY", None))

def _rapid_headers() -> Dict[str, str]:
    headers: Dict[str, str] = {
        "x-rapidapi-key": settings.RAPIDAPI_KEY,  # type: ignore[arg-type]
        "Accept": "application/json",
    }
    host = getattr(settings, "RAPIDAPI_HOST", None) or "kiwi-com-cheap-flights.p.rapidapi.com"
    headers["x-rapidapi-host"] = host
    return headers

def _rapid_base() -> str:
    host = getattr(settings, "RAPIDAPI_HOST", None) or "kiwi-com-cheap-flights.p.rapidapi.com"
    return f"https://{host}"

def _rapid_search_endpoints() -> Dict[str, str]:
    """Returns a dictionary of endpoint names to their URL paths."""
    return {
        "v2": "/v2/search",
        "legacy": "/search",
        "one_way": "/one-way",
        "round_trip": "/round-trip",
    }

def _rapid_locations_endpoints() -> Dict[str, str]:
    base = _rapid_base()
    return {
        "v2": f"{base}/v2/locations/query",
        "legacy": f"{base}/locations/query",
        "search": f"{base}/locations/search",
    }


def _auth_headers() -> Dict[str, str]:
    if not settings.TEQUILA_API_KEY:
        return {}
    return {
        "apikey": settings.TEQUILA_API_KEY,
        "Accept": "application/json",
    }


def _format_duration_seconds(total_seconds: int) -> Optional[str]:
    if not isinstance(total_seconds, int) or total_seconds <= 0:
        return None
    minutes = total_seconds // 60
    hours = minutes // 60
    mins = minutes % 60
    if mins == 0:
        return f"{hours}h"
    return f"{hours}h {mins}m"


def _deep_find_first(obj: Any, predicate) -> Optional[Dict[str, Any]]:
    """Breadth-first search for first dict in nested obj (dict/list) matching predicate."""
    try:
        queue = deque([obj])
    except Exception:
        return None
    visited = set()
    while queue:
        cur = queue.popleft()
        try:
            obj_id = id(cur)
            if obj_id in visited:
                continue
            visited.add(obj_id)
        except Exception:
            pass
        if isinstance(cur, dict):
            try:
                if predicate(cur):
                    return cur
            except Exception:
                pass
            for v in cur.values():
                if isinstance(v, (dict, list)):
                    queue.append(v)
        elif isinstance(cur, list):
            for v in cur:
                if isinstance(v, (dict, list)):
                    queue.append(v)
    return None

def _deep_get(d: Dict[str, Any], key: str) -> Any:
    """Safely get a value from a nested dictionary."""
    try:
        return d[key]
    except (KeyError, TypeError):
        return None

def _date_to_tequila(date_str: str) -> str:
    # input: YYYY-MM-DD -> DD/MM/YYYY (Tequila expects this format)
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        return dt.strftime("%d/%m/%Y")
    except Exception:
        return date_str

def _date_to_rapidapi_day_of_week(date_str: str) -> str:
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        return dt.strftime("%A").upper()
    except Exception:
        return ""


def _rapid_fetch(origin: str, destination: str, date: str) -> Optional[Tuple[Dict[str, Any], str]]:
    if not _is_rapid():
        return None

    headers = _rapid_headers()
    req_date_obj = datetime.strptime(date, "%Y-%m-%d")

    # Order of preference for endpoints
    endpoints_to_try = _rapid_search_endpoints()

    for endpoint_name, endpoint_path in endpoints_to_try.items():
        url = f"https://{settings.RAPIDAPI_HOST}{endpoint_path}"
        
        # Select the correct parameters based on the endpoint path
        if endpoint_path in ["/v2/search", "/search"]:
            params = {
                "fly_from": f"airport:{origin}",
                "fly_to": f"airport:{destination}",
                "date_from": req_date_obj.strftime("%d/%m/%Y"),
                "date_to": req_date_obj.strftime("%d/%m/%Y"),
                "adults": 1,
                "curr": settings.CURRENCY,
                "locale": "en",
                "limit": 50, # Increased from 5 to get a wider range of results
                "sort": "price",
            }
        else:  # for /one-way and /round-trip
            params = {
                "source": f"airport:{origin}",
                "destination": f"airport:{destination}",
                "outboundDate": req_date_obj.strftime("%Y-%m-%d"),
                "currency": settings.CURRENCY,
                "locale": "en",
                "adults": 1,
                "limit": 50, # Increased from 5
            }

        try:
            logger.info("RapidAPI GET %s url=%s params=%s", endpoint_name, url, str(params))
            resp = requests.get(url, headers=headers, params=params, timeout=15)
            logger.info("RapidAPI endpoint %s status %s", endpoint_name, resp.status_code)
            if resp.status_code == 200:
                resp_json = resp.json()
                # Validate that we got some data
                items_key = "data" if endpoint_path in ["/v2/search", "/search"] else "itineraries"
                if resp_json and resp_json.get(items_key):
                    return resp_json, endpoint_path
                else:
                    logger.warning("RapidAPI endpoint %s returned 200 but no flights in '%s'.", endpoint_name, items_key)
                    # This is a valid response (no flights), so we don't try other endpoints.
                    # We return the empty-but-valid response.
                    return resp_json, endpoint_path

            elif resp.status_code == 404:
                 logger.info("RapidAPI endpoint %s returned 404; trying next", endpoint_name)
                 continue
            else:
                logger.error(
                    "RapidAPI endpoint %s failed with status %d: %s",
                    endpoint_name,
                    resp.status_code,
                    resp.text[:200],
                )
        except requests.exceptions.RequestException as e:
            logger.error("RapidAPI request failed for %s: %s", url, e)
            continue  # Try next endpoint

    logger.warning("All RapidAPI endpoints failed for %s-%s", origin, destination)
    return None


def fetch_price_for_date(origin: str, destination: str, date: str) -> Optional[Dict[str, Any]]:
    """
    Queries Kiwi Tequila v2/search for the cheapest one-way flight on a given date.
    Returns a dict aligned with backend.main expectations:
      price (float), currency (str), airline (str), flight_number (str), duration (str),
      departure_time (str ISO), flight_link (str)
    Results are cached by (origin, destination, date) with provider prefix.
    """

    if not getattr(settings, "DISABLE_CACHE", False):
        cache = cache_get(f"KIW|{origin}", destination, date)
        if cache is not None:
            return cache

    # Must have either RapidAPI credentials or direct Tequila key
    if not _is_rapid() and not settings.TEQUILA_API_KEY:
        logger.warning("No API credentials for Kiwi (RapidAPI or Tequila); returning None")
        return None

    try:
        data = None
        endpoint_path_used = None # Keep track of which endpoint succeeded

        if _is_rapid():
            response_tuple = _rapid_fetch(origin, destination, date)
            if response_tuple:
                data, endpoint_path_used = response_tuple
            else:
                data = None
        else:
            date_fmt = _date_to_tequila(date)
            params = {
                "fly_from": origin,
                "fly_to": destination,
                "date_from": date_fmt,
                "date_to": date_fmt,
                "adults": 1,
                "curr": settings.CURRENCY or "EUR",
                "flight_type": "oneway",
                "max_stopovers": 1,
                "sort": "price",
                "limit": 50, # Increased from 5
            }
            logger.info("Tequila GET search %s-%s %s params=%s", origin, destination, date, params)
            resp = requests.get(SEARCH_ENDPOINT, headers=_auth_headers(), params=params, timeout=25)
            if resp.status_code == 401:
                logger.error("Tequila unauthorized (401). Check TEQUILA_API_KEY")
                return None
            if resp.status_code == 429:
                logger.warning("Tequila rate limited (429) for %s-%s %s", origin, destination, date)
                return {"rate_limited": True}
            if resp.status_code not in (200,):
                logger.error("Tequila HTTP %s: %s", resp.status_code, (resp.text or "")[:300])
                return None
            data = resp.json() if resp.text else {}

        if data is None:
            logger.error("No API response obtained from any source.")
            return None

        if _is_rapid():
            # For v2/search, data is in 'data'. For one-way, it's 'itineraries'
            items_raw = data.get("data") if endpoint_path_used in ["/v2/search", "/search"] else data.get("itineraries")
            items = items_raw if isinstance(items_raw, list) else None

            if items is None: # Explicitly check for None, empty list is valid (no flights)
                logger.info("RapidAPI response format error or key not found for %s-%s %s using %s.", origin, destination, date, endpoint_path_used)
                if not getattr(settings, "DISABLE_CACHE", False):
                    set_cache(f"KIW|{origin}", destination, date, None, fetched_at=int(time.time()))
                logger.debug("Tequila client returning None due to format error.")
                return None # Return None on format error
            
            if not items:
                logger.info("RapidAPI returned no flight offers for %s-%s on %s using %s.", origin, destination, date, endpoint_path_used)
                if not getattr(settings, "DISABLE_CACHE", False):
                    set_cache(f"KIW|{origin}", destination, date, {}, fetched_at=int(time.time())) # Cache empty result
                logger.debug("Tequila client returning {} due to no flights found in response.")
                return {} # Return an empty dict to signify "no flights found", not an error

            # Iterate through ALL offers to find the cheapest one
            cheapest_offer = None
            cheapest_price = float('inf')
            
            for offer in items:
                logger.info("Full RapidAPI offer for %s-%s-%s: %s", origin, destination, date, str(offer))
                try:
                    price_val = float(offer.get("price"))
                except (Exception, TypeError, ValueError):
                    try:
                        price_val = float(offer.get("price", {}).get("amount"))
                    except (Exception, TypeError, ValueError):
                        continue  # Skip offers without valid price

                # Skip if price is higher than current cheapest
                if price_val >= cheapest_price:
                    continue

                currency = (settings.CURRENCY or "EUR")
                # bookingOptions.edges[0].node.bookingUrl is often a relative path
                deep_link = None
                try:
                    booking_url_path = (
                        offer.get("bookingOptions", {})
                        .get("edges", [{}])[0]
                        .get("node", {})
                        .get("bookingUrl")
                    )
                    if booking_url_path:
                        if booking_url_path.startswith("http"):
                            deep_link = booking_url_path
                        else:
                            deep_link = f"https://www.kiwi.com{booking_url_path}"
                except Exception:
                    deep_link = None

                # Date check for v2/search which can return flights for other days
                departure_utc_str = _deep_get(offer, "local_departure")
                if not departure_utc_str: # fallback for one-way
                    first_segment = _deep_find_first(offer, lambda d: "localTime" in d and "utcTime" in d)
                    if first_segment:
                        departure_utc_str = first_segment.get("utcTime")

                # Store actual departure date for display
                actual_departure_date = date  # default to requested date
                if departure_utc_str:
                    try:
                        departure_dt_utc = datetime.fromisoformat(departure_utc_str.replace("Z", "+00:00"))
                        actual_departure_date = departure_dt_utc.strftime("%Y-%m-%d")
                        if actual_departure_date != date:
                            logger.info(
                                "Date mismatch - showing cheapest flight. Wanted %s, got %s",
                                date, actual_departure_date
                            )
                            # Don't skip - include in cheapest comparison
                    except (ValueError, TypeError):
                        logger.warning("Could not parse departure time from '%s'", departure_utc_str)
                        # Continue with default date
                
                # --- Main data extraction ---
                airline_code = "TBD"
                flight_number = "TBD"
                duration_str = "TBD"
                departure_time = "TBD"
                
                try:
                    # Find the first segment-like object
                    segment = _deep_find_first(offer, lambda d: "carrier" in d and "code" in d and "duration" in d)
                    if segment:
                        # Airline code
                        carrier = segment.get("carrier") or segment.get("operatingCarrier")
                        if isinstance(carrier, dict):
                            airline_code = carrier.get("code", "TBD")
                        
                        # Flight number
                        flight_num_val = segment.get("code")
                        if flight_num_val:
                           flight_number = str(flight_num_val)

                        # Duration
                        duration_seconds = segment.get("duration")
                        if isinstance(duration_seconds, int):
                            duration_str = _format_duration_seconds(duration_seconds)
                        
                        # Departure time
                        source = segment.get("source")
                        if isinstance(source, dict):
                            dep_utc = source.get("utcTime")
                            if dep_utc:
                                departure_time = dep_utc
                
                except Exception as e:
                    logger.error("Error parsing RapidAPI offer segment: %s", e)

                # Prefer currency from offer if present
                try:
                    curr_from_offer = offer.get("price", {}).get("currency") or offer.get("price", {}).get("currencyCode")
                    if curr_from_offer:
                        currency = curr_from_offer
                except Exception:
                    pass

                # Debug log a small snapshot of keys to validate parsing in logs
                try:
                    logger.info(
                        "RapidAPI parsed keys airline=%s flight_number=%s duration=%s departure=%s link_set=%s price=%s",
                        airline_code, flight_number, duration_str, departure_time, bool(deep_link), price_val
                    )
                except Exception:
                    pass

                # This is the new cheapest offer
                cheapest_price = price_val
                cheapest_offer = {
                    "price": price_val,
                    "currency": currency,
                    "airline": airline_code,
                    "flight_number": flight_number,
                    "duration": duration_str or "TBD",
                    "departure_time": departure_time or "TBD",
                    "flight_link": deep_link,
                    "actual_departure_date": actual_departure_date,  # Gerçek kalkış tarihi
                }

            # Return the cheapest offer found
            if cheapest_offer:
                logger.info("Leg fetch done %s-%s %s resp_type=%s resp_preview=%s (cheapest of %d offers)", 
                           origin, destination, date, type(cheapest_offer).__name__, str(cheapest_offer)[:240], len(items))
                if not getattr(settings, "DISABLE_CACHE", False):
                    set_cache(f"KIW|{origin}", destination, date, cheapest_offer, fetched_at=int(time.time()))
                return cheapest_offer

            # If loop finishes without finding any valid offer
            logger.warning("No valid offers found for the requested date %s after checking all items.", date)
            return None

        else: # Legacy direct Tequila parsing
            items = data.get("data") if isinstance(data, dict) else None
            if not items:
                logger.info("Tequila no offers for %s-%s %s", origin, destination, date)
                if not getattr(settings, "DISABLE_CACHE", False):
                    set_cache(f"KIW|{origin}", destination, date, None, fetched_at=int(time.time()))
                return None
            offer = items[0]
            # Extract fields
            try:
                price_val = float(offer.get("price"))
            except Exception:
                price_val = None

            currency = (settings.CURRENCY or "EUR")
            deep_link = offer.get("deep_link")

            airline_code = None
            flight_number = None
            departure_iso = None
            duration_str = None

            try:
                route = offer.get("route", [])
                if route:
                    first_seg = route[0]
                    airline_code = first_seg.get("airline") or (offer.get("airlines", [None]) or [None])[0]
                    if first_seg.get("airline") and first_seg.get("flight_no"):
                        flight_number = str(first_seg.get("flight_no"))
                    d_utc = first_seg.get("dTimeUTC")
                    if isinstance(d_utc, (int, float)):
                        departure_iso = datetime.fromtimestamp(int(d_utc), tz=timezone.utc).isoformat()
                    else:
                        departure_iso = offer.get("utc_departure") or offer.get("local_departure")
            except Exception:
                pass

            try:
                dur = offer.get("duration", {}).get("total")
                if isinstance(dur, (int, float)):
                    duration_str = _format_duration_seconds(int(dur))
            except Exception:
                pass

            result = {
                "price": price_val,
                "currency": currency,
                "airline": (airline_code or "TBD"),
                "flight_number": (flight_number or "TBD"),
                "duration": (duration_str or "TBD"),
                "departure_time": (departure_iso or "TBD"),
                "flight_link": (deep_link or None),
                "actual_departure_date": actual_departure_date,  # Gerçek kalkış tarihi
            }

        if not getattr(settings, "DISABLE_CACHE", False):
            set_cache(f"KIW|{origin}", destination, date, result, fetched_at=int(time.time()))
        return result

    except requests.RequestException as e:
        logger.error("Tequila network error for %s-%s %s: %s", origin, destination, date, e)
        return None


def probe() -> Dict[str, Any]:
    """Simple key/endpoint probe. Tries locations for IST (limit 1) via RapidAPI or direct Tequila."""
    results: Dict[str, Any] = {}
    try:
        if _is_rapid():
            resp = None
            params = {"term": "IST", "locale": "en", "limit": 1}
            for name, url in _rapid_locations_endpoints().items():
                try:
                    logger.info("RapidAPI GET locations %s url=%s params=%s", name, url, params)
                    r = requests.get(url, headers=_rapid_headers(), params=params, timeout=15)
                    if r.status_code == 404:
                        continue
                    resp = r
                    break
                except Exception:
                    continue
            if resp is None:
                return {"ok": False, "error": "RapidAPI locations endpoints all failed"}
        else:
            if not settings.TEQUILA_API_KEY:
                return {"ok": False, "error": "TEQUILA_API_KEY missing"}
            resp = requests.get(
                LOCATIONS_ENDPOINT,
                headers=_auth_headers(),
                params={"term": "IST", "location_types": "airport", "limit": 1},
                timeout=15,
            )
        results = {
            "status_code": resp.status_code,
            "ok": resp.status_code == 200,
            "preview": (resp.text[:200] if resp.text else None),
        }
    except Exception as e:
        results = {"ok": False, "error": str(e)}
    return results