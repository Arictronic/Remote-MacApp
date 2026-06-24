#!/bin/bash
cd "$(dirname "$0")"

echo "Remote Mac Agent"
echo ""

if [ ! -f "./config.json" ]; then
  echo "config.json not found"
  echo "Press Enter to close"
  read _
  exit 1
fi

if [ ! -x "./RemoteMacAgent" ]; then
  echo "RemoteMacAgent not found or not executable."
  echo "Trying to build it..."
  echo ""

  if [ -f "./build.sh" ]; then
    chmod +x ./build.sh
    ./build.sh
  else
    echo "build.sh not found. Put RemoteMacAgent into this folder or build it first."
    echo "Press Enter to close"
    read _
    exit 1
  fi
fi

echo ""
echo "Starting agent..."
echo "The agent will keep retrying until the server is available."
echo "Stop: Ctrl+C"
echo ""

./RemoteMacAgent --config config.json 2>&1 | awk '
  /Share this URL to connect:/ { next }
  { print; fflush() }
'

echo ""
echo "Agent stopped. Press Enter to close."
read _
