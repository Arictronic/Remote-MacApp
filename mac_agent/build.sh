#!/bin/bash
set -e

export MACOSX_DEPLOYMENT_TARGET=10.12

xcrun swiftc -O -target x86_64-apple-macosx10.12 main.swift -o RemoteMacAgent -framework Cocoa -framework CoreGraphics

chmod +x RemoteMacAgent

echo "Built: ./RemoteMacAgent"
echo "Run:"
echo "./RemoteMacAgent --config config.json"
