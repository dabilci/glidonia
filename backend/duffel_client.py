import time
import logging
import requests
from typing import Optional, Dict, Any

from .config import settings
from .cache_db import get as cache_get, set_cache as cache_set

logger = logging.getLogger("gelidonia")


API_BASE = "https://api.duffel.com/air/offer_requests"
API_AIRLINES = "https://api.duffel.com/air/airlines"


def _auth_headers(version_override: Optional[str] = None) -> Dict[str, str]:
    if not settings.DUFFEL_ACCESS_TOKEN:
        return {}
    headers = {
        "Authorization": f"Bearer {settings.DUFFEL_ACCESS_TOKEN}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    version = version_override if version_override is not None else settings.DUFFEL_API_VERSION
    if version:
        headers["Duffel-Version"] = version
    return headers


def _format_duration_iso8601(total_minutes: int) -> str:
    if not isinstance(total_minutes, int) or total_minutes <= 0:
        return None
    hours = total_minutes // 60
    mins = total_minutes % 60
    if mins == 0:
        return f"{hours}h"
    return f"{hours}h {mins}m"


def _build_offer_request_body(origin: str, destination: str, date: str) -> Dict[str, Any]:
    # Basic one-way search, economy, 1 adult
    return {
        "data": {
            "slices": [
                {"origin": origin, "destination": destination, "departure_date": date}
            ],
            "passengers": [{"type": "adult"}],
            "cabin_class": "economy",
            "max_connections": 1,
            "return_offers": True,
            "currency": settings.CURRENCY,
        }
    }


def fetch_price_for_date(origin: str, destination: str, date: str) -> Optional[Dict[str, Any]]:
    """
    Creates a Duffel offer request and returns the cheapest offer summary for a given date.
    Response shape aligns with backend.main expectations when dict is returned, including:
      price (float), currency (str), airline (str), flight_number (str), duration (str),
      departure_time (str ISO), flight_link (str or None)
    Results are cached by (origin, destination, date).
    """

    # Provider-specific cache key to avoid collisions with Travelpayouts
    cache = cache_get(f"DUF|{origin}", destination, date)
    if cache is not None:
        return cache

    token = settings.DUFFEL_ACCESS_TOKEN
    if not token:
        logger.warning("Duffel token missing; returning None")
        return None

    try:
        # Create offer request
        body = _build_offer_request_body(origin, destination, date)
        logger.info("Duffel POST offer_request %s-%s %s body=%s", origin, destination, date, body)
        candidate_versions = []
        # Try without version first (let API default), then env, then known versions
        candidate_versions = [None]
        if settings.DUFFEL_API_VERSION:
            candidate_versions.append(settings.DUFFEL_API_VERSION)
        candidate_versions += ["2024-10-01", "2024-05-01", "2023-10-01", "beta", "v1"]

        resp = None
        last_error_text = None
        for ver in candidate_versions:
            logger.info("Duffel trying version header=%s", (ver if ver is not None else "<none>"))
            resp = requests.post(API_BASE, json=body, headers=_auth_headers(ver), timeout=25)
            if resp.status_code in (200, 201):
                break
            if resp.status_code == 401:
                logger.error("Duffel unauthorized (401). Check DUFFEL_ACCESS_TOKEN")
                return None
            if resp.status_code == 429:
                logger.warning("Duffel rate limited (429) for %s-%s %s", origin, destination, date)
                return {"rate_limited": True}
            last_error_text = resp.text or ""
            if resp.status_code == 400 and "unsupported_version" in last_error_text:
                # try next version
                continue
            # any other 4xx/5xx: stop and log
            logger.error("Duffel HTTP %s with version %s: %s", resp.status_code, ver, (last_error_text[:300]))
            return None

        if not resp or resp.status_code not in (200, 201):
            logger.error("Duffel couldn't find a supported API version. Last error: %s", (last_error_text[:300] if last_error_text else None))
            return None

        offer_request = resp.json()
        logger.info("Duffel offer_request response code=%s size=%s preview=%s", resp.status_code, len(resp.text or ""), str(offer_request)[:240])
        # Duffel returns offers embedded under data.offers or requires follow-up GET
        # Some responses include "data", {"offers": [...]} directly. Handle both.
        offers = None
        if isinstance(offer_request, dict):
            # Newer API: POST returns 201 and immediate offers at data.offers
            data_obj = offer_request.get("data") or offer_request
            offers = data_obj.get("offers") if isinstance(data_obj, dict) else None

        # If no offers present, try follow-up GET using offer_request id
        if not offers:
            req_id = None
            try:
                req_id = offer_request["data"]["id"]
            except Exception:
                req_id = None
            if req_id:
                time.sleep(0.6)
                get_url = f"{API_BASE}/{req_id}"
                logger.info("Duffel GET offer_request %s", get_url)
                get_resp = requests.get(get_url, headers=_auth_headers(), timeout=25)
                if get_resp.status_code in (200, 201):
                    get_json = get_resp.json()
                    offers = (get_json.get("data") or {}).get("offers")
                    logger.info("Duffel GET offers count=%s preview=%s", (len(offers) if offers else 0), str(offers[:1])[:240] if offers else None)

        if not offers:
            logger.info("Duffel no offers for %s-%s %s", origin, destination, date)
            cache_set(f"DUF|{origin}", destination, date, None, fetched_at=int(time.time()))
            return None

        # Pick cheapest by total_amount
        cheapest = None
        cheapest_amount = float("inf")
        cheapest_currency = settings.CURRENCY
        for offer in offers:
            try:
                amount = float(offer.get("total_amount"))
                currency = offer.get("total_currency") or settings.CURRENCY
                if amount < cheapest_amount:
                    cheapest = offer
                    cheapest_amount = amount
                    cheapest_currency = currency
            except Exception:
                continue

        if not cheapest:
            cache_set(origin, destination, date, None, fetched_at=int(time.time()))
            return None

        # Extract one slice/segment details for display
        airline_code = None
        flight_number = None
        departure_time_iso = None
        duration_str = None

        try:
            # First slice, first segment
            slices = cheapest.get("slices", [])
            if slices:
                first_slice = slices[0]
                segments = first_slice.get("segments", [])
                if segments:
                    first_segment = segments[0]
                    marketing_carrier = first_segment.get("marketing_carrier") or {}
                    airline_code = marketing_carrier.get("iata_code") or marketing_carrier.get("id")
                    flight_number = first_segment.get("marketing_carrier_flight_number")
                    departure_time_iso = first_segment.get("departing_at")
                    # Duration may be at segment or slice level (ISO8601 PTxHxM)
                    duration_iso = first_segment.get("duration") or first_slice.get("duration")
                    if duration_iso and duration_iso.startswith("PT"):
                        # quick parse: PT3H20M
                        val = duration_iso[2:]
                        hours = 0
                        mins = 0
                        if "H" in val:
                            parts = val.split("H")
                            hours = int(parts[0] or 0)
                            val = parts[1] if len(parts) > 1 else ""
                        if "M" in val:
                            mins = int(val.split("M")[0] or 0)
                        duration_str = _format_duration_iso8601(hours * 60 + mins)
        except Exception:
            pass

        result = {
            "price": cheapest_amount,
            "currency": cheapest_currency,
            "airline": airline_code or "TBD",
            "flight_number": flight_number or "TBD",
            "duration": duration_str or "TBD",
            "departure_time": departure_time_iso or "TBD",
            "flight_link": None,
        }

        cache_set(f"DUF|{origin}", destination, date, result, fetched_at=int(time.time()))
        return result

    except requests.RequestException as e:
        logger.error("Duffel network error for %s-%s %s: %s", origin, destination, date, e)
        return None


def probe_versions() -> Dict[str, Any]:
    """Try a simple GET against airlines to detect a supported Duffel-Version.
    Returns a dict of version -> {status_code, ok, preview}.
    """
    results: Dict[str, Any] = {}
    try_versions = [None]
    if settings.DUFFEL_API_VERSION:
        try_versions.append(settings.DUFFEL_API_VERSION)
    try_versions += ["2024-10-01", "2024-05-01", "2023-10-01", "beta", "v1"]

    for ver in try_versions:
        key = ver if ver is not None else "<none>"
        try:
            resp = requests.get(API_AIRLINES, headers=_auth_headers(ver), params={"limit": 1}, timeout=15)
            results[key] = {
                "status_code": resp.status_code,
                "ok": resp.status_code == 200,
                "preview": (resp.text[:200] if resp.text else None),
            }
        except Exception as e:
            results[key] = {"status_code": None, "ok": False, "error": str(e)}
    return results


