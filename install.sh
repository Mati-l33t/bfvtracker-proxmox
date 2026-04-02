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

# ── Detect Debian ─────────────────────────────────────────────────────────────
[[ -f /etc/debian_version ]] || error "This installer requires Debian/Ubuntu."
DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)

# ── Repo base URL ─────────────────────────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/Mati-l33t/bfvtracker-proxmox/main"

# ─────────────────────────────────────────────────────────────────────────────
# WELCOME
# ─────────────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "  ██████╗ ███████╗██╗   ██╗    ████████╗██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗ "
echo "  ██╔══██╗██╔════╝██║   ██║    ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗"
echo "  ██████╔╝█████╗  ██║   ██║       ██║   ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝"
echo "  ██╔══██╗██╔══╝  ╚██╗ ██╔╝       ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗"
echo "  ██████╔╝██║      ╚████╔╝        ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║"
echo "  ╚═════╝ ╚═╝       ╚═══╝         ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  Battlefield Vietnam Stats Tracker — LXC Installer"
echo -e "  https://github.com/Mati-l33t/bfvtracker-proxmox\n"

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION PROMPTS
# ─────────────────────────────────────────────────────────────────────────────
header "Configuration"

# UI choice
echo -e "Which web UI would you like to install?\n"
echo -e "  ${BOLD}1)${NC} Modern UI     — Dark SPA with live stats, rankings, admin panel (port 8080)"
echo -e "  ${BOLD}2)${NC} Classic UI    — Original selectbf PHP stats page (port 8081)"
echo -e "  ${BOLD}3)${NC} Both          — Modern on :8080, classic on :8081\n"
while true; do
    read -rp "  Choice [1/2/3]: " UI_CHOICE
    case "$UI_CHOICE" in
        1|2|3) break ;;
        *) warn "Please enter 1, 2, or 3." ;;
    esac
done

# Admin password (only needed for modern UI)
if [[ "$UI_CHOICE" != "2" ]]; then
    echo ""
    while true; do
        read -rsp "  Admin password for web panel: " ADMIN_PASS; echo
        read -rsp "  Confirm admin password:        " ADMIN_PASS2; echo
        [[ "$ADMIN_PASS" == "$ADMIN_PASS2" ]] && break
        warn "Passwords do not match. Try again."
    done
    [[ -z "$ADMIN_PASS" ]] && error "Admin password cannot be empty."
fi

# Server name
echo ""
read -rp "  Server display name [GmV AIR WARS]: " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-GmV AIR WARS}"

# BFV game server host/ports
read -rp "  BFV server host/IP [10.0.0.70]: " BFV_HOST
BFV_HOST="${BFV_HOST:-10.0.0.70}"

read -rp "  BFV game port [15567]: " BFV_GAME_PORT
BFV_GAME_PORT="${BFV_GAME_PORT:-15567}"

read -rp "  BFV GameSpy query port [23000]: " BFV_QUERY_PORT
BFV_QUERY_PORT="${BFV_QUERY_PORT:-23000}"

# BFV log directory
read -rp "  BFV log directory [/opt/bfv/mods/bfvietnam/logs]: " BFV_LOG_DIR
BFV_LOG_DIR="${BFV_LOG_DIR:-/opt/bfv/mods/bfvietnam/logs}"

# Database config
echo ""
echo -e "  ${BOLD}Database configuration${NC}"
read -rp "  DB host [localhost]: " DB_HOST; DB_HOST="${DB_HOST:-localhost}"
read -rp "  DB port [3306]: "      DB_PORT; DB_PORT="${DB_PORT:-3306}"
read -rp "  DB name [bfvstats]: "  DB_NAME; DB_NAME="${DB_NAME:-bfvstats}"
read -rp "  DB user [bfvstats]: "  DB_USER; DB_USER="${DB_USER:-bfvstats}"

# Auto-generate a DB password if not provided
DB_PASS_DEFAULT=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true)
read -rsp "  DB password [auto-generated]: " DB_PASS; echo
DB_PASS="${DB_PASS:-$DB_PASS_DEFAULT}"

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
header "Summary"
case "$UI_CHOICE" in
    1) UI_DESC="Modern UI only (port 8080)" ;;
    2) UI_DESC="Classic selectbf UI only (port 8081)" ;;
    3) UI_DESC="Both UIs (modern :8080, classic :8081)" ;;
esac

