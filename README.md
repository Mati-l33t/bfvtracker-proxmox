# Battlefield Vietnam Stats for selectbf

A stats tracker for **Battlefield Vietnam** dedicated servers.  
Built on top of [selectbf](https://github.com/toadle/selectbf) with a modern web UI featuring dark and light themes.

Runs on any **Debian 11/12/13** or **Ubuntu 22.04+** machine — bare metal, VM, or LXC.

**Dark mode**

![Dark mode](https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main/docs/bfv-modern.PNG)

**Light mode**

![Light mode](https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main/docs/bfv-light.PNG)

**Original selectbf UI**

![Original selectbf UI](https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main/docs/bfv-old.PNG)

---

## What it installs

| Component | Description |
|-----------|-------------|
| **MariaDB** | Database storing all match stats |
| **selectbf** | PHP log parser + classic stats web UI |
| **FastAPI backend** | REST API for rankings, players, maps, live server status |
| **Modern UI** | Single-page app — live scoreboard, rankings, admin panel; dark/light theme toggle |
| **nginx** | Web server; modern UI on `:8080`, classic on `:8081` |

---

## Requirements

- Debian 11/12/13 or Ubuntu 22.04+ (bare metal, VM, or LXC — 512 MB RAM minimum, 2 GB disk)
- BFV dedicated server reachable on the network
- BFV server log files accessible from this machine (see [Getting the logs](#getting-the-logs))

---

## Quick install

Run as root on any supported Debian/Ubuntu machine:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main/install.sh)
```

The installer will ask you for:

| Prompt | Description |
|--------|-------------|
| **UI choice** | Modern / Classic / Both |
| **Admin password** | Protects both the modern UI admin panel and the classic selectbf admin panel |
| **Site name** | Your clan or server name — shown in the header |
| **Forum URL** | Optional link in the nav bar |
| **Logo URL** | Optional image URL (PNG/JPG) — leave blank for default |
| **BFV server host** | IP address of your BFV dedicated server |
| **BFV game port** | Default: 15567 |
| **BFV query port** | GameSpy UDP port — default: 23000 |
| **Log directory** | Where BFV log files are (local path on this machine) |
| **Database credentials** | Name, user, password — auto-generated if left blank |

---

## Getting the logs

The stats tracker parses BFV `.log` files to populate the database.  
The log files must be accessible as a **local path** on the stats machine.

### Option A — BFV server is on the same machine

Point the installer directly at the log folder:

```
/opt/bfv/mods/bfvietnam/logs
```

That's it — no extra setup needed.

---

### Option B — BFV server is on a different machine (most common)

Your BFV server is on a separate machine. You need to make the remote log directory available locally.

#### Method 1 — Bind mount (Proxmox only)

The cleanest option if both LXCs are on the same Proxmox host.  
Mount the BFV log directory from the game server LXC directly into the stats LXC.

1. Find the BFV LXC ID (e.g. `114`) and the stats LXC ID (e.g. `110`) on the Proxmox host.

2. Add a bind mount to the stats LXC config:
   ```bash
   # Run on the Proxmox host
   echo "mp0: /var/lib/lxc/114/rootfs/opt/bfv/mods/bfvietnam/logs,mp=/opt/bfv-logs,ro=1" \
       >> /etc/pve/lxc/110.conf
   pct reboot 110
   ```
   Replace `114` with your BFV LXC ID, `110` with your stats LXC ID.

3. When the installer asks for the log directory, enter:
   ```
   /opt/bfv-logs
   ```

---

#### Method 2 — rsync over SSH (any setup)

Set up periodic rsync from the BFV server to the stats machine.

**On the stats machine:**

1. Generate an SSH key (no passphrase):
   ```bash
   ssh-keygen -t ed25519 -f /root/.ssh/bfv_logs -N ""
   ```

2. Copy the public key to the BFV server:
   ```bash
   ssh-copy-id -i /root/.ssh/bfv_logs.pub root@<BFV_SERVER_IP>
   ```

3. Create a local log directory:
   ```bash
   mkdir -p /opt/bfv-logs
   ```

4. Create a cron job to sync every 5 minutes:
   ```bash
   crontab -e
   ```
   Add:
   ```
   */5 * * * * rsync -az --delete -e "ssh -i /root/.ssh/bfv_logs -o StrictHostKeyChecking=no" \
       root@<BFV_SERVER_IP>:/opt/bfv/mods/bfvietnam/logs/ /opt/bfv-logs/
   ```

5. When the installer asks for the log directory, enter:
   ```
   /opt/bfv-logs
   ```

---

#### Method 3 — sshfs (mount over SSH, any setup)

Mounts the remote directory as if it were local.

```bash
apt-get install -y sshfs

# Mount the remote log dir
sshfs -o IdentityFile=/root/.ssh/bfv_logs,allow_other,reconnect \
    root@<BFV_SERVER_IP>:/opt/bfv/mods/bfvietnam/logs /opt/bfv-logs

# To auto-mount on boot, add to /etc/fstab:
echo "root@<BFV_SERVER_IP>:/opt/bfv/mods/bfvietnam/logs /opt/bfv-logs fuse.sshfs \
    IdentityFile=/root/.ssh/bfv_logs,allow_other,reconnect,_netdev 0 0" >> /etc/fstab
```

---

## After install

### 1. Import existing log files

Open the modern UI → click **Admin** → enter your password → click **Run Parser**.

This scans the log directory and imports all rounds into the database.  
On a large server with years of logs this may take a few minutes.

### 2. Automatic parsing

New log files are detected automatically.  
You can also set up a cron job to run the parser every few minutes:

```bash
crontab -e
```
Add:
```
*/5 * * * * curl -s -X POST http://localhost:8000/api/admin/run-parser \
    -H "Authorization: Bearer $(cat /opt/bfvstats/.env | grep ADMIN_PASS_HASH)" > /dev/null
```

### 3. Admin panel features

| Feature | Description |
|---------|-------------|
| **Run Parser** | Import new log files from the log directory |
| **Bans** | Ban/unban players by name |
| **Clan tags** | Add clan tag prefixes to group players in rankings |
| **Change password** | Update the admin panel password |

---

## Ports

| Port | Description |
|------|-------------|
| `8080` | Modern UI (if installed) |
| `8081` | Classic selectbf PHP UI (if installed) |
| `8000` | FastAPI backend — internal only, proxied by nginx |

---

## File layout

```
/opt/bfvstats/
    api.py              FastAPI application
    venv/               Python virtual environment
    .env                Config + admin password hash (chmod 640, root:www-data)
    requirements.txt    Python package versions

/var/www/bfvstats/
    index.html          Modern SPA frontend

/var/www/selectbf/
    ...                 Classic selectbf PHP files

/etc/nginx/sites-available/
    bfvstats            nginx config for modern UI (port 8080)
    selectbf            nginx config for classic UI (port 8081)

/etc/systemd/system/
    bfvstats-api.service    FastAPI backend service
```

---

## Troubleshooting

### Stats page is blank / API errors
```bash
systemctl status bfvstats-api
journalctl -u bfvstats-api -n 50
```

### nginx won't start
```bash
nginx -t
journalctl -u nginx -n 30
```

### Database connection error
Check credentials in `/opt/bfvstats/.env`.  
Test connection: `mysql -u bfvstats -p bfvstats`

### Parser finds no logs
Check the log directory path in `.env` (`BFV_LOG_DIR`).  
Make sure the files are readable:
```bash
ls -la $BFV_LOG_DIR
chmod a+r $BFV_LOG_DIR/*.log
```

### Live server status shows Offline
The API queries the BFV server via GameSpy UDP on `BFV_HOST:BFV_QUERY_PORT`.  
Check the port is reachable:
```bash
nc -u -z -w2 <BFV_HOST> 23000 && echo open || echo closed
```

---

## Updating

```bash
cd /opt/bfvstats
curl -fsSL https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main/web/api.py \
    -o api.py
systemctl restart bfvstats-api

curl -fsSL https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main/web/index.html \
    -o /var/www/bfvstats/index.html
```

> **Note:** After updating `index.html`, re-apply your site name and branding, or re-run the installer.

---

## What's been updated from the original selectbf

The original [selectbf](https://github.com/toadle/selectbf) is legacy software from ~2005.  
Its own README states: *"Full scale development has ceased for about 10 years now."*

This project keeps selectbf's log parser and classic PHP UI as an optional component, but wraps it in a modern, maintained stack:

| Area | Original selectbf | This project |
|------|-------------------|--------------|
| **PHP** | PHP 4.3 — 8.x (barely) | PHP 8.2+ fully supported |
| **Database** | MySQL 4.0 | MariaDB 10.x / MySQL 8 |
| **Web server** | Any — manual config | nginx, auto-configured |
| **Log access** | FTP download only | Local path, bind-mount, rsync, or sshfs |
| **Setup** | Manual: edit config files, run `_setup.php` in browser | Fully automated one-line installer |
| **Admin auth** | MD5 password (PHP session) | bcrypt hash (modern UI) |
| **Stats UI** | Classic PHP pages only | Optional modern SPA with dark/light theme, live scoreboard, rankings, player profiles |
| **Live server** | Not included | GameSpy UDP query — live player list, scores, tickets |
| **Live chat** | Not included | Real-time BFV chat log parsed from XML |
| **Ban management** | Not included | Admin panel — sync from `serverbanlist.con`, add/remove bans |
| **Duplicate games** | Parser re-processes files, creates duplicates | Dedup filter in API + rsync exclusion list |
| **Parser trigger** | Manual or FTP cron | HTTP API endpoint + optional cron |

The selectbf PHP parser itself (log parsing logic) is unchanged — it is what reads the BFV XML log files and populates the database. Everything around it has been modernised.

---

## Credits

- [selectbf](https://github.com/toadle/selectbf) — original BFV log parser and classic stats UI
- Modern UI + FastAPI backend by [Mati-l33t](https://github.com/Mati-l33t)
