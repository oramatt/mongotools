#!/bin/bash

#
# Script purpose - Planning
#
# Author: Matt DeMarco (matthew.demarco@oracle.com)
#
# This script is intended for use during the Planning phase for compatibility analysis.
# It captures live server workload characteristics using the MongoDB `serverStatus()` command and enables 
# both snapshot and continuous streaming observations.
#
# This script can perform the following:
# 
# 1. Capture a one-time snapshot of `db.serverStatus()` output from a MongoDB instance using `mongosh`.
# 2. Stream serverStatus output at a configurable interval for live workload monitoring.
# 3. Save the output to a JSON file with optional timestamped filenames for historical traceability.
# 4. Highlight user-specified keywords (e.g. "find", "update", "split") in the terminal using ANSI color formatting.
# 5. (Planned) Optionally redact sensitive metadata fields such as `host`, `pid`, `localTime`, `connections`, 
#    `security`, and `transportSecurity` from the JSON output while preserving the schema.
#
# Example usage:
#   ./mongoServerStatus.sh --uri mongodb://localhost:27017 --highlight find aggregate
#   ./mongoServerStatus.sh --stream --interval 10 --highlight update delete
#   ./mongoServerStatus.sh --out server_snapshot.json --highlight split --stream

# Analyzing multiple system examples
# - Passing mongodb uri
# for i in mongodb://localhost:23456 mongodb://localhost:23456 mongodb://localhost:23456 mongodb://localhost:27017
# do
# bash mongoserverStatus.sh --uri $i
# done

# - Reading mongodb uri from file with newline for each source system
# more src
# mongodb://localhost:23456
# mongodb://localhost:23456
# mongodb://localhost:27017

# for i in $(cat src)
# do
# bash mongoserverStatus.sh --uri $i
# done


# Default values
MONGOSH_PATH="/opt/homebrew/bin/mongosh"
MONGODB_URI="mongodb://localhost:23456"
OUTPUT_FILE="mongodb_workload_assessment_log.json"
TIMESTAMP=$(date '+%Y_%m_%d_%H%M%S')
STREAM_MODE=false
INTERVAL=5
HIGHLIGHT_KEYWORDS=() #try to highlight keywords while streaming...

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --uri)
      MONGODB_URI="$2"
      shift; shift
      ;;
    --out)
      OUTPUT_FILE="$2"
      shift; shift
      ;;
    --stream)
      STREAM_MODE=true
      shift
      ;;
    --interval)
      INTERVAL="$2"
      shift; shift
      ;;
    --highlight)
      shift
      #collect all following arguments as keywords until next -- flag or end
      while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
        HIGHLIGHT_KEYWORDS+=("$1")
        shift
      done
      ;;
    --help)
      shift
      echo "Unknown option: $1"
      echo "Usage: $0 [--uri URI] [--out FILE] [--stream] [--interval SECONDS] [--highlight WORD1 WORD2 ...]"
      exit 1
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--uri URI] [--out FILE] [--stream] [--interval SECONDS] [--highlight WORD1 WORD2 ...]"
      exit 1
      ;;
  esac
done

# Use timestamped file name if streaming and output not manually set
if [[ "$STREAM_MODE" == true && "$OUTPUT_FILE" == "mongodb_workload_assessment_log.json" ]]; then
  OUTPUT_FILE="streamout_mongo_workload_assessment_$(date '+%Y_%m_%d_%H%M%S').json"
else
  OUTPUT_FILE="${TIMESTAMP}_${OUTPUT_FILE}"
fi

# Fetch assessment data from MongoDB
# Change query to experiment with the following options:
# 1. db.adminCommand({ getLog: "global" })
# 2. db.serverStatus()
# 3. db.serverStatus().metrics.operatorCounters

# --quiet suppress startup messages
# --eval runs the javascript command
# --EJSON.stringify makes it properly formated JSON

echo_command() {

  clear
  echo -e "${GREEN}--------------------------------------------${NC}"
  echo -e "${GREEN}db.serverStatus query is: ${NC}"
  echo -e "${GREEN}\"$MONGOSH_PATH\" \"$MONGODB_URI\" --quiet --eval 'EJSON.stringify(db.serverStatus(), null, 2)'${NC}" 
  echo -e "${GREEN}--------------------------------------------${NC}"

  read -p "Press Enter to continue..." noVar

}
fetch_data() {
  "$MONGOSH_PATH" "$MONGODB_URI" --quiet --eval 'EJSON.stringify(db.serverStatus(), null, 2)'
}

# redact_data(){
#   jq 'del(.host, .pid, .localTime, .connections, .security, .transportSecurity)' \\n  /tmp/assesslog.json > /tmp/redacted_assesslog.json
# }

# Highlight console output
highlight_log() {
  local line="$1"
  local highlighted="$line"

  for i in "${!HIGHLIGHT_KEYWORDS[@]}"; do
    keyword="${HIGHLIGHT_KEYWORDS[$i]}"
    case $i in
      0) color=$RED ;;
      1) color=$YELLOW ;;
      2) color=$CYAN ;;
      *) color=$NC ;;
    esac
    highlighted=$(echo "$highlighted" | sed -E "s/($keyword)/${color}\1${NC}/gI")
  done

  echo -e "$highlighted"
}

# Stream or run once
if [[ "$STREAM_MODE" == true ]]; then
  echo "Streaming workload from $MONGODB_URI every $INTERVAL seconds. Output file: $OUTPUT_FILE"
  echo "Highlighting keywords: ${HIGHLIGHT_KEYWORDS[*]}"
  while true; do
    TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
    LOG_JSON=$(fetch_data)

    echo -e "\n--- $TIMESTAMP ---" | tee -a "$OUTPUT_FILE"
    echo "$LOG_JSON" >> "$OUTPUT_FILE"

    echo "$LOG_JSON" | jq -r 'to_entries[] | "\(.key): \(.value)"' | while read -r line; do
      highlight_log "$line"
    done

    sleep "$INTERVAL"
  done
else
  echo_command
  LOG_JSON=$(fetch_data)
  echo "$LOG_JSON" > "$OUTPUT_FILE"
  echo "Saved log to $OUTPUT_FILE"
  echo "$LOG_JSON" | jq -r 'to_entries[] | "\(.key): \(.value)"' | while read -r line; do
    highlight_log "$line"
  done
fi
