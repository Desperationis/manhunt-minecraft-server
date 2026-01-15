# Minecraft Manhunt Server Setup

A reproducible Minecraft Paper server with the Manhunt+ plugin for playing Dream-style manhunt games, and Chunky for pre-generating the world.

## Requirements

- Java 21 or newer
- Linux (tested on Debian/Ubuntu)
- Minimum 2GB RAM recommended

## Server Components

| File | Description |
|------|-------------|
| `minecraft/paper-1.21.11-92.jar` | Paper server (Minecraft 1.21.11) |
| `minecraft/plugins/ManhuntPlus-1.3.jar` | Manhunt+ plugin |
| `minecraft/plugins/Chunky-Bukkit-1.4.40.jar` | Chunk pre-generator |

## Helper Scripts

| Script | Description |
|--------|-------------|
| `run_world.bash` | Run the server with optimal settings |
| `install_requirements.bash` | Install Java 21 on Debian 13 |
| `worlds.bash` | Advanced world manager with Chunky pre-generation |
| `compile_pdf.bash` | Compile README.md to PDF |
| `clean.bash` | Clean git-ignored files (reset to fresh state) |

## Quick Start

### 0. Install Requirements (Debian 13)

```bash
./install_requirements.bash
```

This installs OpenJDK 21.

### 1. First-time Setup

The server and plugins are already in place. Just accept the EULA:

```bash
echo "eula=true" > minecraft/eula.txt
```

### 2. Start the Server

```bash
./run_world.bash
```

