# Changelog

## [2026-04-16]
### Fixed
- Rank #1 row clipped in player profile stat boxes (Nicknames, Character Types, Weapons, Vehicle Time, Top Victims, Top Assassins, Map Performance, Last Games) — sticky `thead th` rule applied globally caused the column header to visually shift down over the first data row when scrolling; added `.card thead th{position:static}` to disable sticky on compact card tables where it isn't needed
- GitHub template had installer placeholders missing — `__SITE_TITLE__`, `__LOGO_FILE__`, `__SERVER_NAME__`, `__FORUM_LINK__` were replaced with static strings by sync.sh instead of being restored as placeholders, breaking fresh installs for other users; all placeholders restored in `web/index.html` and `sync.sh` updated to restore them correctly on future syncs
- Player profile section in GitHub template had real player data (name, stats) from the live site baked in; replaced with generic `—` defaults
- Admin clan tag input placeholder showed a site-specific tag example; changed to generic `e.g. [TAG]`

## [2026-04-11] — Readability & UX fixes
### Fixed
- Chrome showing email/password credential popup when clicking any search bar — all search and admin inputs now use `type="search"` and `autocomplete="new-password"` so Chrome no longer treats the page as a login form
- Server name in hero bar showed name from last completed game in DB — now updated in real time from live GameSpy query on every live poller tick
- Admin "Run Parser Now" button gave no feedback — button now shows "⏳ Running..." and stays disabled until log is fetched; log auto-scrolls to bottom; added a second poll at 6s for slower runs
- Live scoreboard showed "Auto-refresh every 5s" but actual interval is 10s — label corrected
- Site-specific CSS comment header stripped from GitHub repo copy; sync.sh updated to strip it on future pushes

### Changed
- Dark mode dim text colors brightened: `--text-dim` #6b8299 → #90adc4, `--text-muted` #3d5570 → #607a96
- Base font size increased from 14px to 16px for better readability across all pages

## [2026-04-10] — Light theme, UI polish
### Added
- Light/dark theme toggle — moon/sun icon button in navbar between JOIN and Forum; switches theme instantly, persists across page loads via localStorage; dark theme unchanged
- Light theme — steel-blue gray palette with deep teal accent (#0071a0); easy on the eyes, professional look

### Fixed
- Table rank column (# ) was too wide — added `width:1px` shrink-wrap on first column so names sit immediately next to numbers (vehicles, characters, weapons pages)
- Linked player names (Top Pilots, Top Repairers, Top Healers, weapons leaderboards) were dimmer than non-linked names — added `tbody td a.hi` rule so brightness is consistent
- Search fields (Player Name, Server Name) showed browser autofill/saved emails — added `autocomplete="off"`
- Admin link moved from navbar to footer — less visible to regular users, still functional


## [2026-04-10] — Player merge tool
### Added
- Admin panel: Merge Duplicate Players tool — search by name, shows all matching records with keyhash (truncated), last-seen date, score/kills/rounds; most recently used keyhash is highlighted as LAST USED and pre-selected as primary; merge button reassigns all stat tables to primary and recalculates cache_ranking

### Fixed
- Merge results table showed 0 rounds — API field is `rounds_played` but JS was reading `rounds`; corrected field name
- Merge endpoint crashed with Internal Server Error — DELETE statements for `selectbf_cache_weaponkills`, `selectbf_cache_vehicletime`, `selectbf_cache_chartypeusage` referenced non-existent `player_id` column (these are global aggregate tables); removed invalid deletes

## [2026-04-10]
### Added
- `/api/map-images` endpoint — auto-discovers map screen images from disk, builds slug→filename mapping so new maps show images automatically without manual config
- Hamburger menu for mobile/tablet (≤900px) — full-width dropdown nav with scrollable links and JOIN button, closes on nav or outside tap
- Dynamic podium — top-3 players loaded from API on page load and when switching period tabs (All Time / Month / Week), no hardcoded names
- Dynamic clans page — loads from `/api/clans` instead of hardcoded fake rows; page now properly wired to nav loader
- `hue_alt` map image mapping added (resolves to hue1968.jpg)

### Fixed
- Clans API 500 error — `CONCAT('%', ...)` `%` chars were conflicting with pymysql format string, now escaped as `%%`
- Podium cards used hardcoded player names/stats from mockup — replaced with real API data and numeric player IDs
- Clans page had 4 fully hardcoded fake rows with no element IDs and no JS to populate them
- Sticky table header `top:52px` offset caused misplaced line on mobile — set `position:static` on mobile breakpoint
- JOIN button popup clipped by `nav overflow:hidden` — moved JOIN button outside `<nav>` so dropdown renders correctly
- Mobile JOIN popup appeared off-screen — changed to `position:static` flow inside nav dropdown on mobile
- Hero-meta box overflow — long server names now truncate with ellipsis instead of breaking layout
- Server status pill stretched full-width on mobile landscape — now hidden on ≤900px (status visible in hero bar)

### Changed
- Sidebar background now matches player list (removed distinct `--bg-panel` background)
- Sidebar moved to top of layout — now starts level with podium instead of below tabs
- Podium moved inside player list column, centered with table width
- Podium top borders: thicker (4px) and brighter (near-full opacity gold/silver/bronze)
- Nav links larger (11px, more padding) for better readability
- Hamburger breakpoint raised to 900px to cover landscape phones
- VIETNAM watermark removed from hero bar
- Removed `position:sticky` on table headers on mobile to prevent misaligned separators


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
