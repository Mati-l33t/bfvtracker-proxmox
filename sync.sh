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
f = '/opt/bfvtracker-repo/web/index.html'
c = open(f).read()
c = re.sub(r'<title>BFV Stats[^<]*</title>', '<title>BFV Stats</title>', c)
c = c.replace('\n<link rel="icon" type="image/png" href="/favicon.png">', '')
c = re.sub(
    r'<div class="logo-text"><span class="logo-gmv">[^<]+</span>',
    '<div class="logo-text"><span class="logo-gmv">BFV</span>',
    c
)
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
