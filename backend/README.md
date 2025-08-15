Gelidonia backend (FastAPI) - Travelpayouts MVP

1) Ortam kurulumu:
   python -m venv venv
   source venv/bin/activate   # Windows: venv\Scripts\activate
   pip install -r requirements.txt

2) .env dosyası:
   TRAVELPAYOUTS_TOKEN=... (senin token)
   CURRENCY=EUR
   CACHE_DB=cache.db

3) Çalıştır:
   uvicorn main:app --reload --port 8000

4) Endpointler:
   GET /health
   POST /find-route  (JSON, schema in code)
   POST /cache/clear

5) Test örneği (curl):
   curl -X POST "http://127.0.0.1:8000/find-route" -H "Content-Type: application/json" -d @payload.json

   payload.json örneği:
   {
     "start_range_start": "2025-06-01",
     "start_range_end": "2025-09-01",
     "trip_length_days": 12,
     "start_airport": "IST",
     "end_airport": "IST",
     "cities": ["BER","BCN","PAR","ROM"],
     "equal_days": true,
     "max_candidates": 20
   }