This auto-detects your system RAM and runs the server with optimized JVM flags (Aikar's flags).

### 3. Connect

Connect via Minecraft multiplayer using `localhost` or your server's IP address on port `25565`.

## Manhunt+ Commands

| Command | Description |
|---------|-------------|
| `/manhunt start` | Start the manhunt game |
| `/manhunt stop` | Stop the manhunt game |
| `/manhunt list` | List all hunters and speedrunners |
| `/speedrunner add <player>` | Add a player as speedrunner |
| `/speedrunner remove <player>` | Remove a speedrunner |
| `/hunter add <player>` | Add a player as hunter |
| `/hunter remove <player>` | Remove a hunter |
| `/compass <player>` | Track a specific speedrunner |

## Chunky Commands (World Pre-generation)

Pre-generating chunks eliminates lag during gameplay.

### Basic Usage

```bash
# Set the world to pre-generate
/chunky world world

# Set radius (in blocks)
/chunky radius 5000

# Start pre-generation
/chunky start

# Check progress
/chunky progress

# Pause if needed
/chunky pause

# Resume later
/chunky continue
```

### All Commands

| Command | Description |
|---------|-------------|
| `/chunky start` | Start chunk generation |
| `/chunky pause` | Pause and save progress |
| `/chunky continue` | Resume saved task |
| `/chunky cancel` | Stop and discard progress |
| `/chunky world <name>` | Set target world (`world`, `world_nether`, `world_the_end`) |
| `/chunky center <x> <z>` | Set center coordinates |
| `/chunky radius <blocks>` | Set radius (supports `5k` for 5000, `100c` for 100 chunks) |
| `/chunky shape <shape>` | Set shape (`square`, `circle`, etc.) |
| `/chunky worldborder` | Match the vanilla world border |
| `/chunky progress` | Show generation progress |
| `/chunky trim` | Delete chunks outside selection |

### Recommended Pre-generation

Before playing manhunt, pre-generate all three dimensions:

```bash
# Overworld (5000 block radius)
/chunky world world
/chunky radius 5000
/chunky start

# Wait for completion, then Nether
/chunky world world_nether
/chunky radius 625
/chunky start

# Wait for completion, then End
/chunky world world_the_end
/chunky radius 1000
/chunky start
```

## World Manager (worlds.bash)

The `worlds.bash` script provides automated world generation with Chunky pre-generation, making it easy to generate and manage multiple worlds for quick game resets.

### Commands

| Command | Description |
|---------|-------------|
| `bash worlds.bash gen <n>` | Generate n new worlds with chunk pre-generation |
| `bash worlds.bash use <n>` | Load world n (permanently deletes current world) |
| `bash worlds.bash list` | List all saved worlds with generation dates |

### How It Works

When you run `bash worlds.bash gen 10`:

1. **For each world (1-10):**
   - Deletes any existing world in `minecraft/`
   - Starts the Minecraft server
   - Waits for the world to generate (detects "Done" message)
   - Sends Chunky commands to pre-generate chunks around spawn:
     - `chunky world world` - Select overworld
     - `chunky shape square` - Use square shape
     - `chunky spawn` - Center on spawn point
     - `chunky radius Nc` - Set radius in chunks
     - `chunky start` - Begin generation
   - Monitors Chunky progress until completion
   - Saves with `save-all` and gracefully stops the server
   - Moves all world folders (`world`, `world_nether`, `world_the_end`) to `worlds/numX_YYYYMMDD_HHMMSS/`

2. **Worlds are stored in:** `worlds/` folder with naming like `num1_20260114_153022`

### Configuration (config.json)

Edit `config.json` in the root directory to customize server and generation settings:

```json
{
  "server": {
    "max_memory_gb": 8,
    "startup_timeout_seconds": 300
  },
  "chunk_generation": {
    "enabled": true,
    "chunks": 100,
    "shape": "square",
    "center_on_spawn": true,
    "timeout_seconds": 600
  }
}
```

| Setting | Description |
|---------|-------------|
| `max_memory_gb` | Maximum RAM for the server (used by both `run_world.bash` and `worlds.bash`) |
| `startup_timeout_seconds` | Max seconds to wait for server startup |
| `enabled` | Set to `false` to skip Chunky pre-generation |
| `chunks` | Total chunks to pre-generate (100 = 10x10 square) |
| `shape` | Chunky shape: `square`, `circle`, `diamond`, etc. |
| `center_on_spawn` | Always centers on world spawn point |
| `timeout_seconds` | Max seconds to wait for chunk generation |

### Chunk Count Examples

The script calculates radius as `sqrt(chunks) / 2`:

| Chunks | Grid Size | Radius | Approximate Area |
|--------|-----------|--------|------------------|
| 100 | 10x10 | 5c (80 blocks) | 160x160 blocks |
| 400 | 20x20 | 10c (160 blocks) | 320x320 blocks |
| 900 | 30x30 | 15c (240 blocks) | 480x480 blocks |
| 2500 | 50x50 | 25c (400 blocks) | 800x800 blocks |

### Usage Examples

```bash
# Generate 10 pre-generated worlds
bash worlds.bash gen 10

# List available worlds
bash worlds.bash list
# Output:
#   NUM    FOLDER NAME              GENERATED
#   1      num1_20260114_153022     2026-01-14 15:30:22
#   2      num2_20260114_153512     2026-01-14 15:35:12
#   ...

# Switch to world 3 (deletes current world permanently!)
bash worlds.bash use 3

# Start playing on the loaded world
./run_world.bash
```

### Notes

- The `use` command **permanently deletes** the current world before loading
- A confirmation prompt prevents accidental deletion
- Loaded worlds are removed from the `worlds/` folder (one-time use)
- Generate more worlds anytime with `gen` - numbering continues automatically

## How to Play

1. All players join the server
2. Assign one or more players as speedrunners: `/speedrunner add <player>`
3. Assign remaining players as hunters: `/hunter add <player>`
4. Start the game: `/manhunt start`
5. Hunters receive tracking compasses that point to speedrunners
6. Speedrunners win by killing the Ender Dragon
7. Hunters win by killing all speedrunners

## Configuration

After first run, edit `plugins/ManhuntPlus/config.yml`:

```yaml
# Compass auto-calibration interval (in ticks, 20 ticks = 1 second)
# Increase for larger servers, or disable for manual tracking
auto-calibration-interval: 20

# Distance between speedrunner and hunters when using /surround
surround-radius: 3.0
```

Restart the server after changing configuration.

## Server Properties

Edit `server.properties` for common settings:

```properties
# Server name shown in multiplayer list
motd=Manhunt Server

# Maximum players
max-players=10

# Game difficulty (peaceful, easy, normal, hard)
difficulty=hard

# Enable/disable PvP
pvp=true

# Whitelist
white-list=false
```

## Downloading Components

### Paper Server
Download from: https://papermc.io/downloads/paper

### Manhunt+ Plugin
Download from: https://modrinth.com/plugin/manhunt+

### Chunky Plugin
Download from: https://modrinth.com/plugin/chunky

## Troubleshooting

**Server won't start:**
- Ensure Java 21+ is installed: `java -version`
- Check that `eula.txt` contains `eula=true`

**Plugin not loading:**
- Verify `.jar` file is in `plugins/` folder
- Check `logs/latest.log` for errors

**Players can't connect:**
- Ensure port 25565 is open in firewall
- Check `server.properties` for correct settings

## File Structure

```
MINECRAFTSERVER/
├── run_world.bash           # Start the server
├── worlds.bash              # World manager script
├── config.json              # Server and generation settings
├── install_requirements.bash
├── compile_pdf.bash
├── clean.bash               # Clean git-ignored files
├── README.md
├── .gitignore
├── minecraft/               # Server directory
│   ├── paper-1.21.11-92.jar
│   ├── eula.txt
│   ├── server.properties
│   ├── bukkit.yml
│   ├── spigot.yml
│   ├── commands.yml
│   ├── plugins/
│   │   ├── ManhuntPlus-1.3.jar
│   │   ├── Chunky-Bukkit-1.4.40.jar
│   │   ├── ManhuntPlus/     # Plugin config (generated)
│   │   └── Chunky/          # Plugin config (generated)
│   ├── world/               # Current active world
│   ├── world_nether/
│   └── world_the_end/
└── worlds/                  # Saved worlds from worlds.bash
    ├── num1_20260114_153022/
    │   ├── world/
    │   ├── world_nether/
    │   └── world_the_end/
    ├── num2_20260114_153512/
    └── ...
```

## Sources

- [Manhunt+ on Modrinth](https://modrinth.com/plugin/manhunt+)
- [Chunky on Modrinth](https://modrinth.com/plugin/chunky)
- [Chunky Commands Wiki](https://github.com/pop4959/Chunky/wiki/Commands)
- [Paper Downloads](https://papermc.io/downloads/paper)
- [Aikar's JVM Flags](https://docs.papermc.io/paper/aikars-flags)
