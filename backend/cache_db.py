# cache_db.py
# Basit SQLite tabanlı cache. uçuş fiyatlarını (origin,dest,date) -> JSON saklar.

import sqlite3
import json
from typing import Optional

DB_PATH = None

def init(db_path="cache.db"):
    global DB_PATH
    DB_PATH = db_path
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS price_cache (
        origin TEXT,
        destination TEXT,
        date TEXT,
        response TEXT,
        fetched_at INTEGER,
        PRIMARY KEY(origin, destination, date)
    )
    """)
    conn.commit()
    conn.close()

def get(origin: str, destination: str, date: str) -> Optional[dict]:
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT response FROM price_cache WHERE origin=? AND destination=? AND date=?", (origin, destination, date))
    row = c.fetchone()
    conn.close()
    if not row:
        return None
    return json.loads(row[0])

def set_cache(origin: str, destination: str, date: str, data: dict, fetched_at: int = None):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO price_cache(origin,destination,date,response,fetched_at) VALUES (?,?,?,?,?)",
              (origin, destination, date, json.dumps(data), fetched_at or 0))
    conn.commit()
    conn.close()

def clear_all():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("DELETE FROM price_cache")
    conn.commit()
    conn.close()
