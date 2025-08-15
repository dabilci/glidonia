import time
import hashlib
from amadeus import Client, ResponseError, ServerError
import logging
import os
from .config import settings
from .cache_db import get as cache_get, set_cache as cache_set
import datetime

CLIENT_ID = settings.AMADEUS_CLIENT_ID
CLIENT_SECRET = settings.AMADEUS_CLIENT_SECRET
CURRENCY = settings.CURRENCY

logger = logging.getLogger("gelidonia")
amadeus = None
if CLIENT_ID and CLIENT_SECRET:
    amadeus = Client(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET
    )
else:
    logger.warning("Amadeus credentials missing. CLIENT_ID set=%s CLIENT_SECRET set=%s", bool(CLIENT_ID), bool(CLIENT_SECRET))

def fetch_price_for_date(origin, destination, date):
    """
    Amadeus API'sini kullanarak belirli bir rota ve tarih için en ucuz uçuşu arar.
    Sonuçları önbelleğe alır.
    """
    cache_key = f"amadeus-{origin}-{destination}-{date}"
    cached_data = cache_get(origin, destination, date)
    if cached_data:
        print(f"Cache HIT for {origin}-{destination} on {date}.")
        return cached_data

    print(f"Cache MISS for {origin}-{destination} on {date}. Calling Amadeus API.")
    
    # If Amadeus client is not configured, gracefully return None
    if amadeus is None:
        logger.info("Skipping Amadeus call for %s-%s %s due to missing credentials", origin, destination, date)
        return None

    try:
        # simple throttle to avoid rate limiting
        try:
            delay_sec = float(os.getenv("AMADEUS_REQUEST_DELAY_SEC", "1.5"))
        except Exception:
            delay_sec = 0.5
        if delay_sec > 0:
            time.sleep(delay_sec)
        response = amadeus.shopping.flight_offers_search.get(
            originLocationCode=origin,
            destinationLocationCode=destination,
            departureDate=date,
            currencyCode=CURRENCY,
            adults=1,
            max=1 # Sadece en ucuz teklifi al
        )
        
        if not response.data:
            logger.info("Amadeus returned no offers for %s-%s on %s", origin, destination, date)
            # API'den boş yanıt gelirse, bunu da önbelleğe alıp None dönelim.
            cache_set(origin, destination, date, None, fetched_at=int(time.time()))
            return None

        offer = response.data[0]
        price = float(offer['price']['total'])
        
        # Amadeus daha fazla detay sağlar, şimdilik basit tutalım
        airline = "TBD" 
        if 'carrierCode' in offer['itineraries'][0]['segments'][0]:
             airline = offer['itineraries'][0]['segments'][0]['carrierCode']
        
        duration = "TBD"
        if 'duration' in offer['itineraries'][0]:
            duration = offer['itineraries'][0]['duration']

        result = {
            "price": price,
            "airline": airline,
            "duration": duration,
        }

        cache_set(origin, destination, date, result, fetched_at=int(time.time()))
        return result

    except ResponseError as error:
        # Retry/backoff for 429
        try:
            status = getattr(error, 'response', None)
            code = getattr(status, 'status_code', None) or getattr(status, 'code', None)
        except Exception:
            code = None
        if code == 429:
            logger.warning("Rate limited (429) for %s-%s on %s; retrying...", origin, destination, date)
            for delay in (0.8, 1.6):
                time.sleep(delay)
                try:
                    response = amadeus.shopping.flight_offers_search.get(
                        originLocationCode=origin,
                        destinationLocationCode=destination,
                        departureDate=date,
                        currencyCode=CURRENCY,
                        adults=1,
                        max=1
                    )
                    if not response.data:
                        logger.info("Amadeus returned no offers after retry for %s-%s on %s", origin, destination, date)
                        cache_set(origin, destination, date, None, fetched_at=int(time.time()))
                        return None
                    offer = response.data[0]
                    price = float(offer['price']['total'])
                    airline = "TBD"
                    if 'carrierCode' in offer['itineraries'][0]['segments'][0]:
                         airline = offer['itineraries'][0]['segments'][0]['carrierCode']
                    duration = offer['itineraries'][0].get('duration', 'TBD')
                    result = {"price": price, "airline": airline, "duration": duration}
                    cache_set(origin, destination, date, result, fetched_at=int(time.time()))
                    return result
                except ResponseError:
                    continue
                except Exception as e:
                    logger.exception("Unexpected error during retry: %s", e)
                    break
            # final give-up: inform caller about rate limit
            logger.error("Amadeus API Error: 429 (rate limited) for %s-%s on %s", origin, destination, date)
            return {"rate_limited": True}
        else:
            logger.error("Amadeus API Error: %s", error)
            # Hata durumunda da None dönelim ki ana mantık çökmesin.
            return None
    except ServerError as error:
        logger.error("Amadeus Server Error: %s", error)
        return None
    except Exception as e:
        logger.exception("Unexpected error while calling Amadeus: %s", e)
        return None
