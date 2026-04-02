#!/usr/bin/env bash
# BFV Tracker — Proxmox LXC installer
# Repo: https://github.com/Mati-l33t/bfvtracker-proxmox
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run as root (sudo ./install.sh)"

# ── Detect Debian/Ubuntu ──────────────────────────────────────────────────────
[[ -f /etc/debian_version ]] || error "This installer requires Debian or Ubuntu."

# ── Repo base URL ─────────────────────────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main"

# ─────────────────────────────────────────────────────────────────────────────
# WELCOME
# ─────────────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
cat <<'BANNER'
  ██████╗ ███████╗██╗   ██╗    ████████╗██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗
  ██╔══██╗██╔════╝██║   ██║    ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
  ██████╔╝█████╗  ██║   ██║       ██║   ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝
  ██╔══██╗██╔══╝  ╚██╗ ██╔╝       ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
  ██████╔╝██║      ╚████╔╝        ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║
  ╚═════╝ ╚═╝       ╚═══╝         ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
BANNER
echo -e "${NC}"
echo -e "  Battlefield Vietnam Stats Tracker — Installer"
echo -e "  https://github.com/Mati-l33t/bfvtracker-proxmox\n"

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION PROMPTS
# ─────────────────────────────────────────────────────────────────────────────
header "Step 1 — Web UI"

echo -e "Which web UI would you like to install?\n"
echo -e "  ${BOLD}1)${NC} Modern UI     — Dark SPA with live stats, rankings, admin panel (port 8080)"
echo -e "  ${BOLD}2)${NC} Classic UI    — Original selectbf PHP stats page (port 8081)"
echo -e "  ${BOLD}3)${NC} Both          — Modern on :8080, classic on :8081\n"
while true; do
    read -rp "  Choice [1/2/3]: " UI_CHOICE
    case "$UI_CHOICE" in 1|2|3) break ;; *) warn "Please enter 1, 2, or 3." ;; esac
done

# ─── Admin password (modern UI only) ─────────────────────────────────────────
if [[ "$UI_CHOICE" != "2" ]]; then
    header "Step 2 — Admin password"
    echo -e "  This password protects the admin panel (ban players, run parser, manage clans).\n"
    while true; do
        read -rsp "  Admin password: " ADMIN_PASS; echo
        read -rsp "  Confirm:        " ADMIN_PASS2; echo
        [[ "$ADMIN_PASS" == "$ADMIN_PASS2" ]] && break
        warn "Passwords do not match. Try again."
    done
    [[ -z "$ADMIN_PASS" ]] && error "Admin password cannot be empty."
fi

# ─── Site branding ────────────────────────────────────────────────────────────
if [[ "$UI_CHOICE" != "2" ]]; then
    header "Step 3 — Site branding"

    read -rp "  Site / clan name (shown in the header and page title) [BFV Server]: " SITE_TITLE
    SITE_TITLE="${SITE_TITLE:-BFV Server}"

    read -rp "  Forum URL (leave blank to hide the Forum link): " FORUM_URL

    read -rp "  Logo image URL (leave blank to skip — default logo used): " LOGO_URL
fi

# ─── BFV game server ──────────────────────────────────────────────────────────
header "Step 4 — BFV game server"
echo -e "  The stats tracker queries your BFV server for live status."
echo -e "  The server can be on a different machine/LXC as long as it is reachable.\n"

read -rp "  BFV server host/IP: " BFV_HOST
[[ -z "$BFV_HOST" ]] && error "BFV host is required."

read -rp "  BFV game port [15567]: "         BFV_GAME_PORT;  BFV_GAME_PORT="${BFV_GAME_PORT:-15567}"
read -rp "  BFV GameSpy query port [23000]: " BFV_QUERY_PORT; BFV_QUERY_PORT="${BFV_QUERY_PORT:-23000}"

# ─── Log directory ────────────────────────────────────────────────────────────
header "Step 5 — Log directory"
echo -e "  The tracker parses BFV server log files to populate the stats database."
echo -e "  The logs must be accessible from this machine."
echo -e ""
echo -e "  ${BOLD}If your BFV server is on the same machine:${NC}"
echo -e "    Default BFV log path: /opt/bfv/mods/bfvietnam/logs"
echo -e ""
echo -e "  ${BOLD}If your BFV server is on a different machine (remote):${NC}"
echo -e "    Set up rsync or sshfs to mount the remote log dir here first."
echo -e "    See README.md — 'Getting logs from a remote BFV server'.\n"

read -rp "  Path to BFV log directory: " BFV_LOG_DIR
[[ -z "$BFV_LOG_DIR" ]] && error "Log directory path is required."

