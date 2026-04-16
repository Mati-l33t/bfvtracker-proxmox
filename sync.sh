#!/bin/bash
# Syncs live files to repo, strips hardcoded content, commits and pushes.
# Usage: ./sync.sh "commit message"

set -e
REPO=/opt/bfvtracker-repo
MSG="${1:-Update}"

# ── Copy live files ──────────────────────────────────────────────────────────
cp /var/www/bfvstats/index.html  "$REPO/web/index.html"
cp /opt/bfvstats/api.py          "$REPO/web/api.py"
cp /opt/bfvstats/check_uptime.py "$REPO/web/check_uptime.py"

# ── Strip hardcoded site-specific content ────────────────────────────────────
python3 - << 'PYEOF'
import re

# ── index.html ──
f = '/opt/bfvtracker-repo/web/index.html'
c = open(f).read()

# Restore installer placeholders (install.sh patches these on fresh install)
c = re.sub(r'<title>[^<]*</title>', '<title>__SITE_TITLE__</title>', c)
c = re.sub(r'<span class="logo-gmv">[^<]+</span>', '<span class="logo-gmv">__SITE_TITLE__</span>', c)
c = re.sub(
    r'<span class="pill-name">[^<]*</span>',
    '<span class="pill-name">__SERVER_NAME__</span>',
    c
)
# Forum link: restore placeholder (install.sh sets full <a> tag or empty string)
c = re.sub(
    r'<a href="[^"]*" target="_blank" rel="noopener">Forum</a>',
    '__FORUM_LINK__',
    c
)
# Logo image: restore placeholder
c = re.sub(
    r'<img src="/[^"]*" alt="logo"([^>]*)>',
    r'<img src="/__LOGO_FILE__" alt="logo"\1>',
    c
)

# Strip site-specific CSS comment header
c = re.sub(r'/\* [=═]+\s+GmV BFV Stats.*?[=═]+ \*/', '/* BFV Stats */', c, flags=re.DOTALL)

# Remove site-specific favicon (each install uses their own)
c = c.replace('\n<link rel="icon" type="image/png" href="/favicon.png">', '')

# Reset player profile static defaults to generic values
c = re.sub(r'(<div class="pp-name" id="pp-name">)[^<]*(</div>)', r'\g<1>—\2', c)
c = re.sub(r'(<div class="pp-sub" id="pp-sub">)[^<]*(</div>)', r'\g<1>\2', c)
for pid in ['pp-dname','pp-dseen','pp-drounds','pp-dscore','pp-dkills',
            'pp-ddeaths','pp-dkd','pp-dsr']:
    c = re.sub(r'(id="' + pid + r'"[^>]*>)[^<]*(</div>)', r'\g<1>—\2', c)
c = re.sub(r'(id="pp-dtks"[^>]*>)[^<]*(</div>)', r'\g<1>—\2', c)

# Admin clan tag input — generic placeholder
c = re.sub(r'placeholder="e\.g\. [^"]*"(\s+autocomplete="new-password"[^>]*id="clan-tag-input"|[^>]*id="clan-tag-input"[^>]*)',
           r'placeholder="e.g. [TAG]"\1', c)
c = re.sub(r'(id="clan-tag-input"[^>]*)placeholder="e\.g\. [^"]*"', r'\1placeholder="e.g. [TAG]"', c)

open(f, 'w').write(c)

# ── api.py ──
f = '/opt/bfvtracker-repo/web/api.py'
c = open(f).read()
c = re.sub(r'cfg\.get\("BFV_HOST",\s*"[^"]+"\)', 'cfg.get("BFV_HOST", "127.0.0.1")', c)
open(f, 'w').write(c)

# ── check_uptime.py ──
f = '/opt/bfvtracker-repo/web/check_uptime.py'
c = open(f).read()
c = re.sub(r'cfg\.get\("BFV_HOST",\s*"[^"]+"\)', 'cfg.get("BFV_HOST", "127.0.0.1")', c)
open(f, 'w').write(c)

# ── config/run-parser.sh ──
f = '/opt/bfvtracker-repo/config/run-parser.sh'
c = open(f).read()
c = re.sub(r'BFV_SERVER_IP="[^"]+"', 'BFV_SERVER_IP="YOUR_BFV_SERVER_IP"', c)
open(f, 'w').write(c)
PYEOF

# ── Commit and push ──────────────────────────────────────────────────────────
cd "$REPO"
git add -A
if git diff --cached --quiet; then
    echo "Nothing to commit."
else
    git commit -m "$MSG"
    git push
    echo "Pushed: $MSG"
fi
