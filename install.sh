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

# ─── Admin password (both UIs need one) ──────────────────────────────────────
header "Step 2 — Admin password"
case "$UI_CHOICE" in
    1) echo -e "  Protects the modern UI admin panel (ban players, run parser, manage clans).\n" ;;
    2) echo -e "  Protects the classic selectbf admin panel.\n" ;;
    3) echo -e "  One password used for both the modern UI panel and the classic selectbf admin.\n" ;;
esac
while true; do
    read -rsp "  Admin password: " ADMIN_PASS; echo
    read -rsp "  Confirm:        " ADMIN_PASS2; echo
    [[ "$ADMIN_PASS" == "$ADMIN_PASS2" ]] && break
    warn "Passwords do not match. Try again."
done
[[ -z "$ADMIN_PASS" ]] && error "Admin password cannot be empty."

# ─── Site branding (modern UI only) ──────────────────────────────────────────
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
echo -e "  Admin pass:   (set)"
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

    # Write DB connection settings (selectbf uses include/sql_setting.php)
    cat > "$SELECTBF_DIR/include/sql_setting.php" <<PHP
<?php
\$SQL_host     = '${DB_HOST}';
\$SQL_user     = '${DB_USER}';
\$SQL_password = '${DB_PASS}';
\$SQL_datenbank = '${DB_NAME}';
?>
PHP

    # Run selectbf's own setup: create all tables, insert admin password (MD5) and default params
    SELECTBF_ADMIN_MD5=$(echo -n "$ADMIN_PASS" | md5sum | cut -d' ' -f1)
    mysql -u root "$DB_NAME" <<SQL
