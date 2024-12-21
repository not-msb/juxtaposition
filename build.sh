#!/bin/sh

set -xe

mkdir -p dist
zig build-exe src/main.zig -target wasm32-freestanding -fno-entry -femit-bin=dist/main.wasm -rdynamic
