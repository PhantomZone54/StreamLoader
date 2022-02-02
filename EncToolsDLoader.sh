#!/bin/bash

set -eo pipefail

# Make Sure The Environment Is Non-Interactive
export DEBIAN_FRONTEND=noninteractive

echo "::group:: Prepare DLoader Tool"
printf "Installing Required Applications for rclone...\n"
curl -sL "${RCLONE_INSTALL_MIRROR}" | sudo bash
mkdir -p ~/.config/rclone
curl -sL "${RCLONE_CONFIG_URL}" >~/.config/rclone/rclone.conf
echo "::endgroup::"
