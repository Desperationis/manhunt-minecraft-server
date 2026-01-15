#!/usr/bin/env bash
# Install requirements for Minecraft Paper server on Debian 13 (trixie)
set -euo pipefail

echo "Installing Java 21 for Minecraft Paper server..."

# Update package list
sudo apt update

# Install OpenJDK 21 (headless is sufficient for server)
sudo apt install -y openjdk-21-jre-headless

# Verify installation
echo ""
echo "Verifying Java installation..."
java -version

echo ""
echo "Java 21 installed successfully!"
echo "You can now run the server with:"
echo "  ./run_world.bash"
echo "Or manually:"
echo "  cd minecraft && java -Xmx2G -Xms1G -jar paper-1.21.11-92.jar --nogui"
