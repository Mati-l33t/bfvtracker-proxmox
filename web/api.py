# Copyright (c) 2025-2026 -{GmV}- m@gic — https://github.com/Mati-l33t
"""BFV Stats — FastAPI backend for selectbf MySQL database."""
import os, hashlib, time, socket
from urllib.request import urlopen
from functools import lru_cache
from typing import Optional
from fastapi import FastAPI, HTTPException, Depends, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import pymysql
import pymysql.cursors
from dotenv import dotenv_values

# ─── CONFIG ───────────────────────────────────────────────────────────────────
cfg = dotenv_values("/opt/bfvstats/.env")
DB  = dict(host=cfg["DB_HOST"], port=int(cfg.get("DB_PORT",3306)),
           user=cfg["DB_USER"], password=cfg["DB_PASS"], db=cfg["DB_NAME"],
           cursorclass=pymysql.cursors.DictCursor, charset="utf8mb4")

app = FastAPI(title="BFV Stats API", version="2.0.0", docs_url=None, redoc_url=None)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ─── DB HELPER ────────────────────────────────────────────────────────────────
def db():
    return pymysql.connect(**DB)

def q(sql: str, args=None, many=True):
    conn = db()
    try:
        with conn.cursor() as c:
            c.execute(sql, args or ())
            return c.fetchall() if many else c.fetchone()
    finally:
        conn.close()

def q1(sql: str, args=None):
    return q(sql, args, many=False)

# ─── AUTH ─────────────────────────────────────────────────────────────────────
ADMIN_HASH = cfg.get("ADMIN_PASS_HASH","")
_sessions: dict = {}

def verify_admin(request: Request):
    token = request.headers.get("X-Admin-Token","")
    if not token or token not in _sessions:
        raise HTTPException(status_code=401, detail="Unauthorized")
    if time.time() - _sessions[token] > 3600:
        del _sessions[token]
        raise HTTPException(status_code=401, detail="Session expired")
    _sessions[token] = time.time()

def check_password(pw: str) -> bool:
    if ":" not in ADMIN_HASH:
        return False
    salt, h = ADMIN_HASH.split(":", 1)
    return hashlib.sha256((pw + salt).encode()).hexdigest() == h

# ─── ROUTES: SYSTEM ───────────────────────────────────────────────────────────
BFV_HOST = cfg.get("BFV_HOST", "10.0.0.70")
BFV_QUERY_PORT = int(cfg.get("BFV_QUERY_PORT", 23000))
BFV_GAME_PORT = int(cfg.get("BFV_GAME_PORT", 15567))

_wan_ip_cache: dict = {"ip": None, "ts": 0}

def _get_wan_ip() -> str:
    now = time.time()
    if _wan_ip_cache["ip"] and now - _wan_ip_cache["ts"] < 300:
        return _wan_ip_cache["ip"]
    try:
        ip = urlopen("https://api.ipify.org", timeout=4).read().decode().strip()
        _wan_ip_cache["ip"] = ip
        _wan_ip_cache["ts"] = now
        return ip
    except Exception:
        return _wan_ip_cache["ip"] or ""

