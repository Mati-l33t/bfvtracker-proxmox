#!/usr/bin/env python3
"""Checks BFV server availability via GameSpy UDP and logs result to DB."""
import socket, pymysql
from dotenv import dotenv_values

cfg = dotenv_values("/opt/bfvstats/.env")
DB  = dict(host=cfg["DB_HOST"], port=int(cfg.get("DB_PORT", 3306)),
           user=cfg["DB_USER"], password=cfg["DB_PASS"], db=cfg["DB_NAME"],
           charset="utf8mb4")
BFV_HOST       = cfg.get("BFV_HOST", "127.0.0.1")
BFV_QUERY_PORT = int(cfg.get("BFV_QUERY_PORT", 23000))

def is_online():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(3.0)
        s.sendto(b"\\status\\", (BFV_HOST, BFV_QUERY_PORT))
        data = s.recv(256)
        s.close()
        return len(data) > 0
    except Exception:
        return False

online = 1 if is_online() else 0
conn = pymysql.connect(**DB)
with conn.cursor() as c:
    c.execute("INSERT INTO selectbf_uptime_log (online) VALUES (%s)", (online,))
    # Prune entries older than 31 days to keep the table small
    c.execute("DELETE FROM selectbf_uptime_log WHERE ts < DATE_SUB(NOW(), INTERVAL 31 DAY)")
conn.commit()
conn.close()
