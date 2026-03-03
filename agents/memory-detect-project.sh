#!/bin/bash
# Agent-side project detection wrapper.
# Keeps agent script decoupled from skill internals.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../hooks/memory-detect-project.sh"