def _gamespy_query(host: str, port: int, timeout: float = 3.0) -> dict:
    """Send GameSpy status query and return parsed key/value dict."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    try:
        s.sendto(b"\\status\\", (host, port))
        data = b""
        for _ in range(10):
            try:
                chunk = s.recv(4096)
                data += chunk
                if b"\\final\\" in chunk or b"\\EOF\\" in chunk:
                    break
            except socket.timeout:
                break
    finally:
        s.close()
    parts = data.decode("latin-1").split("\\")
    it = iter(parts[1:])  # skip leading empty
    result = {}
    for k in it:
        try:
            result[k] = next(it)
        except StopIteration:
            break
    return result

@app.get("/api/live")
def live():
    try:
        d = _gamespy_query(BFV_HOST, BFV_QUERY_PORT)
        if not d:
            raise ValueError("empty response")
        map_raw = d.get("mapname", "")
        map_slug = map_raw.lower().replace(" ", "_")
        wan = _get_wan_ip()
        return {
            "online": True,
            "server": d.get("hostname", ""),
            "map": map_slug,
            "map_display": map_raw.title(),
            "player_count": int(d.get("numplayers", 0)),
            "maxplayers": int(d.get("maxplayers", 64)),
            "tickets_team1": int(d.get("tickets_t0", 0)) if d.get("tickets_t0","").isdigit() else None,
            "tickets_team2": int(d.get("tickets_t1", 0)) if d.get("tickets_t1","").isdigit() else None,
            "gamemode": d.get("gametype", ""),
            "public_host": wan,
            "public_port": BFV_GAME_PORT,
            "players": [],
        }
    except Exception:
        raise HTTPException(status_code=503, detail="Server offline")

@app.get("/api/health")
def health():
    try:
        r = q1("SELECT COUNT(*) as cnt FROM selectbf_players")
        return {"status": "ok", "players": r["cnt"] if r else 0}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/api/stats/summary")
def summary():
    players = q1("SELECT COUNT(*) c FROM selectbf_players")
    games   = q1("SELECT COUNT(*) c FROM selectbf_games")
    kills   = q1("SELECT SUM(kills) c FROM selectbf_cache_ranking")
    return {
        "players": players["c"] if players else 0,
        "games":   games["c"]   if games   else 0,
        "kills":   kills["c"]   if kills   else 0,
    }

# ─── ROUTES: AUTH ─────────────────────────────────────────────────────────────
@app.post("/api/admin/login")
async def login(request: Request):
    body = await request.json()
    if not check_password(body.get("password", "")):
        raise HTTPException(status_code=403, detail="Wrong password")
    import secrets
    token = secrets.token_hex(32)
    _sessions[token] = time.time()
    return {"token": token}

@app.post("/api/admin/logout")
def logout(request: Request):
    token = request.headers.get("X-Admin-Token","")
    _sessions.pop(token, None)
    return {"ok": True}

# ─── ROUTES: PLAYERS ──────────────────────────────────────────────────────────
@app.get("/api/players")
def players(
    limit:  int = Query(50, le=200),
    offset: int = Query(0),
    sort:   str = Query("score"),
    order:  str = Query("desc"),
    search: str = Query(""),
    period: str = Query(""),   # "month" | "week" | "" (all time)
    filter: str = Query(""),   # "clan" | ""
):
    allowed_sort  = {"score","kills","deaths","kd","rounds","tks"}
    allowed_order = {"asc","desc"}
    sort  = sort  if sort  in allowed_sort  else "score"
    order = order if order in allowed_order else "desc"

    if period in ("month", "week"):
        interval = "1 MONTH" if period == "month" else "7 DAY"
        sort_col = {"kd": "kd"}.get(sort, sort)
        name_where = "AND p.name LIKE %s" if search else ""
        args = [f"%{search}%"] if search else []
        sql = f"""
            SELECT p.id, p.name,
                   NULL AS rank,
                   SUM(ps.score)  AS score,
                   SUM(ps.kills)  AS kills,
                   SUM(ps.deaths) AS deaths,
                   ROUND(SUM(ps.kills)/NULLIF(SUM(ps.deaths),0), 4) AS kd,
                   ROUND(SUM(ps.score)/NULLIF(COUNT(DISTINCT ps.round_id),0), 4) AS sr,
                   SUM(ps.tks)    AS tks,
                   COUNT(DISTINCT ps.round_id) AS rounds,
                   SUM(ps.first)  AS gold_awards,
                   SUM(ps.second) AS silver_awards,
                   SUM(ps.third)  AS bronze_awards,
                   SUM(ps.repairs) AS repairs,
                   SUM(ps.heals)  AS heal_points,
                   NULL AS last_seen
            FROM selectbf_players p
            JOIN selectbf_playerstats ps ON ps.player_id = p.id
            JOIN selectbf_rounds ro ON ro.id = ps.round_id
            WHERE ro.starttime >= DATE_SUB(NOW(), INTERVAL {interval})
            {name_where}
            GROUP BY p.id, p.name
            ORDER BY {sort_col} {order}
            LIMIT %s OFFSET %s
        """
        args += [limit, offset]
        rows = q(sql, args)
        count_args = [f"%{search}%"] if search else []
        total_row = q1(f"""
            SELECT COUNT(DISTINCT p.id) c
            FROM selectbf_players p
            JOIN selectbf_playerstats ps ON ps.player_id = p.id
            JOIN selectbf_rounds ro ON ro.id = ps.round_id
            WHERE ro.starttime >= DATE_SUB(NOW(), INTERVAL {interval})
            {name_where}
        """, count_args)
        return {"total": total_row["c"] if total_row else 0, "players": rows}

    # All-time: use cache_ranking
    sort_col = {"kd": "kdrate", "rounds": "rounds_played"}.get(sort, sort)
    conds, args = [], []
    if search:
        conds.append("p.name LIKE %s"); args.append(f"%{search}%")
    if filter == "clan":
        conds.append("EXISTS (SELECT 1 FROM selectbf_clan_tags ct WHERE p.name LIKE CONCAT('%%',ct.clan_tag,'%%'))")
    where = ("WHERE " + " AND ".join(conds)) if conds else ""
    sql = f"""
        SELECT
            p.id, p.name,
            r.rank,
            r.score, r.kills, r.deaths,
            r.kdrate AS kd,
            ROUND(r.score / NULLIF(r.rounds_played, 0), 4) AS sr,
            r.tks, r.rounds_played AS rounds,
            r.first AS gold_awards,
            r.second AS silver_awards,
            r.third AS bronze_awards,
            r.repairs, r.heals AS heal_points,
            r.last_visit AS last_seen
        FROM selectbf_players p
        JOIN selectbf_cache_ranking r ON r.player_id = p.id
        {where}
        ORDER BY r.{sort_col} {order}
        LIMIT %s OFFSET %s
    """
    args += [limit, offset]
    rows = q(sql, args)
    count_args = args[:-2]  # strip limit/offset
    total = q1(
        f"SELECT COUNT(*) c FROM selectbf_players p JOIN selectbf_cache_ranking r ON r.player_id=p.id {where}",
        count_args
    )
    return {"total": total["c"] if total else 0, "players": rows}

@app.get("/api/players/{player_id}")
def player_detail(player_id: int):
    p = q1("""
        SELECT p.id, p.name, p.keyhash, p.inserttime,
               r.rank, r.score, r.kills, r.deaths,
               r.kdrate AS kd,
               ROUND(r.score / NULLIF(r.rounds_played,0), 4) AS sr,
               r.tks, r.rounds_played AS rounds,
               r.first AS gold_awards, r.second AS silver_awards, r.third AS bronze_awards,
               r.repairs, r.heals AS heal_points, r.captures, r.attacks, r.defences,
               r.objectives, r.playtime, r.last_visit AS last_seen
        FROM selectbf_players p
        JOIN selectbf_cache_ranking r ON r.player_id = p.id
        WHERE p.id = %s
    """, [player_id])
    if not p:
        raise HTTPException(404, "Player not found")

    nicknames = q(
        "SELECT nickname AS name, times_used AS usage_count FROM selectbf_nicknames WHERE player_id=%s ORDER BY times_used DESC",
        [player_id])

    chartypes = q(
        "SELECT kit AS chartype, times_used AS usage_count FROM selectbf_kits WHERE player_id=%s ORDER BY times_used DESC LIMIT 20",
        [player_id])

    weapons = q(
        """SELECT weapon AS name, SUM(times_used) AS kills,
           ROUND(SUM(times_used)*100.0/NULLIF((SELECT kills FROM selectbf_cache_ranking WHERE player_id=%s),0),2) AS pct
           FROM selectbf_kills_weapon WHERE player_id=%s
           GROUP BY weapon ORDER BY kills DESC LIMIT 30""",
        [player_id, player_id])

    vehicles = q(
        """SELECT vehicle AS name,
           SEC_TO_TIME(ROUND(SUM(drivetime))) AS time_fmt,
           ROUND(SUM(drivetime)) AS seconds,
           ROUND(SUM(drivetime)*100.0/NULLIF((SELECT SUM(drivetime) FROM selectbf_drives WHERE player_id=%s),0),2) AS pct
           FROM selectbf_drives WHERE player_id=%s
           GROUP BY vehicle ORDER BY seconds DESC LIMIT 25""",
        [player_id, player_id])

    top_victims = q(
        """SELECT kp.victim_id, p2.name AS victim_name, SUM(kp.times_killed) AS kills,
           ROUND(SUM(kp.times_killed)*100.0/NULLIF((SELECT kills FROM selectbf_cache_ranking WHERE player_id=%s),0),2) AS pct
           FROM selectbf_kills_player kp JOIN selectbf_players p2 ON kp.victim_id=p2.id
           WHERE kp.player_id=%s GROUP BY kp.victim_id ORDER BY kills DESC LIMIT 15""",
        [player_id, player_id])

    top_assassins = q(
        """SELECT kp.player_id AS killer_id, p2.name AS killer_name, SUM(kp.times_killed) AS kills,
           ROUND(SUM(kp.times_killed)*100.0/NULLIF((SELECT deaths FROM selectbf_cache_ranking WHERE player_id=%s),0),2) AS pct
           FROM selectbf_kills_player kp JOIN selectbf_players p2 ON kp.player_id=p2.id
           WHERE kp.victim_id=%s GROUP BY kp.player_id ORDER BY kills DESC LIMIT 15""",
        [player_id, player_id])

    map_perf = q(
        """SELECT g.map AS map_name,
           SUM(ps.score) AS score, SUM(ps.kills) AS kills, SUM(ps.deaths) AS deaths,
           ROUND(SUM(ps.score)*100.0/NULLIF((SELECT score FROM selectbf_cache_ranking WHERE player_id=%s),0),2) AS pct
           FROM selectbf_playerstats ps
           JOIN selectbf_rounds r ON ps.round_id = r.id
           JOIN selectbf_games g ON r.game_id = g.id
           WHERE ps.player_id=%s
           GROUP BY g.map ORDER BY score DESC LIMIT 20""",
        [player_id, player_id])

    last_games = q(
        """SELECT g.id AS game_id, g.starttime AS start_time, g.servername AS server_name,
           g.modid AS mod_name, g.map AS map_name, g.game_mode AS gamemode,
           ps.score, ps.kills, ps.deaths
           FROM selectbf_playerstats ps
           JOIN selectbf_rounds r ON ps.round_id = r.id
           JOIN selectbf_games g ON r.game_id = g.id
           WHERE ps.player_id=%s
           ORDER BY g.starttime DESC LIMIT 20""",
        [player_id])

    return {
        "player":        p,
        "nicknames":     nicknames,
        "chartypes":     chartypes,
        "weapons":       weapons,
        "vehicles":      vehicles,
        "top_victims":   top_victims,
        "top_assassins": top_assassins,
        "map_perf":      map_perf,
        "last_games":    last_games,
    }

# ─── ROUTES: GAMES ────────────────────────────────────────────────────────────
@app.get("/api/games")
def games(limit: int = Query(20, le=100), offset: int = Query(0)):
    # Paginate first, then aggregate player counts only for those rows
    sql = """
        SELECT g.id, g.starttime AS start_time, g.servername AS server_name,
               g.modid AS mod_name, g.map AS map_name, g.game_mode AS gamemode,
               COALESCE(pc.player_count, 0) AS player_count
        FROM (
            SELECT id, starttime, servername, modid, map, game_mode
            FROM selectbf_games
            ORDER BY starttime DESC
            LIMIT %s OFFSET %s
        ) g
        LEFT JOIN (
            SELECT r.game_id, COUNT(DISTINCT ps.player_id) AS player_count
            FROM selectbf_rounds r
            JOIN selectbf_playerstats ps ON ps.round_id = r.id
            GROUP BY r.game_id
        ) pc ON pc.game_id = g.id
        ORDER BY g.starttime DESC
    """
    rows  = q(sql, [limit, offset])
    total = q1("SELECT COUNT(*) c FROM selectbf_games")
    return {"total": total["c"] if total else 0, "games": rows}

@app.get("/api/games/{game_id}")
def game_detail(game_id: int):
    game = q1("""
        SELECT id, starttime AS start_time, servername AS server_name,
               modid AS mod_name, map AS map_name, game_mode AS gamemode,
               gametime, maxplayers, scorelimit
        FROM selectbf_games WHERE id=%s
    """, [game_id])
    if not game:
        raise HTTPException(404, "Game not found")

    rounds = q("""
        SELECT id, starttime, endtime, endtype, winning_team,
               start_tickets_team1, start_tickets_team2,
               end_tickets_team1, end_tickets_team2
        FROM selectbf_rounds WHERE game_id=%s ORDER BY id
    """, [game_id])
    round_ids = [r["id"] for r in rounds]

    players_in_game = []
    if round_ids:
        placeholders = ",".join(["%s"]*len(round_ids))
        players_in_game = q(f"""
            SELECT ps.*, p.name AS player_name, p.id AS player_id, ps.team
            FROM selectbf_playerstats ps
            JOIN selectbf_players p ON ps.player_id = p.id
            WHERE ps.round_id IN ({placeholders})
            ORDER BY ps.score DESC
        """, round_ids)

    chat = q("""
        SELECT cl.inserttime AS time, p.name AS player_name, cl.text, '' AS channel
        FROM selectbf_chatlog cl
        LEFT JOIN selectbf_players p ON cl.player_id = p.id
        JOIN selectbf_rounds r ON cl.round_id = r.id
        WHERE r.game_id=%s ORDER BY cl.inserttime
    """, [game_id])

    return {"game": game, "rounds": rounds, "players": players_in_game, "chat": chat}

# ─── ROUTES: WEAPONS ──────────────────────────────────────────────────────────
@app.get("/api/weapons")
def weapons_global():
    return q("""
        SELECT weapon AS name, SUM(times_used) AS kills,
        ROUND(SUM(times_used)*100.0/(SELECT SUM(times_used) FROM selectbf_kills_weapon),2) AS pct
        FROM selectbf_kills_weapon GROUP BY weapon ORDER BY kills DESC LIMIT 50
    """)

# ─── ROUTES: VEHICLES ─────────────────────────────────────────────────────────
@app.get("/api/vehicles")
def vehicles_global():
    return q("""
        SELECT vehicle AS name,
        SEC_TO_TIME(ROUND(SUM(drivetime))) AS time_fmt,
        ROUND(SUM(drivetime)) AS seconds,
        ROUND(SUM(drivetime)*100.0/(SELECT SUM(drivetime) FROM selectbf_drives),2) AS pct
        FROM selectbf_drives GROUP BY vehicle ORDER BY seconds DESC LIMIT 30
    """)

# ─── ROUTES: CHARACTER TYPES ──────────────────────────────────────────────────
@app.get("/api/chartypes")
def chartypes_global():
    return q("""
        SELECT kit AS chartype, SUM(times_used) AS usage_count,
        ROUND(SUM(times_used)*100.0/(SELECT SUM(times_used) FROM selectbf_kits),2) AS pct
        FROM selectbf_kits GROUP BY kit ORDER BY usage_count DESC LIMIT 30
    """)

# ─── ROUTES: MAPS ─────────────────────────────────────────────────────────────
@app.get("/api/maps")
def maps_list():
    return q("""
        SELECT
            g.map AS id,
            g.map AS name,
            COUNT(DISTINCT r.id) AS rounds,
            SUM(CASE WHEN r.winning_team=1 THEN 1 ELSE 0 END) AS red_wins,
            SUM(CASE WHEN r.winning_team=2 THEN 1 ELSE 0 END) AS blue_wins,
            SUM(ps.kills) AS total_kills
        FROM selectbf_games g
        JOIN selectbf_rounds r ON r.game_id = g.id
        LEFT JOIN selectbf_playerstats ps ON ps.round_id = r.id
        GROUP BY g.map ORDER BY rounds DESC
    """)

@app.get("/api/maps/{map_id}")
def map_detail(map_id: str):
    info = q1("SELECT DISTINCT map AS id, map AS name FROM selectbf_games WHERE map=%s", [map_id])
    if not info:
        raise HTTPException(404, "Map not found")

    team_stats = q1("""
        SELECT
          SUM(CASE WHEN r.winning_team=1 THEN 1 ELSE 0 END) AS red_wins,
          SUM(CASE WHEN r.winning_team=2 THEN 1 ELSE 0 END) AS blue_wins,
          SUM(ps_t1.kills) AS red_kills,  SUM(ps_t2.kills) AS blue_kills,
          SUM(ps_t1.deaths) AS red_deaths, SUM(ps_t2.deaths) AS blue_deaths,
          AVG(CASE WHEN r.winning_team=1 THEN r.end_tickets_team1 END) AS avg_red_tickets_win,
          AVG(CASE WHEN r.winning_team=2 THEN r.end_tickets_team2 END) AS avg_blue_tickets_win
        FROM selectbf_games g
        JOIN selectbf_rounds r ON r.game_id = g.id
        LEFT JOIN selectbf_playerstats ps_t1 ON ps_t1.round_id=r.id AND ps_t1.team=1
        LEFT JOIN selectbf_playerstats ps_t2 ON ps_t2.round_id=r.id AND ps_t2.team=2
        WHERE g.map=%s
    """, [map_id])

    best_rounds = q("""
        SELECT ps.score, ps.kills, ps.deaths, ps.tks, ps.captures AS conquests,
               p.id AS player_id, p.name AS player_name,
               g.servername AS server_name, g.starttime AS start_time
        FROM selectbf_playerstats ps
        JOIN selectbf_players p ON ps.player_id = p.id
        JOIN selectbf_rounds r ON ps.round_id = r.id
        JOIN selectbf_games g ON r.game_id = g.id
        WHERE g.mapid=%s ORDER BY ps.score DESC LIMIT 3
    """, [map_id])

    top_killers = q("""
        SELECT p.id AS player_id, p.name AS player_name, SUM(ps.kills) AS kills
        FROM selectbf_playerstats ps
        JOIN selectbf_players p ON ps.player_id = p.id
        JOIN selectbf_rounds r ON ps.round_id = r.id
        JOIN selectbf_games g ON r.game_id = g.id
        WHERE g.mapid=%s GROUP BY p.id ORDER BY kills DESC LIMIT 20
    """, [map_id])

    return {"map": info, "team_stats": team_stats, "best_rounds": best_rounds, "top_killers": top_killers}

# ─── ROUTES: CLANS ────────────────────────────────────────────────────────────
@app.get("/api/clan-tags")
def clan_tags_public():
    rows = q("SELECT clan_tag FROM selectbf_clan_tags ORDER BY clan_tag")
    return [r["clan_tag"] for r in rows]

@app.get("/api/admin/clan-tags")
def clan_tags_list(_: None = Depends(verify_admin)):
    rows = q("SELECT clan_tag FROM selectbf_clan_tags ORDER BY clan_tag")
    return [r["clan_tag"] for r in rows]

@app.post("/api/admin/clan-tags")
async def clan_tag_add(request: Request, _: None = Depends(verify_admin)):
    body = await request.json()
    tag = (body.get("tag") or "").strip()
    if not tag:
        raise HTTPException(400, "Tag required")
    conn = db()
    try:
        with conn.cursor() as c:
            c.execute("INSERT IGNORE INTO selectbf_clan_tags (clan_tag) VALUES (%s)", [tag])
        conn.commit()
    finally:
        conn.close()
    return {"ok": True}

@app.delete("/api/admin/clan-tags/{tag}")
def clan_tag_delete(tag: str, _: None = Depends(verify_admin)):
    conn = db()
    try:
        with conn.cursor() as c:
            c.execute("DELETE FROM selectbf_clan_tags WHERE clan_tag=%s", [tag])
        conn.commit()
    finally:
        conn.close()
    return {"ok": True}

@app.get("/api/clans")
def clans():
    # Clan tags are stored in selectbf_clan_tags; match to players by name prefix/suffix pattern
    return q("""
        SELECT
            ct.clan_tag,
            COUNT(*) AS members,
            SUM(r.score) AS total_score,
            SUM(r.kills) AS total_kills,
            ROUND(SUM(r.kills)/NULLIF(SUM(r.deaths),0),4) AS avg_kd,
            SUM(r.rounds_played) AS total_rounds
        FROM selectbf_clan_tags ct
        JOIN selectbf_players p ON p.name LIKE CONCAT('%', ct.clan_tag, '%')
        JOIN selectbf_cache_ranking r ON r.player_id = p.id
        GROUP BY ct.clan_tag ORDER BY total_score DESC
    """)

# ─── ROUTES: SEARCH ───────────────────────────────────────────────────────────
@app.get("/api/search")
def search(
    name:   str = Query(""),
    server: str = Query(""),
    day:    Optional[int] = Query(None),
    month:  Optional[int] = Query(None),
    year:   Optional[int] = Query(None),
    mod:    str = Query(""),
):
    conditions, args = [], []
    if name:
        conditions.append("p.name LIKE %s")
        args.append(f"%{name}%")
    if server:
        conditions.append("""p.id IN (
            SELECT DISTINCT ps.player_id FROM selectbf_playerstats ps
            JOIN selectbf_rounds rn ON ps.round_id=rn.id
            JOIN selectbf_games g ON rn.game_id=g.id
            WHERE g.servername LIKE %s)""")
        args.append(f"%{server}%")
    if day:
        conditions.append("DAY(r.last_visit)=%s");   args.append(day)
    if month:
        conditions.append("MONTH(r.last_visit)=%s"); args.append(month)
    if year:
        conditions.append("YEAR(r.last_visit)=%s");  args.append(year)

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    return q(f"""
        SELECT p.id, p.name,
               r.score, r.kills, r.deaths,
               r.kdrate AS kd,
               ROUND(r.score/NULLIF(r.rounds_played,0),4) AS sr,
               r.tks, r.rounds_played AS rounds, r.last_visit AS last_seen
        FROM selectbf_players p
        JOIN selectbf_cache_ranking r ON r.player_id = p.id
        {where}
        ORDER BY r.score DESC LIMIT 100
    """, args)

# ─── ROUTES: ADMIN ────────────────────────────────────────────────────────────
@app.post("/api/admin/run-parser")
def run_parser(_: None = Depends(verify_admin)):
    import subprocess, threading
    def _run():
        subprocess.run(
            ["bash", "/opt/bfvstats/run-parser.sh"],
            capture_output=True, timeout=300
        )
    threading.Thread(target=_run, daemon=True).start()
    return {"ok": True, "message": "Parser started in background"}

@app.get("/api/admin/parser-log")
def parser_log(_: None = Depends(verify_admin)):
    try:
        with open("/opt/bfvstats/logs/parser.log") as f:
            return {"log": f.read()[-8000:]}
    except FileNotFoundError:
        return {"log": "No log yet — run the parser first."}

@app.get("/api/admin/bans")
def get_bans(_: None = Depends(verify_admin)):
    return q("SELECT * FROM sbf_ban ORDER BY created_at DESC")

@app.post("/api/admin/ban")
async def ban_player(request: Request, _: None = Depends(verify_admin)):
    body = await request.json()
    conn = db()
    try:
        with conn.cursor() as c:
            c.execute(
                "INSERT INTO sbf_ban (player_name, reason, created_at) VALUES (%s,%s,NOW())",
                [body.get("name",""), body.get("reason","")]
            )
        conn.commit()
    finally:
        conn.close()
    return {"ok": True}

@app.delete("/api/admin/ban/{ban_id}")
def unban(ban_id: int, _: None = Depends(verify_admin)):
    conn = db()
    try:
        with conn.cursor() as c:
            c.execute("DELETE FROM sbf_ban WHERE id=%s", [ban_id])
        conn.commit()
    finally:
        conn.close()
    return {"ok": True}

@app.post("/api/admin/change-password")
async def change_password(request: Request, _: None = Depends(verify_admin)):
    import secrets as _s
    body = await request.json()
    pw = body.get("password","")
    if len(pw) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")
    salt = _s.token_hex(16)
    h    = hashlib.sha256((pw+salt).encode()).hexdigest()
    new_hash = f"{salt}:{h}"
    env = open("/opt/bfvstats/.env").read()
    env = "\n".join(
        f"ADMIN_PASS_HASH={new_hash}" if l.startswith("ADMIN_PASS_HASH=") else l
        for l in env.splitlines()
    )
    open("/opt/bfvstats/.env","w").write(env)
    global ADMIN_HASH
    ADMIN_HASH = new_hash
    return {"ok": True}
