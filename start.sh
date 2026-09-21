#!/usr/bin/env bash
# Starts all four Claims Policy Assistant integrations in the correct
# dependency order (claims_api -> claims_rag -> claims_mcp -> claims_agent),
# plus the chat_ui, each as a background `bal run` process, logging to
# logs/&lt;package&gt;.log.
#
# Usage:
#   ./start.sh
#
# Stop everything with ./stop.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PACKAGES=(claims_api claims_rag claims_mcp claims_agent chat_ui)
LOG_DIR="$SCRIPT_DIR/logs"
PID_DIR="$SCRIPT_DIR/.pids"

mkdir -p "$LOG_DIR" "$PID_DIR"

wait_for_port() {
    local port="$1"
    local label="$2"
    local attempts=60
    while ! (exec 3<>"/dev/tcp/localhost/$port") 2>/dev/null; do
        attempts=$((attempts - 1))
        if [ "$attempts" -le 0 ]; then
            echo "  WARNING: $label did not start listening on port $port in time. Check logs/$label.log"
            return 1
        fi
        sleep 1
    done
    exec 3<&- 2>/dev/null || true
    exec 3>&- 2>/dev/null || true
    echo "  $label is listening on port $port."
    return 0
}

echo "Starting Claims Policy Assistant integrations..."

for package in "${PACKAGES[@]}"; do
    echo ""
    echo "==> Starting $package"
    (cd "$package" && nohup bal run > "$LOG_DIR/$package.log" 2>&1 &
     echo $! > "$PID_DIR/$package.pid")
    sleep 1
done

echo ""
echo "Waiting for services to become ready..."
wait_for_port 8080 claims_api
wait_for_port 8081 claims_rag
wait_for_port 8090 claims_mcp
wait_for_port 8091 claims_agent
wait_for_port 8092 chat_ui

echo ""
echo "All integrations started. Logs are in $LOG_DIR/, PIDs in $PID_DIR/."
echo "  Claims API          -> http://localhost:8080"
echo "  Claims RAG          -> http://localhost:8081"
echo "  Claims MCP          -> http://localhost:8090/claims-mcp"
echo "  Claims Policy Agent -> http://localhost:8091/claims-policy-agent/secure-chat"
echo "  Chat UI             -> http://localhost:8092"
echo ""
echo "Tail all logs with: tail -f logs/*.log"
echo "Stop everything with: ./stop.sh"
