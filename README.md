# Minecraft Manhunt Server Setup

A reproducible Minecraft Paper server with the Manhunt+ plugin for playing Dream-style manhunt games, and Chunky for pre-generating the world.

## Requirements

- Java 21 or newer
- Linux (tested on Debian/Ubuntu)
- Minimum 2GB RAM recommended

## Server Components

| File | Description |
|------|-------------|
| `paper-1.21.11-92.jar` | Paper server (Minecraft 1.21.11) |
| `ManhuntPlus-1.3.jar` | Manhunt+ plugin |
| `Chunky-Bukkit-1.4.40.jar` | Chunk pre-generator |

## Helper Scripts

| Script | Description |
|--------|-------------|
| `run_world.bash` | Run the server with optimal settings |
| `install_requirements.bash` | Install Java 21 on Debian 13 |
| `generate_worlds.bash <n>` | Generate n world folders for quick resets |
| `compile_pdf.bash` | Compile README.md to PDF |

## Quick Start

### 0. Install Requirements (Debian 13)

```bash
./install_requirements.bash
```

This installs OpenJDK 21.

### 1. First-time Setup

```bash
# Create plugins directory
mkdir -p plugins

# Move the plugins to plugins folder
mv ManhuntPlus-1.3.jar Chunky-Bukkit-1.4.40.jar plugins/

# Accept the EULA
echo "eula=true" > eula.txt
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

## Batch World Generation

Generate multiple pre-made worlds for quick game resets:

```bash
# Generate 10 worlds (manhunt_01 through manhunt_10)
./generate_worlds.bash 10
```

This creates separate world folders you can swap in:

```bash
# To use a specific world, stop the server then:
rm -rf world world_nether world_the_end
cp -r manhunt_05 world
cp -r manhunt_05_nether world_nether
cp -r manhunt_05_the_end world_the_end

# Start the server with the new world
./run_world.bash
```

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
├── paper-1.21.11-92.jar
├── eula.txt
├── server.properties
├── run_world.bash
├── install_requirements.bash
├── generate_worlds.bash
├── compile_pdf.bash
├── README.md
├── plugins/
│   ├── ManhuntPlus-1.3.jar
│   └── Chunky-Bukkit-1.4.40.jar
├── world/
├── world_nether/
├── world_the_end/
├── manhunt_01/          # Generated worlds
├── manhunt_01_nether/
├── manhunt_01_the_end/
└── ...
```

## Sources

- [Manhunt+ on Modrinth](https://modrinth.com/plugin/manhunt+)
- [Chunky on Modrinth](https://modrinth.com/plugin/chunky)
- [Chunky Commands Wiki](https://github.com/pop4959/Chunky/wiki/Commands)
- [Paper Downloads](https://papermc.io/downloads/paper)
- [Aikar's JVM Flags](https://docs.papermc.io/paper/aikars-flags)
