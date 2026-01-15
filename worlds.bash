#!/usr/bin/env bash
# Advanced Minecraft World Manager with Chunky Pre-generation
# Usage:
#   bash worlds.bash gen N    - Generate N new worlds with chunk pre-generation
#   bash worlds.bash use N    - Switch to world N (deletes current world)
#   bash worlds.bash list     - List all available worlds

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/minecraft"
WORLDS_DIR="$SCRIPT_DIR/worlds"
CONFIG_FILE="$SCRIPT_DIR/config.json"
JAR="paper-1.21.11-92.jar"
WORLD_FOLDERS=("world" "world_nether" "world_the_end")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }
print_chunky() { echo -e "${MAGENTA}[CHUNKY]${NC} $1"; }

# Read config values (with defaults)
get_config() {
    local key=$1
    local default=$2

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$default"
        return
    fi

    local value
    case "$key" in
        "chunk_generation.enabled")
            value=$(grep -o '"enabled"[[:space:]]*:[[:space:]]*[^,}]*' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d ' ')
            ;;
        "chunk_generation.radius")
            value=$(grep -o '"radius"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//')
            ;;
        "chunk_generation.shape")
            value=$(grep -o '"shape"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*"//' | tr -d '"')
            ;;
        "chunk_generation.center_on_spawn")
            value=$(grep -o '"center_on_spawn"[[:space:]]*:[[:space:]]*[^,}]*' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d ' ')
            ;;
        "chunk_generation.timeout_seconds")
            value=$(grep -o '"timeout_seconds"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//')
            ;;
        "server.startup_timeout_seconds")
            value=$(grep -o '"startup_timeout_seconds"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//')
            ;;
        "server.max_memory_gb")
            value=$(grep -o '"max_memory_gb"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//')
            ;;
        *)
            value=""
            ;;
    esac

    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

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

# Get JVM memory settings (matches run_world.bash logic)
get_memory_settings() {
    local total_mem_kb total_mem_mb server_mem_mb max_mem_gb max_mem_mb
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_mem_mb=$((total_mem_kb / 1024))
    server_mem_mb=$((total_mem_mb * 80 / 100))

    # Cap minimum at 2GB if available
    if [ "$server_mem_mb" -lt 2048 ] && [ "$total_mem_mb" -ge 2048 ]; then
        server_mem_mb=2048
    fi

    # Apply max memory limit from config
    max_mem_gb=$(get_config "server.max_memory_gb" "0")
    if [ "$max_mem_gb" -gt 0 ]; then
        max_mem_mb=$((max_mem_gb * 1024))
        if [ "$server_mem_mb" -gt "$max_mem_mb" ]; then
            server_mem_mb=$max_mem_mb
        fi
    fi

    echo "$server_mem_mb"
}

