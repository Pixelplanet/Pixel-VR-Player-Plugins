#!/bin/sh
# Builds the example plugin on Linux (on the headset, or any arm64 Linux with g++).
# Output: build/example/ (plugin.json + example), ready for ../tools/package-plugin.sh.
set -e
cd "$(dirname "$0")"
mkdir -p build/example
g++ -std=c++17 -O2 -Wall -o build/example/example main.cpp
cp plugin.json build/example/
echo "built build/example - package it with: sh ../tools/package-plugin.sh build/example ."
