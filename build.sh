#!/bin/bash
set -euo pipefail

cd -- "$(dirname -- "$(realpath -- "$0")")"

if [ ! -d build ]; then
    git clone --depth 1 --branch halium-11 \
        https://github.com/ben443/halium-generic-adaptation-build-tools.git build
fi

if [ ! -x build/build.sh ]; then
    echo "Missing executable build/build.sh; check the adaptation build-tools checkout." >&2
    exit 1
fi

if [ "${1:-}" = "--fetch-tools-only" ]; then
    exit 0
fi

exec bash ./scripts/build-port.sh "$@"
