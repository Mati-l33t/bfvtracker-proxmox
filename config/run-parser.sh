#!/bin/bash
# Copyright (c) 2025-2026 -{GmV}- m@gic — https://github.com/Mati-l33t
LOG=/opt/bfvstats/logs/parser.log
LOCK=/tmp/bfvstats-parser.lock
BFV_SERVER_IP="10.0.0.70"
BFV_REMOTE_LOG="/opt/bfv/mods/bfvietnam/logs"
BFV_LOCAL_LOG="/opt/bfv/logs"

if [ -f "$LOCK" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Parser already running, skipping." >> "$LOG"
  exit 0
fi

touch "$LOCK"
trap "rm -f $LOCK" EXIT

# ─── BUILD EXCLUSION LIST (skip files already parsed) ────────────────────────
# Files renamed to *.xml.parsed after processing — exclude their originals
EXCL=$(mktemp)
for f in "${BFV_LOCAL_LOG}"/*.xml.parsed; do
  [ -f "$f" ] && basename "$f" .parsed >> "$EXCL"
done

# ─── SYNC LOGS FROM BFV SERVER ───────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Syncing logs from ${BFV_SERVER_IP}..." >> "$LOG"

rsync -az --timeout=10 \
  --exclude-from="$EXCL" \
  -e "ssh -i /root/.ssh/bfvstats_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5" \
  "root@${BFV_SERVER_IP}:${BFV_REMOTE_LOG}/" \
  "${BFV_LOCAL_LOG}/" >> "$LOG" 2>&1

rm -f "$EXCL"

RSYNC_STATUS=$?
if [ $RSYNC_STATUS -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log sync complete." >> "$LOG"
elif [ $RSYNC_STATUS -eq 255 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: SSH connection to BFV server failed — parsing existing local logs." >> "$LOG"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: rsync exited with status $RSYNC_STATUS — parsing existing local logs." >> "$LOG"
fi

# ─── RUN PARSER ──────────────────────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting selectbf parser..." >> "$LOG"

cd /opt/bfvstats/selectbf/bin
bash selectbf.sh >> "$LOG" 2>&1
STATUS=$?

if [ $STATUS -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Parse complete." >> "$LOG"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Parser exited with status $STATUS" >> "$LOG"
fi

# Rotate log if >2MB
if [ $(stat -c%s "$LOG" 2>/dev/null || echo 0) -gt 2097152 ]; then
  mv "$LOG" "$LOG.1"
  touch "$LOG"
fi
