#!/bin/bash

set -eo pipefail

# Make Sure The Environment Is Non-Interactive
export DEBIAN_FRONTEND=noninteractive

echo "::group:: Prepare R3ncod3r Tool"
printf "Adding Required Applications for R3ncod3r...\n"
cd "$(mktemp -d)"
wget -q "${FTOOL_ARC_URL}" || curl -sL "${FTOOL_ARC_URL}" -O
tar -xJf ff*.tar.xz --strip-components 1
printf "Compressing Binaries before Use\n"
upx -q -1 --no-backup bin/*
chmod a+x bin/*
sudo mv bin/* /usr/local/bin/
cd -
${FTOOL_CONVERTER} -version
echo "::endgroup::"
