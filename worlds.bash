#!/usr/bin/env bash
# Advanced Minecraft World Manager
# Usage:
#   bash worlds.bash gen N    - Generate N new worlds
#   bash worlds.bash use N    - Switch to world N (deletes current world)
#   bash worlds.bash list     - List all available worlds

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/minecraft"
WORLDS_DIR="$SCRIPT_DIR/worlds"
JAR="paper-1.21.11-92.jar"
WORLD_FOLDERS=("world" "world_nether" "world_the_end")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Ensure worlds directory exists
ensure_worlds_dir() {
    mkdir -p "$WORLDS_DIR"
}

# Get the next available world number
get_next_world_number() {
    local max_num=0
    if [ -d "$WORLDS_DIR" ]; then
        for dir in "$WORLDS_DIR"/num*; do
            if [ -d "$dir" ]; then
                local num
                num=$(basename "$dir" | sed 's/num\([0-9]*\)_.*/\1/')
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt "$max_num" ]; then
                    max_num=$num
                fi
            fi
        done
    fi
    echo $((max_num + 1))
}

# Delete current world folders from minecraft directory
delete_current_world() {
    print_info "Deleting current world folders..."
    for folder in "${WORLD_FOLDERS[@]}"; do
        if [ -d "$SERVER_DIR/$folder" ]; then
            rm -rf "$SERVER_DIR/$folder"
            print_info "  Deleted $folder"
        fi
    done
}

# Check if world exists (all three folders)
world_exists() {
    [ -d "$SERVER_DIR/world" ] && \
    [ -d "$SERVER_DIR/world/region" ] && \
    [ "$(ls -A "$SERVER_DIR/world/region" 2>/dev/null)" ]
}

# Get JVM memory settings (from run_world.bash)
get_memory_settings() {
    local total_mem_kb total_mem_mb server_mem_mb
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_mem_mb=$((total_mem_kb / 1024))
    server_mem_mb=$((total_mem_mb * 80 / 100))
    if [ "$server_mem_mb" -lt 2048 ] && [ "$total_mem_mb" -ge 2048 ]; then
        server_mem_mb=2048
    fi
    echo "$server_mem_mb"
}

# Run server and wait for world generation
run_server_for_world_gen() {
    local server_pid
    local mem_mb
    mem_mb=$(get_memory_settings)

    print_info "Starting server with ${mem_mb}MB RAM..."

    cd "$SERVER_DIR"

    # Start server in background, redirect output to a temp file for monitoring
    local log_file="/tmp/mc_world_gen_$$.log"

    java \
        -Xms${mem_mb}M \
        -Xmx${mem_mb}M \
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
        -jar "$JAR" --nogui > "$log_file" 2>&1 &

    server_pid=$!
    print_info "Server started with PID: $server_pid"

    # Wait for server to be ready (look for "Done" message)
    print_info "Waiting for world generation..."
    local timeout=300  # 5 minute timeout
    local elapsed=0
    local done_found=false

    while [ $elapsed -lt $timeout ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            print_error "Server crashed unexpectedly!"
            cat "$log_file"
            rm -f "$log_file"
            return 1
        fi

        if grep -q "Done" "$log_file" 2>/dev/null; then
            done_found=true
            print_success "World generation complete!"
            break
        fi

        sleep 2
        elapsed=$((elapsed + 2))

        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ]; then
            print_info "  Still generating... (${elapsed}s elapsed)"
        fi
    done

    if [ "$done_found" = false ]; then
        print_error "Timeout waiting for world generation!"
        kill "$server_pid" 2>/dev/null || true
        rm -f "$log_file"
        return 1
    fi

    # Give the server a moment to finish any pending saves
    sleep 3

    # Send stop command to the server via RCON or just kill it gracefully
    print_info "Stopping server gracefully..."

    # Try to stop gracefully by sending SIGTERM
    kill "$server_pid" 2>/dev/null || true

    # Wait for server to stop (max 30 seconds)
    local stop_timeout=30
    local stop_elapsed=0
    while kill -0 "$server_pid" 2>/dev/null && [ $stop_elapsed -lt $stop_timeout ]; do
        sleep 1
        stop_elapsed=$((stop_elapsed + 1))
    done

    # Force kill if still running
    if kill -0 "$server_pid" 2>/dev/null; then
        print_warning "Server didn't stop gracefully, force killing..."
        kill -9 "$server_pid" 2>/dev/null || true
        sleep 2
    fi

    print_success "Server stopped."
    rm -f "$log_file"

    cd "$SCRIPT_DIR"
    return 0
}

# Generate a single world and save it
generate_single_world() {
    local world_num=$1
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local folder_name="num${world_num}_${timestamp}"

    print_step "Generating world $world_num..."

    # Delete any existing world
    delete_current_world

    # Run server to generate world
    if ! run_server_for_world_gen; then
        print_error "Failed to generate world!"
        return 1
    fi

    # Verify world was created
    if ! world_exists; then
        print_error "World folders not found after generation!"
        return 1
    fi

    # Create destination folder
    local dest_dir="$WORLDS_DIR/$folder_name"
    mkdir -p "$dest_dir"

    # Move world folders to destination
    print_info "Moving world to $folder_name..."
    for folder in "${WORLD_FOLDERS[@]}"; do
        if [ -d "$SERVER_DIR/$folder" ]; then
            mv "$SERVER_DIR/$folder" "$dest_dir/"
            print_info "  Moved $folder"
        fi
    done

    print_success "World $world_num saved as $folder_name"
    return 0
}

