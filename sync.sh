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
c = re.sub(r'<title>BFV Stats[^<]*</title>', '<title>BFV Stats</title>', c)
c = c.replace('\n<link rel="icon" type="image/png" href="/favicon.png">', '')
c = re.sub(
    r'<div class="logo-text"><span class="logo-gmv">[^<]+</span>',
    '<div class="logo-text"><span class="logo-gmv">BFV</span>',
    c
)
# Strip hardcoded server name and IP from header pill
c = re.sub(
    r'<span class="pill-name">[^<]*</span><span class="pill-addr">[^<]*<span id="header-addr">[^<]*</span>',
    '<span class="pill-name">BFV Server</span><span class="pill-addr">&nbsp;·&nbsp; <span id="header-addr">—</span>',
    c
)
# Strip site-specific forum link
c = re.sub(
    r'<a href="https://[^"]+" target="_blank" rel="noopener">Forum</a>',
    '<a href="#" target="_blank" rel="noopener">Forum</a>',
    c
)
# Strip site-specific logo image
c = re.sub(
    r'<img src="/[^"]*logo[^"]*" alt="logo"[^>]*>',
    '<img src="/logo.png" alt="logo" style="width:32px;height:32px;object-fit:contain">',
    c
)
open(f, 'w').write(c)

# ── api.py ──
f = '/opt/bfvtracker-repo/web/api.py'
c = open(f).read()
# Replace hardcoded fallback IP with placeholder
c = re.sub(r'cfg\.get\("BFV_HOST",\s*"[^"]+"\)', 'cfg.get("BFV_HOST", "127.0.0.1")', c)
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
