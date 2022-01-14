#!/bin/bash

# Make Sure The Environment Is Non-Interactive
export DEBIAN_FRONTEND=noninteractive

echo "::group:: Prepare Tools"
sudo apt-fast install -qqy mkvtoolnix
curl -sL "${RCLONE_INSTALL_MIRROR}" | sudo bash 1>/dev/null
mkdir -p ~/.config/rclone
curl -sL "${RCLONE_CONFIG_URL}" > ~/.config/rclone/rclone.conf
cd "$(mktemp -d)"
wget -q ${FTOOL_ARC_URL} || curl -sL ${FTOOL_ARC_URL} -O
tar -xJf ff*.tar.xz --strip-components 1
sudo mv bin/* /usr/local/bin/
cd -
echo "::endgroup::"
