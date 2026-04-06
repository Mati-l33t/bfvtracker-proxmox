# Changelog

## [2026-04-06]
### Fixed
- install.sh now creates selectbf_ping_summary and selectbf_uptime_log tables on fresh install
- install.sh now installs check_uptime.py and sets up cron job on fresh install


### Added
- Real server uptime tracking via GameSpy UDP ping every 30 minutes (cron job + `selectbf_uptime_log` table)
- `check_uptime.py` script — logs up/down every minute, auto-prunes entries older than 31 days
- Uptime widget shows "Collecting..." until enough data is gathered, then shows true % over last 30 days


### Added
- Map image in Current Map sidebar widget with map name overlaid
- Per-player ping summary table (`selectbf_ping_summary`) — stores one running average ping row per player, never grows unboundedly
- Round-transition detection in live API — pings are collected during a round and flushed to DB when round ends
- Avg ping shown on player profile page KPI bar (appears once data is collected)
- Avg ping survives API restarts via persistent cache file
- Current Map widget on front page sidebar (above Recent Games) — shows map image, map name, avg ping, 30-day uptime %
- New `/api/stats/server` endpoint returning uptime % and avg ping

### Changed
- Renamed "Server Stats" widget to "Current Map"
- Live scoreboard and chat polling reduced from 5s to 10s to reduce load on BFV server
- K/D colors updated: red (<1.0), green (1.0–2.0), gold with glow (>2.0)
- Logo text gradient styling

## [2026-04-05]
### Added
- Debian 13 added to supported OS list in requirements

## [2026-04-04]
### Added
- World clock widget in sidebar (Local, New York, London, Kyiv)
- Top Pilots leaderboard on Characters page (air kills)
- Ban details panel in admin — shows banned by, reason, timestamp

### Fixed
- Player count showing incorrect numbers
- Last Games duplicates on player profile
- Player tracking inconsistencies

## [2026-04-03]
### Added
- Top Repairers and Top Healers sections on Characters page
- Weapon categories page with top-25 player leaderboards per weapon category
- Pulsing JOIN button in nav bar with live server IP
- Screenshots added to README

### Fixed
- Player profile 404 for players missing from cache ranking table
- `last_seen` using actual round endtime instead of stale playtimes table
- Duplicate games: deduplicated at API query level
- Live scoreboard, chat and parser dedup fixes
- Ban sync fixes
- JOIN button pulse/hover CSS
- Hardcoded server values replaced with installer placeholders

## [2026-04-02] — Initial Release
### Added
- BFV Stats LXC installer (Proxmox, Debian 12)
- FastAPI backend (`api.py`) with full selectbf MySQL integration
- Single-page frontend with: Rankings, Player Profiles, Games, Maps, Weapons, Vehicles, Characters, Live Scoreboard, Search, Admin
- Live scoreboard with 5s polling, team tickets, chat log, round history
- Player profiles: KPIs, weapon stats, vehicle time, map performance, kill/death relationships, nickname history
- Map statistics with win rates
- Clan rankings
- Full installer script with nginx, MariaDB, uvicorn systemd service
- Full setup README with selectbf modernisation notes