echo -e "  UI:           ${BOLD}$UI_DESC${NC}"
echo -e "  Server name:  $SERVER_NAME"
echo -e "  BFV host:     $BFV_HOST  game:$BFV_GAME_PORT  query:$BFV_QUERY_PORT"
echo -e "  Log dir:      $BFV_LOG_DIR"
echo -e "  DB:           $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""
read -rp "  Proceed with installation? [y/N]: " CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { info "Aborted."; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
# INSTALL DEPENDENCIES
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
    # Classic UI needs PHP
    info "Installing PHP for classic UI..."
    apt-get install -y -qq \
        php \
        php-fpm \
        php-mysql \
        php-mbstring \
        php-xml \
        php-gd
    PHP_FPM_SOCK=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1 || echo "/run/php/php8.2-fpm.sock")
    PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.2")
fi
success "System packages installed."

# ─────────────────────────────────────────────────────────────────────────────
# MARIADB SETUP
# ─────────────────────────────────────────────────────────────────────────────
header "Setting up MariaDB"
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
# SELECTBF INSTALL (classic or both)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$UI_CHOICE" != "1" ]]; then
    header "Installing selectbf (classic UI)"
    SELECTBF_DIR="/var/www/selectbf"
    mkdir -p "$SELECTBF_DIR"

    # Download selectbf — try to grab a known release or fall back to cloning
    SELECTBF_ZIP_URL="https://github.com/select-bf/selectbf/archive/refs/heads/master.zip"
    info "Downloading selectbf..."
    if curl -fsSL "$SELECTBF_ZIP_URL" -o /tmp/selectbf.zip 2>/dev/null; then
        unzip -q /tmp/selectbf.zip -d /tmp/selectbf_src
        SRC_DIR=$(ls -d /tmp/selectbf_src/selectbf-*/ 2>/dev/null | head -1)
        if [[ -d "$SRC_DIR" ]]; then
            cp -r "$SRC_DIR"/* "$SELECTBF_DIR/"
        fi
        rm -rf /tmp/selectbf.zip /tmp/selectbf_src
    else
        warn "Could not download selectbf automatically."
        warn "Place selectbf files in $SELECTBF_DIR manually and re-run: systemctl restart nginx php${PHP_VER}-fpm"
    fi

    # Write selectbf config if config.php exists
    SELECTBF_CFG="$SELECTBF_DIR/config.php"
    if [[ -f "$SELECTBF_CFG" ]]; then
        sed -i "s/define('DB_HOST'.*/define('DB_HOST', '${DB_HOST}');/" "$SELECTBF_CFG" || true
        sed -i "s/define('DB_USER'.*/define('DB_USER', '${DB_USER}');/" "$SELECTBF_CFG" || true
        sed -i "s/define('DB_PASS'.*/define('DB_PASS', '${DB_PASS}');/" "$SELECTBF_CFG" || true
        sed -i "s/define('DB_NAME'.*/define('DB_NAME', '${DB_NAME}');/" "$SELECTBF_CFG" || true
    fi

    chown -R www-data:www-data "$SELECTBF_DIR"
    success "selectbf installed to $SELECTBF_DIR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# MODERN UI INSTALL
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$UI_CHOICE" != "2" ]]; then
    header "Installing modern UI + FastAPI backend"

    # Python venv
    INSTALL_DIR="/opt/bfvstats"
    mkdir -p "$INSTALL_DIR"
    python3 -m venv "$INSTALL_DIR/venv"

    # requirements.txt
    curl -fsSL "${REPO_RAW}/requirements.txt" -o "$INSTALL_DIR/requirements.txt"
    "$INSTALL_DIR/venv/bin/pip" install -q --upgrade pip
    "$INSTALL_DIR/venv/bin/pip" install -q -r "$INSTALL_DIR/requirements.txt"
    success "Python venv ready."

    # api.py
    curl -fsSL "${REPO_RAW}/web/api.py" -o "$INSTALL_DIR/api.py"
    success "api.py installed."

    # frontend
    WEB_DIR="/var/www/bfvstats"
    mkdir -p "$WEB_DIR"
    curl -fsSL "${REPO_RAW}/web/index.html" -o "$WEB_DIR/index.html"
    success "index.html installed."

    # Generate admin password hash  (salt:sha256)
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

    # DB schema — create clan_tags table and performance indexes
    mysql -u root "$DB_NAME" <<SQL
