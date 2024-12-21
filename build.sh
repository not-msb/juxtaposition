#!/bin/sh

set -xe

zig build-exe src/main.zig -target wasm32-freestanding -fno-entry -femit-bin=dist/main.wasm -rdynamic
