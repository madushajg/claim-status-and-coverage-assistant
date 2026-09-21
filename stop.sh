#!/usr/bin/env bash
# Stops all integrations started by start.sh, using the PIDs recorded
# under .pids/. Falls back to matching `bal run` processes by working
# directory if a PID file is missing or stale.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PACKAGES=(claims_api claims_rag claims_mcp claims_agent chat_ui)
PID_DIR="$SCRIPT_DIR/.pids"

echo "Stopping Claims Policy Assistant integrations..."

for package in "${PACKAGES[@]}"; do
    pid_file="$PID_DIR/$package.pid"
    if [ -f "$pid_file" ]; then
        pid="$(cat "$pid_file")"
        if kill -0 "$pid" 2>/dev/null; then
            echo "==> Stopping $package (pid $pid)"
            kill "$pid" 2>/dev/null
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        else
            echo "==> $package (pid $pid) was not running"
        fi
        rm -f "$pid_file"
    else
        echo "==> No PID file for $package, skipping"
    fi
done

echo ""
echo "Done. Any lingering bal/java processes can be found with: ps aux | grep bal"