# Run server with command input capability
run_server_for_world_gen() {
    local mem_mb
    mem_mb=$(get_memory_settings)

    print_info "Starting server with ${mem_mb}MB RAM..."

    cd "$SERVER_DIR"

    # Create a named pipe for sending commands
    local fifo_in="/tmp/mc_server_in_$$"
    local log_file="/tmp/mc_world_gen_$$.log"

    rm -f "$fifo_in"
    mkfifo "$fifo_in"

    # Start server with FIFO as stdin
    # Use tail -f to keep the FIFO open
    tail -f "$fifo_in" | java \
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

    local server_pid=$!
    local tail_pid=$(pgrep -P $$ -f "tail -f $fifo_in" | head -1)

    print_info "Server started with PID: $server_pid"

    # Function to send command to server
    send_command() {
        echo "$1" > "$fifo_in"
        sleep 0.5
    }

    # Wait for server to be ready
    print_info "Waiting for server startup..."
    local startup_timeout
    startup_timeout=$(get_config "server.startup_timeout_seconds" "300")
    local elapsed=0
    local done_found=false

    while [ $elapsed -lt "$startup_timeout" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            print_error "Server crashed unexpectedly!"
            tail -50 "$log_file"
            rm -f "$fifo_in" "$log_file"
            return 1
        fi

        if grep -q "Done" "$log_file" 2>/dev/null; then
            done_found=true
            print_success "Server started successfully!"
            break
        fi

        sleep 2
        elapsed=$((elapsed + 2))

        if [ $((elapsed % 10)) -eq 0 ]; then
            print_info "  Still starting... (${elapsed}s elapsed)"
        fi
    done

    if [ "$done_found" = false ]; then
        print_error "Timeout waiting for server startup!"
        kill "$server_pid" 2>/dev/null || true
        kill "$tail_pid" 2>/dev/null || true
        rm -f "$fifo_in" "$log_file"
        return 1
    fi

    # Give server a moment to settle
    sleep 3

    # Check if Chunky pre-generation is enabled
    local chunky_enabled
    chunky_enabled=$(get_config "chunk_generation.enabled" "true")

    if [ "$chunky_enabled" = "true" ]; then
        print_chunky "Starting chunk pre-generation..."

        local radius shape
        radius=$(get_config "chunk_generation.radius" "500")
        shape=$(get_config "chunk_generation.shape" "square")

        print_chunky "Configuration: ${radius} block radius, ${shape} shape"

        # Configure Chunky
        send_command "chunky world world"
        sleep 1
        send_command "chunky shape $shape"
        sleep 1
        send_command "chunky spawn"
        sleep 1
        send_command "chunky radius $radius"
        sleep 1

        # Start generation
        send_command "chunky start"
        sleep 2

        # Wait for Chunky to complete
        local chunky_timeout
        chunky_timeout=$(get_config "chunk_generation.timeout_seconds" "600")
        local chunky_elapsed=0
        local chunky_done=false

        print_chunky "Generating chunks (timeout: ${chunky_timeout}s)..."

        while [ $chunky_elapsed -lt "$chunky_timeout" ]; do
            if ! kill -0 "$server_pid" 2>/dev/null; then
                print_error "Server crashed during chunk generation!"
                rm -f "$fifo_in" "$log_file"
                return 1
            fi

            # Check for Chunky completion - only "Task finished" is definitive
            # (100% progress can appear before finalization is complete)
            if grep -q "Task finished for" "$log_file" 2>/dev/null; then
                chunky_done=true
                print_success "Chunk pre-generation complete!"
                break
            fi

            # Show progress from Chunky
            local progress
            progress=$(grep -oE "[0-9]+\.[0-9]+%.*chunks" "$log_file" 2>/dev/null | tail -1 || echo "")
            if [ -n "$progress" ]; then
                print_chunky "  Progress: $progress"
            fi

            sleep 5
            chunky_elapsed=$((chunky_elapsed + 5))

            if [ $((chunky_elapsed % 30)) -eq 0 ] && [ -z "$progress" ]; then
                print_info "  Still generating... (${chunky_elapsed}s elapsed)"
            fi
        done

        if [ "$chunky_done" = false ]; then
            print_warning "Chunky timeout reached, stopping generation..."
            send_command "chunky cancel"
            sleep 2
        fi

        # Save the world
        print_info "Saving world..."
        send_command "save-all"
        sleep 5
    fi

    # Stop server gracefully
    print_info "Stopping server gracefully..."
    send_command "stop"

    # Wait for server to stop
    local stop_timeout=60
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

    # Clean up tail process
    kill "$tail_pid" 2>/dev/null || true
    pkill -f "tail -f $fifo_in" 2>/dev/null || true

    print_success "Server stopped."

    # Cleanup
    rm -f "$fifo_in" "$log_file"

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

    # Show config
    echo ""
    print_info "Configuration (from config.json):"
    local chunky_enabled radius shape max_mem_gb
    chunky_enabled=$(get_config "chunk_generation.enabled" "true")
    radius=$(get_config "chunk_generation.radius" "500")
    shape=$(get_config "chunk_generation.shape" "square")
    max_mem_gb=$(get_config "server.max_memory_gb" "0")
    print_info "  Max memory: ${max_mem_gb}GB"
    print_info "  Chunky enabled: $chunky_enabled"
    print_info "  Radius: ${radius} blocks"
    print_info "  Shape: $shape"
    echo ""

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
    echo "Minecraft World Manager with Chunky Pre-generation"
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
    echo "Configuration: Edit config.json to change settings"
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
