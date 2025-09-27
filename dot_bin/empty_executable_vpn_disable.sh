#!/bin/bash

# Script to temporarily disable Tailscale exit node

set -e

# Check if tailscale is installed
command -v tailscale &>/dev/null || exit 1

# Get current exit node IP address
current_exit_node=$(sudo tailscale status --json | jq -r '.ExitNodeStatus.TailscaleIPs[0] // empty' | cut -d'/' -f1)

# Exit if no exit node configured
[[ -z "$current_exit_node" ]] && exit 0

# Disable the exit node
sudo tailscale set --exit-node="" || exit 1

# Wait for user input
echo "Press Enter to re-enable exit node..."
read -r

# Re-enable the exit node
sudo tailscale set --exit-node="$current_exit_node"