# ─── Database ────────────────────────────────────────────────────────────────
header "Step 6 — Database"
echo -e "  MariaDB will be installed and configured automatically.\n"

read -rp "  DB name [bfvstats]: " DB_NAME; DB_NAME="${DB_NAME:-bfvstats}"
read -rp "  DB user [bfvstats]: " DB_USER; DB_USER="${DB_USER:-bfvstats}"
DB_PASS_DEFAULT=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true)
read -rsp "  DB password [auto-generate]: " DB_PASS; echo
DB_PASS="${DB_PASS:-$DB_PASS_DEFAULT}"
read -rp "  DB host [localhost]: " DB_HOST; DB_HOST="${DB_HOST:-localhost}"
read -rp "  DB port [3306]: "      DB_PORT; DB_PORT="${DB_PORT:-3306}"

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
header "Summary — review before installing"
case "$UI_CHOICE" in
    1) UI_DESC="Modern UI only (port 8080)" ;;
    2) UI_DESC="Classic selectbf UI only (port 8081)" ;;
    3) UI_DESC="Both UIs (modern :8080, classic :8081)" ;;
esac
echo -e "  UI:           ${BOLD}$UI_DESC${NC}"
[[ "$UI_CHOICE" != "2" ]] && echo -e "  Site name:    $SITE_TITLE"
[[ "$UI_CHOICE" != "2" && -n "${FORUM_URL:-}" ]] && echo -e "  Forum URL:    $FORUM_URL"
echo -e "  BFV host:     $BFV_HOST  game:$BFV_GAME_PORT  query:$BFV_QUERY_PORT"
echo -e "  Log dir:      $BFV_LOG_DIR"
echo -e "  DB:           $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""
read -rp "  Proceed with installation? [y/N]: " CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { info "Aborted."; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM PACKAGES
# ─────────────────────────────────────────────────────────────────────────────
header "Installing system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    nginx \
    mariadb-server \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    git \
    unzip

if [[ "$UI_CHOICE" != "1" ]]; then
    info "Installing PHP for classic UI..."
    apt-get install -y -qq \
        php php-fpm php-mysql php-mbstring php-xml php-gd
    PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.2")
    PHP_FPM_SOCK="/run/php/php${PHP_VER}-fpm.sock"
fi
success "System packages installed."

# ─────────────────────────────────────────────────────────────────────────────
# MARIADB
# ─────────────────────────────────────────────────────────────────────────────
header "Configuring MariaDB"
systemctl enable --quiet mariadb
systemctl start mariadb

mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${DB_HOST}';
FLUSH PRIVILEGES;
SQL
success "Database '${DB_NAME}' and user '${DB_USER}' ready."

# ─────────────────────────────────────────────────────────────────────────────
# SELECTBF (classic UI)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$UI_CHOICE" != "1" ]]; then
    header "Installing selectbf (classic UI)"
    SELECTBF_DIR="/var/www/selectbf"
    mkdir -p "$SELECTBF_DIR"

    SELECTBF_ZIP_URL="https://github.com/select-bf/selectbf/archive/refs/heads/master.zip"
    info "Downloading selectbf..."
    if curl -fsSL "$SELECTBF_ZIP_URL" -o /tmp/selectbf.zip 2>/dev/null; then
        unzip -q /tmp/selectbf.zip -d /tmp/selectbf_src
        SRC_DIR=$(ls -d /tmp/selectbf_src/selectbf-*/ 2>/dev/null | head -1 || true)
        if [[ -d "${SRC_DIR:-}" ]]; then
            cp -r "$SRC_DIR"/* "$SELECTBF_DIR/"
            success "selectbf files extracted."
        fi
        rm -rf /tmp/selectbf.zip /tmp/selectbf_src
    else
        warn "Could not download selectbf automatically."
        warn "Place selectbf files in $SELECTBF_DIR manually, then: systemctl restart nginx php${PHP_VER}-fpm"
    fi

    SELECTBF_CFG="$SELECTBF_DIR/config.php"
    if [[ -f "$SELECTBF_CFG" ]]; then
        sed -i "s/define('DB_HOST'.*/define('DB_HOST', '${DB_HOST}');/"   "$SELECTBF_CFG" || true
        sed -i "s/define('DB_USER'.*/define('DB_USER', '${DB_USER}');/"   "$SELECTBF_CFG" || true
        sed -i "s/define('DB_PASS'.*/define('DB_PASS', '${DB_PASS}');/"   "$SELECTBF_CFG" || true
        sed -i "s/define('DB_NAME'.*/define('DB_NAME', '${DB_NAME}');/"   "$SELECTBF_CFG" || true
        sed -i "s/define('LOG_DIR'.*/define('LOG_DIR', '${BFV_LOG_DIR}');/" "$SELECTBF_CFG" || true
    fi

    chown -R www-data:www-data "$SELECTBF_DIR"
    success "selectbf installed to $SELECTBF_DIR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# MODERN UI + FASTAPI
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$UI_CHOICE" != "2" ]]; then
    header "Installing modern UI + FastAPI backend"

    INSTALL_DIR="/opt/bfvstats"
    WEB_DIR="/var/www/bfvstats"
    mkdir -p "$INSTALL_DIR" "$WEB_DIR"

    # Python venv
    python3 -m venv "$INSTALL_DIR/venv"
    curl -fsSL "${REPO_RAW}/requirements.txt" -o "$INSTALL_DIR/requirements.txt"
    "$INSTALL_DIR/venv/bin/pip" install -q --upgrade pip
    "$INSTALL_DIR/venv/bin/pip" install -q -r "$INSTALL_DIR/requirements.txt"
    success "Python venv ready."

    # api.py
    curl -fsSL "${REPO_RAW}/web/api.py" -o "$INSTALL_DIR/api.py"
    success "api.py installed."

    # index.html — download then patch placeholders
    curl -fsSL "${REPO_RAW}/web/index.html" -o "$WEB_DIR/index.html"

    # Build forum link HTML (empty = hidden)
    if [[ -n "${FORUM_URL:-}" ]]; then
        FORUM_LINK="<a href=\"${FORUM_URL}\" target=\"_blank\" rel=\"noopener\">Forum</a>"
    else
        FORUM_LINK=""
    fi

    # Logo: download custom or use inline SVG fallback
    if [[ -n "${LOGO_URL:-}" ]]; then
        LOGO_FILE="logo.png"
        if curl -fsSL "$LOGO_URL" -o "$WEB_DIR/$LOGO_FILE" 2>/dev/null; then
            success "Custom logo downloaded."
        else
            warn "Could not download logo from $LOGO_URL — using default."
            LOGO_FILE="logo-default.svg"
            # Minimal SVG shield as fallback
            cat > "$WEB_DIR/$LOGO_FILE" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><path d="M16 2L4 7v9c0 7 5.3 13.1 12 15 6.7-1.9 12-8 12-15V7z" fill="#e08820"/><text x="16" y="20" text-anchor="middle" fill="#fff" font-size="10" font-family="sans-serif" font-weight="bold">BFV</text></svg>
SVG
        fi
    else
        LOGO_FILE="logo-default.svg"
        cat > "$WEB_DIR/$LOGO_FILE" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><path d="M16 2L4 7v9c0 7 5.3 13.1 12 15 6.7-1.9 12-8 12-15V7z" fill="#e08820"/><text x="16" y="20" text-anchor="middle" fill="#fff" font-size="10" font-family="sans-serif" font-weight="bold">BFV</text></svg>
SVG
    fi

    # Patch placeholders in index.html (use | as sed delimiter to avoid URL slash issues)
    sed -i \
        -e "s|__SITE_TITLE__|${SITE_TITLE}|g" \
        -e "s|__LOGO_FILE__|${LOGO_FILE}|g" \
        -e "s|__FORUM_LINK__|${FORUM_LINK}|g" \
        -e "s|__SERVER_NAME__|${SERVER_NAME:-${SITE_TITLE}}|g" \
        -e "s|__BFV_HOST__|${BFV_HOST}|g" \
        -e "s|__BFV_GAME_PORT__|${BFV_GAME_PORT}|g" \
        "$WEB_DIR/index.html"
    success "index.html patched with site settings."

    # Admin password hash  (salt:sha256)
    ADMIN_SALT=$(tr -dc 'a-f0-9' </dev/urandom | head -c 16 || true)
    ADMIN_HASH=$(echo -n "${ADMIN_SALT}${ADMIN_PASS}" | sha256sum | cut -d' ' -f1)

    # .env
    cat > "$INSTALL_DIR/.env" <<ENV
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
ADMIN_PASS_HASH=${ADMIN_SALT}:${ADMIN_HASH}
WEB_PORT=8080
BFV_LOG_DIR=${BFV_LOG_DIR}
BFV_MOD=bfvietnam
BFV_HOST=${BFV_HOST}
BFV_QUERY_PORT=${BFV_QUERY_PORT}
BFV_GAME_PORT=${BFV_GAME_PORT}
ENV
    chmod 640 "$INSTALL_DIR/.env"
    chown root:www-data "$INSTALL_DIR/.env"
    chown -R www-data:www-data "$INSTALL_DIR" "$WEB_DIR"
    success ".env written."

    # DB schema extras
    mysql -u root "$DB_NAME" <<SQL
CREATE TABLE IF NOT EXISTS selectbf_clan_tags (
    id    INT AUTO_INCREMENT PRIMARY KEY,
    tag   VARCHAR(32) NOT NULL UNIQUE,
    added DATETIME DEFAULT NOW()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX IF NOT EXISTS idx_ps_round_id     ON selectbf_playerstats (round_id);
CREATE INDEX IF NOT EXISTS idx_games_starttime ON selectbf_games       (starttime);
CREATE INDEX IF NOT EXISTS idx_rounds_game_id  ON selectbf_rounds      (game_id);
SQL
    success "DB schema and indexes applied."

    # systemd service
    curl -fsSL "${REPO_RAW}/systemd/bfvstats-api.service" \
        -o /etc/systemd/system/bfvstats-api.service
    systemctl daemon-reload
    systemctl enable --quiet bfvstats-api
    systemctl restart bfvstats-api
    success "bfvstats-api service started."
fi

# ─────────────────────────────────────────────────────────────────────────────
# NGINX
# ─────────────────────────────────────────────────────────────────────────────
header "Configuring nginx"
rm -f /etc/nginx/sites-enabled/default

case "$UI_CHOICE" in
    1)
        curl -fsSL "${REPO_RAW}/config/nginx-modern.conf" \
            -o /etc/nginx/sites-available/bfvstats
        ln -sfn /etc/nginx/sites-available/bfvstats /etc/nginx/sites-enabled/bfvstats
        rm -f /etc/nginx/sites-enabled/selectbf
        ;;
    2)
        curl -fsSL "${REPO_RAW}/config/nginx-classic.conf" \
            | sed "s|php8.4-fpm.sock|php${PHP_VER}-fpm.sock|g" \
            > /etc/nginx/sites-available/selectbf
        ln -sfn /etc/nginx/sites-available/selectbf /etc/nginx/sites-enabled/selectbf
        rm -f /etc/nginx/sites-enabled/bfvstats
        ;;
    3)
        curl -fsSL "${REPO_RAW}/config/nginx-modern.conf" \
            -o /etc/nginx/sites-available/bfvstats
        ln -sfn /etc/nginx/sites-available/bfvstats /etc/nginx/sites-enabled/bfvstats

        curl -fsSL "${REPO_RAW}/config/nginx-classic.conf" \
            | sed "s|php8.4-fpm.sock|php${PHP_VER}-fpm.sock|g" \
            > /etc/nginx/sites-available/selectbf
        ln -sfn /etc/nginx/sites-available/selectbf /etc/nginx/sites-enabled/selectbf
        ;;
