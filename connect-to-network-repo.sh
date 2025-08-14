#!/bin/bash
#
#	connect-to-network.sh
#
#	Script to set up a display server to connect to a local network repo
#
#===================================================================================

# Make sure the http server is running on the host machine
#cd ~/marquee-magic_repo; python3 -m http.server 8000


# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# The address of the server hosting the repository.
REPO_HOST="nuc.local"
# The port the HTTP server is running on.
REPO_PORT="8000"
# The unique ID for your repository (must match the server's repo ID if it has one).
REPO_ID="local-network-repo"
# A human-readable name for your repository.
REPO_NAME="My Local Network Repository"
# --- End Configuration ---

# Check if the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Error: Please run this script as root or using sudo."
  exit 1
fi

echo "--- Configuring DNF to use the network repository at http://${REPO_HOST}:${REPO_PORT} ---"

# 1. Create the DNF repository file
echo "STEP 1: Creating DNF repository file..."
cat > "/etc/yum.repos.d/${REPO_ID}.repo" << EOF
[${REPO_ID}]
name=${REPO_NAME}
baseurl=http://${REPO_HOST}:${REPO_PORT}/
enabled=1
gpgcheck=0
metadata_expire=1m
EOF

echo "Repository file '/etc/yum.repos.d/${REPO_ID}.repo' created successfully."

# 2. Clean the DNF cache and verify
echo "STEP 2: Cleaning DNF cache to fetch new repository data..."
dnf clean all > /dev/null

echo "STEP 3: Verifying connection to the new repository..."
echo "Your new network repository should be listed below:"
# Use dnf repoinfo for a more detailed check, or repolist for a quick one.
if dnf repolist | grep -q "${REPO_ID}"; then
    echo "✅ Success! Repository '${REPO_ID}' is now active."
    echo "You can now install packages using 'sudo dnf install <your-package-name>'."
else
    echo "❌ Error: Could not find the repository '${REPO_ID}'."
    echo "Please check the following:"
    echo "  1. The server at '${REPO_HOST}' is running and accessible from this machine."
    echo "  2. The HTTP server is running on port ${REPO_PORT} on the server."
    echo "  3. The firewall on the server allows incoming connections on port ${REPO_PORT}."
fi
