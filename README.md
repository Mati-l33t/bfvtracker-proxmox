# BFV Tracker — Proxmox LXC Installer

Stats tracker for **Battlefield Vietnam** dedicated servers, designed to run inside a Debian LXC on Proxmox.

Built on top of [selectbf](https://github.com/select-bf/selectbf) with an optional modern dark UI.

## What it installs

| Component | Description |
|-----------|-------------|
| **selectbf** | PHP log parser + classic stats web UI |
| **FastAPI backend** | `/api/*` endpoints — rankings, players, maps, live server status |
| **Modern UI** | Single-page dark app with live scoreboard, admin panel, clan filters |
| **MariaDB** | Database for all match stats |
| **nginx** | Reverse proxy; modern UI on `:8080`, classic on `:8081` |

## Quick install

Run inside a fresh Debian LXC:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main/install.sh)
```

The installer will ask:
- Which UI to install (modern / classic / both)
- Admin password for the modern UI panel
- BFV server host, game port, GameSpy query port
- Path to BFV server log directory
- Database credentials

## After install

1. Point your BFV dedicated server log directory at the path you entered (default `/opt/bfv/mods/bfvietnam/logs`)
2. Open the web UI and use **Admin → Run Parser** to import existing logs
3. The parser also runs automatically when new log files are detected

## Ports

| Port | UI |
|------|----|
| 8080 | Modern dark UI (if installed) |
| 8081 | Classic selectbf PHP UI (if installed) |
| 8000 | FastAPI backend (internal, proxied by nginx) |

## Requirements

- Debian 11/12 LXC (or Ubuntu 22.04+)
- BFV dedicated server reachable on the network (can be on another LXC/host)
- At least 512 MB RAM, 2 GB disk

## File layout

```
/opt/bfvstats/
    api.py          FastAPI application
    venv/           Python virtual environment
    .env            Config + admin password hash (chmod 640)

/var/www/bfvstats/
    index.html      Modern SPA frontend

/var/www/selectbf/
    ...             Classic selectbf PHP files
```
