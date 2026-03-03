#!/bin/bash
# validate.sh — Validate naming document format and naming conventions.
# Usage: bash validate.sh naming_output.md

set -euo pipefail

FILE="${1:-naming_output.md}"

if [ ! -f "$FILE" ]; then
    echo "ERROR: file not found: $FILE"
    exit 1
fi

echo "=== Naming Document Validation ==="
echo "File: $FILE"
echo ""

ERRORS=0
WARNINGS=0

# 1) Check template sections
echo "--- 1) Template Sections ---"
SECTIONS=(
  "Physical Quantities"
  "Control Variables"
  "State Variables"
  "Parameters and Constants"
  "Intermediate Variables"
  "Struct Definitions"
  "Enum Definitions"
)
for section in "${SECTIONS[@]}"; do
    if grep -q "## [0-9]*\. $section" "$FILE" 2>/dev/null; then
        echo "  OK: $section"
    else
        echo "  ERROR: missing section: $section"
        ((ERRORS++))
    fi
done
echo ""

# 2) Heuristic check for variable prefixes
echo "--- 2) Prefix checks (G_/S_/ST_/EM_) ---"
grep -oP '(?<=\| )[A-Za-z_][A-Za-z0-9_]*(?= \| float)' "$FILE" 2>/dev/null | while read -r name; do
    if [[ "$name" == G_* ]] || [[ "$name" == [a-z]* ]] || [[ "$name" == [A-Z][A-Z_]* ]]; then
        :
    else
        echo "  WARN: possible missing prefix: $name"
        ((WARNINGS++))
    fi
done
echo "  Done"
echo ""

# 3) Struct naming
echo "--- 3) Struct naming (ST_) ---"
grep -oP 'ST_[A-Za-z0-9_]+' "$FILE" 2>/dev/null | sort -u | while read -r name; do
    echo "  OK: $name"
done
grep -P 'Struct Type' "$FILE" -A 100 2>/dev/null | grep -oP '(?<=\| )[A-Z][A-Za-z0-9_]+(?= \|)' | grep -v '^ST_' | grep -v '^#' | while read -r name; do
    echo "  ERROR: struct type without ST_ prefix: $name"
    ((ERRORS++))
done
echo ""

# 4) Enum naming
echo "--- 4) Enum naming (EM_) ---"
grep -oP 'EM_[A-Za-z0-9_]+' "$FILE" 2>/dev/null | sort -u | while read -r name; do
    echo "  OK: $name"
done
echo ""

# 5) Constant naming
echo "--- 5) Constant naming (UPPER_SNAKE) ---"
grep -P 'const float|const int|const uint' "$FILE" 2>/dev/null | grep -oP '(?<=\| )[A-Za-z_][A-Za-z0-9_]*(?= \|)' | while read -r name; do
    if [[ "$name" =~ ^[A-Z][A-Z0-9_]*$ ]] || [[ "$name" == G_* ]] || [[ "$name" == S_* ]]; then
        echo "  OK: $name"
    else
        echo "  WARN: constant should be uppercase: $name"
        ((WARNINGS++))
    fi
done
echo ""

# 6) One-letter variable names
echo "--- 6) One-letter variable check ---"
grep -oP '(?<=\| )[a-zA-Z](?= \|)' "$FILE" 2>/dev/null | while read -r name; do
    if [[ "$name" =~ ^[ijk]$ ]]; then
        echo "  OK: loop variable $name"
    else
        echo "  ERROR: disallowed one-letter variable: $name"
        ((ERRORS++))
    fi
done
echo "  Done"
echo ""

echo "=== Validation Complete ==="
echo "Errors: $ERRORS | Warnings: $WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
    exit 1
else
    exit 0
fi
