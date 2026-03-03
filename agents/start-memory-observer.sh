#!/bin/bash
# Continuous Learning v2.1 - Memory Observer Agent Launcher

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# This sets: PROJECT_ID, PROJECT_NAME, PROJECT_ROOT, PROJECT_DIR, PYTHON_CMD
source "${SCRIPT_DIR}/memory-detect-project.sh"

CONFIG_FILE="${CLAUDE_ROOT}/skills/continuous-learning-v2/config.json"
PID_FILE="${PROJECT_DIR}/.observer.pid"
LOG_FILE="${PROJECT_DIR}/observer.log"
OBSERVATIONS_FILE="${PROJECT_DIR}/observations.jsonl"
INSTINCTS_DIR="${PROJECT_DIR}/instincts/personal"

OBSERVER_INTERVAL_MINUTES=5
MIN_OBSERVATIONS=20
OBSERVER_ENABLED=false
if [ -f "$CONFIG_FILE" ]; then
  _config=$(CLV2_CONFIG="$CONFIG_FILE" $PYTHON_CMD -c "
import json, os
with open(os.environ['CLV2_CONFIG']) as f:
    cfg = json.load(f)
obs = cfg.get('observer', {})
print(obs.get('run_interval_minutes', 5))
print(obs.get('min_observations_to_analyze', 20))
print(str(obs.get('enabled', False)).lower())
" 2>/dev/null || echo "5
20
false")
  _interval=$(echo "$_config" | sed -n '1p')
  _min_obs=$(echo "$_config" | sed -n '2p')
  _enabled=$(echo "$_config" | sed -n '3p')
  if [ "$_interval" -gt 0 ] 2>/dev/null; then
    OBSERVER_INTERVAL_MINUTES="$_interval"
  fi
  if [ "$_min_obs" -gt 0 ] 2>/dev/null; then
    MIN_OBSERVATIONS="$_min_obs"
  fi
  if [ "$_enabled" = "true" ]; then
    OBSERVER_ENABLED=true
  fi
fi
OBSERVER_INTERVAL_SECONDS=$((OBSERVER_INTERVAL_MINUTES * 60))

echo "Project: ${PROJECT_NAME} (${PROJECT_ID})"
echo "Storage: ${PROJECT_DIR}"

case "${1:-start}" in
  stop)
    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping observer for ${PROJECT_NAME} (PID: $pid)..."
        kill "$pid"
        rm -f "$PID_FILE"
        echo "Observer stopped."
      else
        echo "Observer not running (stale PID file)."
        rm -f "$PID_FILE"
      fi
    else
      echo "Observer not running."
    fi
    exit 0
    ;;

  status)
    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Observer is running (PID: $pid)"
        echo "Log: $LOG_FILE"
        echo "Observations: $(wc -l < "$OBSERVATIONS_FILE" 2>/dev/null || echo 0) lines"
        instinct_count=$(find "$INSTINCTS_DIR" -name "*.yaml" 2>/dev/null | wc -l)
        echo "Instincts: $instinct_count"
        exit 0
      else
        echo "Observer not running (stale PID file)"
        rm -f "$PID_FILE"
        exit 1
      fi
    else
      echo "Observer not running"
      exit 1
    fi
    ;;

  start)
    if [ "$OBSERVER_ENABLED" != "true" ]; then
      echo "Observer is disabled in config.json (observer.enabled: false)."
      echo "Set observer.enabled to true in config.json to enable."
      exit 1
    fi

    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Observer already running for ${PROJECT_NAME} (PID: $pid)"
        exit 0
      fi
      rm -f "$PID_FILE"
    fi

    echo "Starting memory observer for ${PROJECT_NAME}..."

    (
      trap 'rm -f "$PID_FILE"; exit 0' TERM INT

      analyze_observations() {
        if [ ! -f "$OBSERVATIONS_FILE" ]; then
          return
        fi
        obs_count=$(wc -l < "$OBSERVATIONS_FILE" 2>/dev/null || echo 0)
        if [ "$obs_count" -lt "$MIN_OBSERVATIONS" ]; then
          return
        fi

        echo "[$(date)] Analyzing $obs_count observations for project ${PROJECT_NAME}..." >> "$LOG_FILE"

        if command -v claude &> /dev/null; then
          exit_code=0
          claude --model haiku --print \
            "Read $OBSERVATIONS_FILE and identify patterns for the project '${PROJECT_NAME}'.
If you find 3+ occurrences of the same pattern, create an instinct file in $INSTINCTS_DIR/ following this format:

---
id: <kebab-case-id>
trigger: \"<when this happens>\"
confidence: <0.3-0.9>
domain: <code-style|testing|git|debugging|workflow|etc>
source: session-observation
scope: project
project_id: ${PROJECT_ID}
project_name: ${PROJECT_NAME}
---

# <Title>

## Action
<What to do>

## Evidence
<What observations led to this>

Be conservative - only create instincts for clear patterns.
If a pattern seems universal (not project-specific), set scope to 'global' instead of 'project'." \
            >> "$LOG_FILE" 2>&1 || exit_code=$?
          if [ "$exit_code" -ne 0 ]; then
            echo "[$(date)] Claude analysis failed (exit $exit_code)" >> "$LOG_FILE"
          fi
        else
          echo "[$(date)] claude CLI not found, skipping analysis" >> "$LOG_FILE"
        fi

        if [ -f "$OBSERVATIONS_FILE" ]; then
          archive_dir="${PROJECT_DIR}/observations.archive"
          mkdir -p "$archive_dir"
          mv "$OBSERVATIONS_FILE" "$archive_dir/processed-$(date +%Y%m%d-%H%M%S)-$$.jsonl" 2>/dev/null || true
        fi
      }

      trap 'analyze_observations' USR1

      echo "$$" > "$PID_FILE"
      echo "[$(date)] Observer started for ${PROJECT_NAME} (PID: $$)" >> "$LOG_FILE"

      while true; do
        sleep "$OBSERVER_INTERVAL_SECONDS"
        analyze_observations
      done
    ) &

    disown
    sleep 1

    if [ -f "$PID_FILE" ]; then
      echo "Observer started (PID: $(cat "$PID_FILE"))"
      echo "Log: $LOG_FILE"
    else
      echo "Failed to start observer"
      exit 1
    fi
    ;;

  *)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac
