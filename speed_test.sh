#!/usr/bin/env bash
# Set shell options for stricter error handling:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status, or zero if no command failed.
set -euo pipefail

# Define the URL of the file to download for the speed test.
URL="https://rm-files.rivermeadow.com/rivermeadow-packages/95a8536f-38cd-48a6-9a2e-a872cc5bf49d/appliances/rms-ma-vsphere-0.128.8120.zip"

# PERIOD: The wait time between full test runs (in seconds). Here, 3600 seconds = 1 hour.
PERIOD=3600
# INTERVAL: The time between speed samples during the test window (in seconds). Here, 30 seconds.
INTERVAL=30
# SAMPLES: The number of speed samples to take during the test window. Here, 4 samples.
SAMPLES=4
# WINDOW: The total duration of the download test window (in seconds). Here, 120 seconds = 2 minutes.
WINDOW=120

# Determine the directory where this script is located, making it absolute for reliability.
# This is useful if the script is called from a different working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the path for the log file, placed in the script's directory.
# All output from tests will be appended to this file for historical tracking.
LOGFILE="${SCRIPT_DIR}/curl_speedtest.log"

# Function to convert bytes per second (bps) to a human-readable format (e.g., MB/s).
# Input: bytes (an integer representing bytes per second).
# Uses awk for the conversion logic, handling units from B to TB.
bytes_to_human() {
  local bytes=$1
  awk -v b="$bytes" 'BEGIN{
    split("B kB MB GB TB",u)
    for(i=1;b>=1024 && i<5;i++) b/=1024
    printf "%.2f %s/s", b, u[i]
  }'
}

# Set up a trap for interrupt signals (INT: Ctrl+C, TERM: termination signal).
# When triggered, it logs a friendly exit message and exits cleanly with status 0.
# The 'tee -a' ensures the message is both printed to stdout and appended to the log.
trap 'echo -e "\nInterrupted — exiting." | tee -a "$LOGFILE"; exit 0' INT TERM

# Infinite loop to run the speed test repeatedly.
# Each iteration performs one full test and then sleeps for the PERIOD.
while :; do
  # Print a header for the current test run, including timestamp and description.
  # Uses 'tee -a' to output to both console and log file.
  echo -e "\n==== $(date '+%F %T') | Starting 2-minute test ====" | tee -a "$LOGFILE"
  
  # Create a temporary file to store the partial download.
  # mktemp ensures a unique, secure temporary file name.
  TMPFILE=$(mktemp)
  
  # Initialize an array to store the speed values (in bytes per second) for each sample.
  speed_vals=()
  
  # Start the curl download in the background:
  # - timeout "$WINDOW": Kills curl after the WINDOW duration to limit the test.
  # - curl -L -o "$TMPFILE" "$URL": Follow redirects (-L), save output to TMPFILE.
  # - --progress-meter: Outputs progress info (though we capture it for logging).
  # | tee -a "$LOGFILE": Logs the curl progress output.
  # & : Runs in background, capturing the PID for later waiting.
  timeout "$WINDOW" curl -L -o "$TMPFILE" "$URL" --progress-meter | tee -a "$LOGFILE" &
  CURL_PID=$!
  
  # Brief sleep to allow curl to start and begin downloading before sampling.
  sleep 2
  
  # Initialize variables for delta calculations:
  # last_size: Tracks the file size at the previous sample (starts at 0).
  # last_ts: Timestamp of the previous sample (in seconds since epoch).
  last_size=0
  last_ts=$(date +%s)
  
  # Loop to take SAMPLES number of speed measurements.
  for ((i=1;i<=SAMPLES;i++)); do
    # Wait for the INTERVAL between samples.
    sleep "$INTERVAL"
    
    # Get the current size of the temporary file.
    # stat -c%s: Prints the size in bytes; 2>/dev/null suppresses errors if file doesn't exist yet.
    # Fallback to 0 if stat fails (e.g., very early in download).
    now_size=$(stat -c%s "$TMPFILE" 2>/dev/null || echo 0)
    
    # Get the current timestamp in seconds.
    now_ts=$(date +%s)
    
    # Calculate the delta bytes downloaded since last sample.
    delta_b=$(( now_size - last_size ))
    
    # Calculate the delta time since last sample (in seconds).
    # Ensure delta_t is at least 1 to avoid division by zero.
    delta_t=$(( now_ts - last_ts ))
    (( delta_t == 0 )) && delta_t=1
    
    # Compute current speed in bytes per second for this interval.
    cur_bps=$(( delta_b / delta_t ))
    
    # Store this speed value in the array.
    speed_vals+=( "$cur_bps" )
    
    # Log the sample with timestamp and human-readable speed.
    echo "[$(date '+%T')] sample $i: $(bytes_to_human "$cur_bps")" | tee -a "$LOGFILE"
    
    # Update last values for the next iteration.
    last_size=$now_size
    last_ts=$now_ts
  done
  
  # Wait for the curl process to finish (or timeout).
  # 2>/dev/null || true: Suppresses wait errors if already done, ensures no exit on error.
  wait "$CURL_PID" 2>/dev/null || true
  
  # Get the final total bytes downloaded (after window or timeout).
  # Fallback to 0 if stat fails.
  total_bytes=$(stat -c%s "$TMPFILE" 2>/dev/null || echo 0)
  
  # Calculate average speed over the entire WINDOW (total bytes / window seconds).
  avg_bps=$(( total_bytes / WINDOW ))
  
  # Print a summary section:
  # - Separator line.
  # - List each sample's speed.
  # - Average over the 2-minute window.
  # - Teaser for next run.
  # All output via tee to log and console.
  {
    echo "--------------------------------------------"
    for ((i=0;i<${#speed_vals[@]};i++)); do
      echo " Sample $((i+1)): $(bytes_to_human "${speed_vals[$i]}")"
    done
    echo " Avg (2 min): $(bytes_to_human "$avg_bps")"
    echo "--------------------------------------------"
    echo "Next run in $((PERIOD/60)) minutes..."
  } | tee -a "$LOGFILE"
  
  # Clean up the temporary file.
  rm -f "$TMPFILE"
  
  # Sleep for the PERIOD before the next full test run.
  # This keeps the script running indefinitely, testing hourly.
  sleep "$PERIOD"
done
