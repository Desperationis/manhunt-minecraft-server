#!/usr/bin/env bash
# Run Minecraft server with optimal settings for this machine
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/minecraft"
JAR="paper-1.21.11-92.jar"

# Change to the server directory
cd "$SERVER_DIR"

# Check JAR exists
if [ ! -f "$JAR" ]; then
    echo "Error: $JAR not found in $SERVER_DIR"
    exit 1
fi

# Check eula.txt
if [ ! -f "eula.txt" ] || ! grep -q "eula=true" eula.txt; then
    echo "Error: EULA not accepted. Run: echo 'eula=true' > $SERVER_DIR/eula.txt"
    exit 1
fi

# Get total system memory in MB
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))

# Use 80% of total RAM for the server, leave some for OS
SERVER_MEM_MB=$((TOTAL_MEM_MB * 80 / 100))

# Cap minimum at 2GB if available
if [ "$SERVER_MEM_MB" -lt 2048 ] && [ "$TOTAL_MEM_MB" -ge 2048 ]; then
    SERVER_MEM_MB=2048
fi

echo "System RAM: ${TOTAL_MEM_MB}MB"
echo "Server RAM: ${SERVER_MEM_MB}MB"
echo ""

# Aikar's optimized JVM flags for Minecraft servers
# https://docs.papermc.io/paper/aikars-flags
exec java \
    -Xms${SERVER_MEM_MB}M \
    -Xmx${SERVER_MEM_MB}M \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    -jar "$JAR" --nogui
