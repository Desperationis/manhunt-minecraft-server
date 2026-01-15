#!/usr/bin/env bash
# Install requirements for Minecraft Paper server on Debian 13 (trixie)
set -euo pipefail

# Determine if we need sudo (skip if already root, e.g., in Docker)
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
    else
        echo "Error: Not running as root and sudo is not available."
        exit 1
    fi
fi

echo "Installing Java 21 for Minecraft Paper server..."

# Update package list
$SUDO apt update

# Install OpenJDK 21 (headless is sufficient for server)
$SUDO apt install -y openjdk-21-jre-headless

# Verify installation
echo ""
echo "Verifying Java installation..."
java -version

echo ""
echo "Java 21 installed successfully!"

# Configure UFW firewall if installed
if command -v ufw &> /dev/null; then
    echo ""
    echo "UFW detected. Allowing Minecraft server port (25565)..."
    $SUDO ufw allow 25565/tcp comment "Minecraft Server"
    echo "Firewall rule added for Minecraft server."
fi

echo ""
echo "You can now run the server with:"
echo "  ./run_world.bash"
echo "Or manually:"
echo "  cd minecraft && java -Xmx2G -Xms1G -jar paper-1.21.11-92.jar --nogui"
