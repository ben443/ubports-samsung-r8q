#!/bin/bash
set -xe

export BSP_BUILD_FAMILY=sharkl5Pro
export BSP_BUILD_DT_OVERLAY=y
export BSP_BUILD_ANDROID_OS=y

[ -d build ] || git clone https://gitlab.com/ubports/community-ports/halium-generic-adaptation-build-tools build -b halium-11
./build/build.sh "$@"