-- selectbf core tables
CREATE TABLE IF NOT EXISTS \`selectbf_admin\` (\`id\` int(10) NOT NULL auto_increment, \`name\` text, \`value\` text, \`inserttime\` datetime default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_cache_chartypeusage\` (\`kit\` varchar(255) NOT NULL default '', \`percentage\` float default NULL, \`times_used\` int(10) default NULL, PRIMARY KEY (\`kit\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_cache_mapstats\` (\`map\` varchar(100) NOT NULL default '0', \`wins_team1\` int(10) default NULL, \`wins_team2\` int(10) default NULL, \`win_team1_tickets_team1\` float default NULL, \`win_team1_tickets_team2\` float default NULL, \`win_team2_tickets_team1\` float default NULL, \`win_team2_tickets_team2\` float default NULL, \`score_team1\` int(10) default NULL, \`score_team2\` int(10) default NULL, \`kills_team1\` int(10) default NULL, \`kills_team2\` int(10) default NULL, \`deaths_team1\` int(10) default NULL, \`deaths_team2\` int(10) default NULL, \`attacks_team1\` int(10) default NULL, \`attacks_team2\` int(10) default NULL, \`captures_team1\` int(10) default NULL, \`captures_team2\` int(10) default NULL, PRIMARY KEY (\`map\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_cache_ranking\` (\`rank\` int(10) default NULL, \`player_id\` int(10) NOT NULL default '0', \`playername\` varchar(100) default NULL, \`score\` int(10) default NULL, \`kills\` int(10) default NULL, \`deaths\` int(10) default NULL, \`kdrate\` double default NULL, \`score_per_minute\` double default NULL, \`tks\` int(10) default NULL, \`captures\` int(10) default NULL, \`attacks\` int(10) default NULL, \`defences\` int(10) default NULL, \`objectives\` int(10) default NULL, \`objectivetks\` int(10) default NULL, \`heals\` int(10) default NULL, \`selfheals\` int(10) default NULL, \`repairs\` int(10) default NULL, \`otherrepairs\` int(10) default NULL, \`first\` int(10) default NULL, \`second\` int(10) default NULL, \`third\` int(10) default NULL, \`playtime\` double default NULL, \`rounds_played\` int(10) default NULL, \`last_visit\` datetime default NULL, PRIMARY KEY (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_cache_vehicletime\` (\`vehicle\` varchar(100) NOT NULL default '', \`time\` float default NULL, \`percentage_time\` float default NULL, \`times_used\` int(10) default NULL, \`percentage_usage\` float default NULL, PRIMARY KEY (\`vehicle\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_cache_weaponkills\` (\`weapon\` varchar(50) NOT NULL default '', \`kills\` int(10) default NULL, \`percentage\` float default NULL, PRIMARY KEY (\`weapon\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_category\` (\`id\` int(10) NOT NULL auto_increment, \`name\` varchar(50) default NULL, \`collect_data\` int(10) default NULL, \`datasource_name\` varchar(50) default NULL, \`type\` varchar(50) default NULL, \`inserttime\` datetime default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_categorymember\` (\`member\` varchar(50) default NULL, \`category\` int(10) default NULL) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_chatlog\` (\`Id\` int(10) NOT NULL auto_increment, \`text\` text NOT NULL, \`player_id\` smallint(10) NOT NULL default '0', \`round_id\` int(10) default NULL, \`inserttime\` datetime default NULL, PRIMARY KEY (\`Id\`), KEY \`player_id\` (\`player_id\`), KEY \`round_id\` (\`round_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_clan_ranking\` (\`ranks\` int(10) default NULL, \`score\` float default NULL, \`clanname\` varchar(100) default NULL, \`members\` int(10) default NULL, \`kills\` float default NULL, \`deaths\` float default NULL, \`kdrate\` float default NULL, \`tks\` float default NULL, \`captures\` float default NULL, \`attacks\` float default NULL, \`defences\` float default NULL, \`objectives\` float default NULL, \`objectivetks\` float default NULL, \`heals\` float default NULL, \`selfheals\` float default NULL, \`repairs\` float default NULL, \`otherrepairs\` float default NULL, \`rounds_played\` float default NULL, \`first\` int(11) default NULL, \`second\` int(11) default NULL, \`third\` int(11) default NULL) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_clan_tags\` (\`clan_tag\` varchar(100) default NULL) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_cleartext\` (\`id\` int(10) NOT NULL auto_increment, \`original\` varchar(50) default NULL, \`custom\` varchar(100) default NULL, \`type\` varchar(50) default NULL, \`inserttime\` datetime default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_drives\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`vehicle\` tinytext, \`drivetime\` float default '0', \`times_used\` int(10) default '0', PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`), KEY \`player_id\` (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_games\` (\`id\` int(10) NOT NULL auto_increment, \`servername\` tinytext, \`modid\` tinytext, \`mapid\` tinytext, \`map\` tinytext, \`game_mode\` tinytext, \`gametime\` int(10) default NULL, \`maxplayers\` int(10) default NULL, \`scorelimit\` int(10) default NULL, \`spawntime\` int(10) default NULL, \`soldierff\` int(10) default NULL, \`vehicleff\` int(10) default NULL, \`tkpunish\` int(10) default NULL, \`deathcamtype\` int(10) default NULL, \`starttime\` datetime default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_heals\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`healed_player_id\` int(10) default NULL, \`amount\` int(10) default NULL, \`healtime\` float default NULL, \`times_healed\` int(10) default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`,\`healed_player_id\`), KEY \`player_id\` (\`player_id\`), KEY \`healed_player_id\` (\`healed_player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_kills_player\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`victim_id\` int(10) default NULL, \`times_killed\` int(10) default '0', PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`,\`victim_id\`), KEY \`player_id\` (\`player_id\`), KEY \`victim_id\` (\`victim_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_kills_weapon\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`weapon\` varchar(50) default '0', \`times_used\` int(10) default '0', PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`,\`weapon\`), KEY \`player_id\` (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_kits\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`kit\` text, \`times_used\` int(10) default '0', PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`), KEY \`player_id\` (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_modassignment\` (\`id\` int(10) NOT NULL auto_increment, \`item\` varchar(50) default NULL, \`mod\` varchar(50) default NULL, \`type\` varchar(50) default NULL, \`inserttime\` datetime default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_nicknames\` (\`nickname\` varchar(150) default NULL, \`times_used\` int(10) default NULL, \`player_id\` int(10) default NULL, KEY \`player_id\` (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_params\` (\`id\` int(10) NOT NULL auto_increment, \`name\` varchar(50) default NULL, \`value\` varchar(255) default NULL, \`inserttime\` datetime default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_players\` (\`id\` int(10) NOT NULL auto_increment, \`name\` varchar(150) default NULL, \`keyhash\` varchar(32) NOT NULL default '', \`inserttime\` datetime default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_playerstats\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`team\` int(10) default NULL, \`score\` int(10) default NULL, \`kills\` int(10) default NULL, \`deaths\` int(10) default NULL, \`tks\` int(10) default NULL, \`captures\` int(10) default NULL, \`attacks\` int(10) default NULL, \`defences\` int(10) default NULL, \`objectives\` int(10) default NULL, \`objectivetks\` int(10) default NULL, \`heals\` int(10) default NULL, \`selfheals\` int(10) default NULL, \`repairs\` int(10) default NULL, \`otherrepairs\` int(10) default NULL, \`round_id\` int(10) default NULL, \`first\` int(10) default NULL, \`second\` int(10) default NULL, \`third\` int(10) default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`,\`round_id\`), KEY \`player_id\` (\`player_id\`), KEY \`round_id\` (\`round_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_playtimes\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`last_seen\` datetime default NULL, \`playtime\` float default '0', \`slots_used\` int(10) default '0', PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`), KEY \`player_id\` (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_repairs\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`vehicle\` varchar(150) default NULL, \`amount\` int(10) default NULL, \`repairtime\` float default NULL, \`times_repaired\` int(10) default '0', PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`,\`vehicle\`), KEY \`player_id\` (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_rounds\` (\`id\` int(10) NOT NULL auto_increment, \`start_tickets_team1\` int(10) default NULL, \`start_tickets_team2\` int(10) default NULL, \`starttime\` datetime default NULL, \`end_tickets_team1\` int(10) default NULL, \`end_tickets_team2\` int(10) default NULL, \`endtime\` datetime default NULL, \`endtype\` tinytext, \`winning_team\` int(10) default '0', \`game_id\` int(10) default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`game_id\`), KEY \`game_id\` (\`game_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_selfkills\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`times_killed\` int(10) default NULL, PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`), KEY \`player_id\` (\`player_id\`)) ENGINE=MyISAM;
CREATE TABLE IF NOT EXISTS \`selectbf_tks\` (\`id\` int(10) NOT NULL auto_increment, \`player_id\` int(10) default NULL, \`victim_id\` int(10) default NULL, \`times_killed\` int(10) NOT NULL default '0', PRIMARY KEY (\`id\`), UNIQUE KEY \`id\` (\`id\`), KEY \`id_2\` (\`id\`,\`player_id\`,\`victim_id\`), KEY \`player_id\` (\`player_id\`), KEY \`victim_id\` (\`victim_id\`)) ENGINE=MyISAM;

-- Admin password and default params (only insert if table is empty)
INSERT IGNORE INTO selectbf_admin (name, value, inserttime) VALUES ('ADMIN_PSW', '${SELECTBF_ADMIN_MD5}', NOW());
INSERT IGNORE INTO selectbf_admin (name, value, inserttime) VALUES ('VERSION', '0.3', NOW());

INSERT IGNORE INTO selectbf_params (id, name, value, inserttime) VALUES
(1,'TEMPLATE','original',NOW()),
(2,'DEBUG-LEVEL','0',NOW()),
(3,'TITLE-PREFIX','BFV Stats',NOW()),
(4,'MIN-ROUNDS','0',NOW()),
(5,'STAR-NUMBER','20',NOW()),
(6,'RANK-ORDERBY','points',NOW()),
(7,'RANK-FORMULA','(0/0)*0',NOW()),
(8,'CLAN-TABLE-SETUP','1',NOW()),
(9,'CLAN-ACCESS-RIGHT','1',NOW()),
(10,'CLAN-PARSER-PATH','${BFV_LOG_DIR}',NOW()),
(11,'MIN-CLAN-MEMBERS','1',NOW()),
(12,'MIN-CLAN-ROUNDS','1',NOW()),
(13,'LIST-RANKING-PLAYER','50',NOW()),
(14,'LIST-RANKING-GAMES','15',NOW()),
(15,'LIST-CLAN-RANKING','25',NOW()),
(16,'LIST-CHARACTER-TYPE','15',NOW()),
(17,'LIST-CHARACTER-REPAIRS','15',NOW()),
(18,'LIST-CHARACTER-HEALS','15',NOW()),
(19,'LIST-MAP-ROUNDS','1',NOW()),
(20,'LIST-MAP-KILLERS','15',NOW()),
(21,'LIST-MAP-ATTACKS','15',NOW()),
(22,'LIST-MAP-DEATHS','15',NOW()),
(23,'LIST-MAP-TKS','15',NOW()),
(24,'LIST-WEAPONS-LIST','25',NOW()),
(25,'LIST-VEHICLES-LIST','25',NOW()),
(26,'LIST-PLAYER-NICKNAMES','10',NOW()),
(27,'LIST-PLAYER-CHARACTERS','10',NOW()),
(28,'LIST-PLAYER-WEAPONS','10',NOW()),
(29,'LIST-PLAYER-VICTIMS','10',NOW()),
(30,'LIST-PLAYER-ASSASINS','10',NOW()),
(31,'LIST-PLAYER-VEHICLES','10',NOW()),
(32,'LIST-PLAYER-MAPS','10',NOW()),
(33,'LIST-PLAYER-GAMES','10',NOW()),
(34,'LIST-CLAN-MEMBERS','50',NOW()),
(35,'RANK-ROUND','other',NOW()),
(36,'RANK-ROUND-NUMBER','2',NOW());
SQL

    chown -R www-data:www-data "$SELECTBF_DIR"
    success "selectbf installed and configured in $SELECTBF_DIR"
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

CREATE TABLE IF NOT EXISTS selectbf_ping_summary (
    player_id    INT UNSIGNED NOT NULL PRIMARY KEY,
    avg_ping     FLOAT NOT NULL DEFAULT 0,
    sample_count INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS selectbf_uptime_log (
    id     INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    ts     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    online TINYINT(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL
    success "DB schema and indexes applied."

    # systemd service
    curl -fsSL "${REPO_RAW}/systemd/bfvstats-api.service" \
        -o /etc/systemd/system/bfvstats-api.service
    systemctl daemon-reload
    systemctl enable --quiet bfvstats-api
    systemctl restart bfvstats-api
    success "bfvstats-api service started."

    # Uptime check script + cron job (every 30 minutes)
    curl -fsSL "${REPO_RAW}/web/check_uptime.py" -o "$INSTALL_DIR/check_uptime.py"
    chmod +x "$INSTALL_DIR/check_uptime.py"
    # Add cron job only if not already present
    if ! crontab -l 2>/dev/null | grep -q "check_uptime.py"; then
        (crontab -l 2>/dev/null; echo "*/30 * * * * ${INSTALL_DIR}/venv/bin/python3 ${INSTALL_DIR}/check_uptime.py") | crontab -
    fi
    success "Uptime check script installed (runs every 30 minutes)."
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
case "$UI_CHOICE" in
    1|3)
        echo -e "  ${BOLD}Modern admin panel:${NC}  click ${BOLD}Admin${NC} in the nav bar and enter your password."
        echo -e "  ${BOLD}Run parser:${NC}          Admin → Run Parser to import existing log files."
        ;;
esac
case "$UI_CHOICE" in
    2|3)
        echo -e "  ${BOLD}Classic admin panel:${NC} http://${HOST_IP}:8081/admin/ — use your admin password."
        echo -e "  ${BOLD}Run parser:${NC}          Admin → Clantag/Parser section to import logs."
        ;;
esac
echo ""
echo -e "  ${YELLOW}Tip:${NC} Save your DB password — it was written to /opt/bfvstats/.env"
if [[ "${DB_PASS}" == "${DB_PASS_DEFAULT:-}" ]]; then
    echo -e "  ${YELLOW}Auto-generated DB password:${NC} ${BOLD}${DB_PASS}${NC}"
fi
echo ""