esac

nginx -t && systemctl restart nginx
success "nginx configured and restarted."

if [[ "$UI_CHOICE" != "1" ]]; then
    systemctl enable --quiet "php${PHP_VER}-fpm"
    systemctl restart "php${PHP_VER}-fpm"
    success "php${PHP_VER}-fpm restarted."
fi

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
header "Installation complete!"
HOST_IP=$(hostname -I | awk '{print $1}')

echo -e "  ${BOLD}Your stats tracker is ready.${NC}\n"
case "$UI_CHOICE" in
    1) echo -e "  Modern UI:   ${BOLD}http://${HOST_IP}:8080/${NC}" ;;
    2) echo -e "  Classic UI:  ${BOLD}http://${HOST_IP}:8081/${NC}" ;;
    3) echo -e "  Modern UI:   ${BOLD}http://${HOST_IP}:8080/${NC}"
       echo -e "  Classic UI:  ${BOLD}http://${HOST_IP}:8081/${NC}" ;;
esac
echo ""
if [[ "$UI_CHOICE" != "2" ]]; then
    echo -e "  ${BOLD}Admin panel:${NC} click ${BOLD}Admin${NC} in the nav bar and enter your password."
    echo -e "  ${BOLD}Run parser:${NC}  Admin → Run Parser to import existing log files."
fi
echo ""
echo -e "  ${YELLOW}Tip:${NC} Save your DB password — it was written to /opt/bfvstats/.env"
if [[ "${DB_PASS}" == "${DB_PASS_DEFAULT:-}" ]]; then
    echo -e "  ${YELLOW}Auto-generated DB password:${NC} ${BOLD}${DB_PASS}${NC}"
fi
echo ""
