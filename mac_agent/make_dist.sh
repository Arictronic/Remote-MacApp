#!/bin/bash
set -e

cd "$(dirname "$0")"

if [ ! -x "./RemoteMacAgent" ]; then
  chmod +x ./build.sh
  ./build.sh
fi

DIST="../dist_mac"
rm -rf "$DIST"
mkdir -p "$DIST"

cp ./RemoteMacAgent "$DIST/"
cp ./config.json "$DIST/"
cp ./start_agent.command "$DIST/"

chmod +x "$DIST/RemoteMacAgent"
chmod +x "$DIST/start_agent.command"

cat > "$DIST/README_START.txt" <<'EOF'
Remote Mac Agent

1. Edit config.json:
   server = ws://WINDOWS_SERVER_IP:8000/ws/mac
   token  = the same token as server/.env
   receive_dir = Desktop by default

2. Open System Preferences -> Security & Privacy -> Privacy -> Accessibility.
   Add Terminal or RemoteMacAgent.

3. Run start_agent.command by double click.
   If macOS blocks it, right click -> Open.

Viewer URL:
- http://SERVER_IP:8000/viewer/?token=TOKEN

File transfer:
- Drag a file into the browser viewer or use Send file.
- Received files appear in the configured receive_dir, Desktop by default.

For Terminal run:
./RemoteMacAgent --config config.json
EOF

echo "Created: $DIST"
