#!/usr/bin/env bash
set -euo pipefail

URL="https://rm-files.rivermeadow.com/rivermeadow-packages/95a8536f-38cd-48a6-9a2e-a872cc5bf49d/appliances/rms-ma-vsphere-0.128.8120.zip"
PERIOD=3600
INTERVAL=30
SAMPLES=4
WINDOW=120

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="${SCRIPT_DIR}/curl_speedtest.log"

bytes_to_human() {
  local bytes=$1
  awk -v b="$bytes" 'BEGIN{
    split("B kB MB GB TB",u)
    for(i=1;b>=1024 && i<5;i++) b/=1024
    printf "%.2f %s/s", b, u[i]
  }'
}

trap 'echo -e "\nInterrupted — exiting." | tee -a "$LOGFILE"; exit 0' INT TERM

while :; do
  echo -e "\n==== $(date '+%F %T') | Starting 2-minute test ====" | tee -a "$LOGFILE"
  TMPFILE=$(mktemp)
  speed_vals=()

  timeout "$WINDOW" curl -L -o "$TMPFILE" "$URL" --progress-meter | tee -a "$LOGFILE" &
  CURL_PID=$!
  sleep 2

  last_size=0
  last_ts=$(date +%s)

  for ((i=1;i<=SAMPLES;i++)); do
    sleep "$INTERVAL"

    now_size=$(stat -c%s "$TMPFILE" 2>/dev/null || echo 0)
    now_ts=$(date +%s)
    delta_b=$(( now_size - last_size ))
    delta_t=$(( now_ts - last_ts ))
    (( delta_t == 0 )) && delta_t=1

    cur_bps=$(( delta_b / delta_t ))
    speed_vals+=( "$cur_bps" )

    echo "[$(date '+%T')] sample $i: $(bytes_to_human "$cur_bps")" | tee -a "$LOGFILE"

    last_size=$now_size
    last_ts=$now_ts
  done

  wait "$CURL_PID" 2>/dev/null || true

  total_bytes=$(stat -c%s "$TMPFILE" 2>/dev/null || echo 0)
  avg_bps=$(( total_bytes / WINDOW ))

  {
    echo "--------------------------------------------"
    for ((i=0;i<${#speed_vals[@]};i++)); do
      echo "  Sample $((i+1)): $(bytes_to_human "${speed_vals[$i]}")"
    done
    echo "  Avg (2 min): $(bytes_to_human "$avg_bps")"
    echo "--------------------------------------------"
    echo "Next run in $((PERIOD/60)) minutes..."
  } | tee -a "$LOGFILE"

  rm -f "$TMPFILE"
  sleep "$PERIOD"
done

