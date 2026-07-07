#!/bin/sh
set -eu

if ! command -v idf.py >/dev/null 2>&1; then
    if [ -f "${HOME}/esp-idf/export.sh" ]; then
        . "${HOME}/esp-idf/export.sh"
    fi
fi

if ! command -v idf.py >/dev/null 2>&1; then
    echo "idf.py not found. Source your ESP-IDF export.sh first." >&2
    exit 1
fi

exec idf.py build "$@"
