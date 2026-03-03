#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

exec "${CLAUDE_ROOT}/agents/start-memory-observer.sh" "$@"