# Generate N worlds
cmd_gen() {
    local count=${1:-1}

    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
        print_error "Invalid count: $count (must be a positive integer)"
        exit 1
    fi

    ensure_worlds_dir

    print_info "Generating $count world(s)..."
    echo ""

    local start_num
    start_num=$(get_next_world_number)
    local successful=0
    local failed=0

    for i in $(seq 1 "$count"); do
        local world_num=$((start_num + i - 1))
        echo "=============================================="
        print_info "World $i of $count (will be num$world_num)"
        echo "=============================================="

        if generate_single_world "$world_num"; then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi

        echo ""
    done

    echo "=============================================="
    print_info "Generation complete!"
    print_success "Successful: $successful"
    if [ "$failed" -gt 0 ]; then
        print_error "Failed: $failed"
    fi
    echo "=============================================="
}

# Use a specific world
cmd_use() {
    local num=$1

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        print_error "Invalid world number: $num"
        exit 1
    fi

    # Find the world folder
    local world_folder=""
    for dir in "$WORLDS_DIR"/num${num}_*; do
        if [ -d "$dir" ]; then
            world_folder="$dir"
            break
        fi
    done

    if [ -z "$world_folder" ] || [ ! -d "$world_folder" ]; then
        print_error "World num$num not found!"
        print_info "Use 'bash worlds.bash list' to see available worlds."
        exit 1
    fi

    local folder_name
    folder_name=$(basename "$world_folder")

    print_warning "This will DELETE the current world permanently!"
    print_info "Loading world: $folder_name"
    echo ""
    read -p "Are you sure? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Cancelled."
        exit 0
    fi

    # Delete current world
    delete_current_world

    # Move saved world back to server
    print_info "Restoring world from $folder_name..."
    for folder in "${WORLD_FOLDERS[@]}"; do
        if [ -d "$world_folder/$folder" ]; then
            mv "$world_folder/$folder" "$SERVER_DIR/"
            print_info "  Restored $folder"
        fi
    done

    # Remove the now-empty world folder from worlds/
    rmdir "$world_folder" 2>/dev/null || rm -rf "$world_folder"

    print_success "World num$num is now active!"
    print_info "Run './run_world.bash' to start the server with this world."
}

# List all available worlds
cmd_list() {
    ensure_worlds_dir

    echo ""
    echo "=============================================="
    echo "         Available Minecraft Worlds          "
    echo "=============================================="
    echo ""

    local found=false
    local format="  %-6s %-24s %s\n"

    printf "$format" "NUM" "FOLDER NAME" "GENERATED"
    printf "$format" "---" "-----------" "---------"

    # Get all world folders sorted by number
    for dir in "$WORLDS_DIR"/num*; do
        if [ -d "$dir" ]; then
            found=true
            local basename_dir
            basename_dir=$(basename "$dir")

            # Extract number
            local num
            num=$(echo "$basename_dir" | sed 's/num\([0-9]*\)_.*/\1/')

            # Extract date/time from folder name (format: numX_YYYYMMDD_HHMMSS)
            local date_part time_part
            date_part=$(echo "$basename_dir" | sed 's/num[0-9]*_\([0-9]*\)_.*/\1/')
            time_part=$(echo "$basename_dir" | sed 's/num[0-9]*_[0-9]*_\([0-9]*\)/\1/')

            # Format date nicely: YYYY-MM-DD HH:MM:SS
            local formatted_date=""
            if [[ "$date_part" =~ ^[0-9]{8}$ ]] && [[ "$time_part" =~ ^[0-9]{6}$ ]]; then
                formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
            else
                formatted_date="Unknown"
            fi

            printf "$format" "$num" "$basename_dir" "$formatted_date"
        fi
    done

    echo ""

    if [ "$found" = false ]; then
        print_warning "No worlds found."
        print_info "Generate some with: bash worlds.bash gen 10"
    else
        echo "----------------------------------------------"
        echo "Usage: bash worlds.bash use <NUM>"
        echo "Example: bash worlds.bash use 1"
        echo "----------------------------------------------"
    fi

    echo ""
}

# Show usage
usage() {
    echo ""
    echo "Minecraft World Manager"
    echo ""
    echo "Usage:"
    echo "  bash worlds.bash gen <count>   Generate <count> new worlds"
    echo "  bash worlds.bash use <num>     Load world num<num> (deletes current)"
    echo "  bash worlds.bash list          List all available worlds"
    echo ""
    echo "Examples:"
    echo "  bash worlds.bash gen 10        Generate 10 new worlds"
    echo "  bash worlds.bash use 1         Switch to world num1"
    echo "  bash worlds.bash list          Show all saved worlds"
    echo ""
}

# Main entry point
main() {
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi

    local cmd=$1
    shift

    case "$cmd" in
        gen|generate)
            if [ $# -lt 1 ]; then
                print_error "Missing count argument!"
                echo "Usage: bash worlds.bash gen <count>"
                exit 1
            fi
            cmd_gen "$1"
            ;;
        use|load)
            if [ $# -lt 1 ]; then
                print_error "Missing world number!"
                echo "Usage: bash worlds.bash use <num>"
                exit 1
            fi
            cmd_use "$1"
            ;;
        list|ls)
            cmd_list
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