CREATE TABLE IF NOT EXISTS selectbf_clan_tags (
    id    INT AUTO_INCREMENT PRIMARY KEY,
    tag   VARCHAR(32) NOT NULL UNIQUE,
    added DATETIME DEFAULT NOW()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Performance indexes (safe to run if they already exist)
CREATE INDEX IF NOT EXISTS idx_ps_round_id     ON selectbf_playerstats (round_id);
CREATE INDEX IF NOT EXISTS idx_games_starttime ON selectbf_games       (starttime);
CREATE INDEX IF NOT EXISTS idx_rounds_game_id  ON selectbf_rounds      (game_id);
SQL
    success "DB schema / indexes applied."

    # systemd service
    curl -fsSL "${REPO_RAW}/systemd/bfvstats-api.service" \
        -o /etc/systemd/system/bfvstats-api.service
    systemctl daemon-reload
    systemctl enable --quiet bfvstats-api
    systemctl restart bfvstats-api
    success "bfvstats-api service started."
fi

# ─────────────────────────────────────────────────────────────────────────────
# NGINX CONFIG
# ─────────────────────────────────────────────────────────────────────────────
header "Configuring nginx"

# Remove default site
rm -f /etc/nginx/sites-enabled/default

case "$UI_CHOICE" in
    1)
        curl -fsSL "${REPO_RAW}/config/nginx-modern.conf" \
            -o /etc/nginx/sites-available/bfvstats
        ln -sfn /etc/nginx/sites-available/bfvstats \
                /etc/nginx/sites-enabled/bfvstats
        rm -f /etc/nginx/sites-enabled/selectbf
        ;;
    2)
        # Patch PHP socket into classic config before writing
        CLASSIC_CONF=$(curl -fsSL "${REPO_RAW}/config/nginx-classic.conf")
        echo "$CLASSIC_CONF" \
            | sed "s|php8.4-fpm.sock|php${PHP_VER}-fpm.sock|g" \
            > /etc/nginx/sites-available/selectbf
        ln -sfn /etc/nginx/sites-available/selectbf \
                /etc/nginx/sites-enabled/selectbf
        rm -f /etc/nginx/sites-enabled/bfvstats
        ;;
    3)
        curl -fsSL "${REPO_RAW}/config/nginx-modern.conf" \
            -o /etc/nginx/sites-available/bfvstats
        ln -sfn /etc/nginx/sites-available/bfvstats \
                /etc/nginx/sites-enabled/bfvstats

        CLASSIC_CONF=$(curl -fsSL "${REPO_RAW}/config/nginx-classic.conf")
        echo "$CLASSIC_CONF" \
            | sed "s|php8.4-fpm.sock|php${PHP_VER}-fpm.sock|g" \
            > /etc/nginx/sites-available/selectbf
        ln -sfn /etc/nginx/sites-available/selectbf \
                /etc/nginx/sites-enabled/selectbf
        ;;
esac

nginx -t && systemctl restart nginx
success "nginx configured and restarted."

if [[ "$UI_CHOICE" != "1" ]]; then
    systemctl enable --quiet "php${PHP_VER}-fpm"
    systemctl restart "php${PHP_VER}-fpm"
    success "php-fpm restarted."
fi

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
header "Installation complete"
HOST_IP=$(hostname -I | awk '{print $1}')

case "$UI_CHOICE" in
    1)
        echo -e "  Modern UI:   ${BOLD}http://${HOST_IP}:8080/${NC}"
        echo -e "  Admin panel: click ${BOLD}Admin${NC} in the nav bar, password: ${BOLD}(what you entered)${NC}"
        ;;
    2)
        echo -e "  Classic UI:  ${BOLD}http://${HOST_IP}:8081/${NC}"
        ;;
    3)
        echo -e "  Modern UI:   ${BOLD}http://${HOST_IP}:8080/${NC}"
        echo -e "  Classic UI:  ${BOLD}http://${HOST_IP}:8081/${NC}"
        echo -e "  Admin panel: click ${BOLD}Admin${NC} in the modern UI nav bar"
        ;;
esac

echo ""
echo -e "  ${YELLOW}Note:${NC} The BFV server log parser runs via the admin panel."
echo -e "  Point your BFV dedicated server logs at: ${BOLD}${BFV_LOG_DIR}${NC}"
echo ""
