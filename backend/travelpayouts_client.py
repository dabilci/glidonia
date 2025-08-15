import time
import logging
import requests
from config import settings
from cache_db import get as cache_get, set_cache

logger = logging.getLogger("gelidonia")

# Use the correct working API endpoint for real-time pricing
# API_BASE = "https://api.travelpayouts.com/aviasales/v3/prices_for_dates"  # Expected prices only
API_BASE = "https://api.travelpayouts.com/v1/prices/cheap"  # Current prices

TOKEN = settings.TRAVELPAYOUTS_TOKEN
CURRENCY = settings.CURRENCY

def fetch_price_for_date(origin: str, destination: str, date: str):
    cache_key = f"tp-{origin}-{destination}-{date}"
    cached = cache_get(origin, destination, date)
    if cached is not None:
        return cached

    if not TOKEN:
        logger.warning("Travelpayouts token missing; returning None")
        return None

    # Use the correct API parameters for cheap prices endpoint
    params = {
        "origin": origin,
        "destination": destination,
        "depart_date": date,
        "currency": CURRENCY,
        "token": TOKEN,
        "limit": 1,  # Get only the cheapest flight
    }

    try:
        time.sleep(0.5)  # Rate limiting
        resp = requests.get(API_BASE, params=params, timeout=15)
        
        if resp.status_code == 429:
            logger.warning("TP rate limited 429 for %s-%s %s", origin, destination, date)
            return None
        if resp.status_code != 200:
            logger.error("TP HTTP %s: %s", resp.status_code, resp.text[:200])
            return None
            
        data = resp.json()
        
        # Check if we have valid data
        if not isinstance(data, dict):
            logger.warning("TP invalid response format for %s-%s %s", origin, destination, date)
            return None
            
        # Extract flight data from the response - handle different response formats
        flights_data = None
        
        # For v1/prices/cheap endpoint, data is directly a list of flights
        if isinstance(data, list):
            flights_data = data
        elif "data" in data:
            if isinstance(data["data"], dict):
                flights_data = data["data"].get(f"{origin}-{destination}", {})
            elif isinstance(data["data"], list):
                # Handle list format
                for item in data["data"]:
                    if isinstance(item, dict) and item.get("origin") == origin and item.get("destination") == destination:
                        flights_data = item
                        break
        
        if not flights_data:
            logger.warning("TP no flights found for %s-%s %s", origin, destination, date)
            set_cache(origin, destination, date, None, fetched_at=int(time.time()))
            return None

        # Get the cheapest flight
        cheapest_flight = None
        min_price = float('inf')
        
        # Handle different flight data structures
        if isinstance(flights_data, dict):
            # Direct flight data
            price = flights_data.get("price")
            if price and isinstance(price, (int, float)):
                min_price = price
                cheapest_flight = flights_data
        elif isinstance(flights_data, list):
            # List of flights
            for flight_info in flights_data:
                if isinstance(flight_info, dict):
                    price = flight_info.get("price")
                    if price and isinstance(price, (int, float)) and price < min_price:
                        min_price = price
                        cheapest_flight = flight_info

        if not cheapest_flight:
            logger.warning("TP no valid price found for %s-%s %s", origin, destination, date)
            set_cache(origin, destination, date, None, fetched_at=int(time.time()))
            return None

        # Price validation removed - accept all valid prices

        # Log the raw API response for debugging
        logger.info("TP RAW API RESPONSE for %s-%s %s: %s", origin, destination, date, data)
        logger.info("TP FLIGHTS_DATA for %s-%s %s: %s", origin, destination, date, flights_data)
        logger.info("TP CHEAPEST_FLIGHT for %s-%s %s: %s", origin, destination, date, cheapest_flight)
        
        # Extract flight details
        airline_code = cheapest_flight.get("airline", "TBD")
        flight_number = cheapest_flight.get("flight_number", "TBD")
        departure_time = cheapest_flight.get("departure_time", "TBD")
        duration = cheapest_flight.get("duration", "TBD")
        
        # Build flight link - use the actual link from API if available
        flight_link = cheapest_flight.get("link") or f"https://www.aviasales.com/{origin}/{destination}/{date}"
        
        # Format duration if it's in minutes
        duration_readable = "TBD"
        if duration and isinstance(duration, (int, float)):
            hours = int(duration // 60)
            minutes = int(duration % 60)
            if hours > 0:
                duration_readable = f"{hours}h {minutes}m" if minutes > 0 else f"{hours}h"
            else:
                duration_readable = f"{minutes}m"

        result = {
            "price": min_price,
            "airline": airline_code,
            "flight_number": flight_number,
            "duration": duration_readable,
            "currency": CURRENCY,
            "departure_time": departure_time,
            "flight_link": flight_link
        }
        
        set_cache(origin, destination, date, result, fetched_at=int(time.time()))
        return result
        
    except Exception as e:
        logger.exception("TP fetch error for %s-%s %s: %s", origin, destination, date, e)
        return None


