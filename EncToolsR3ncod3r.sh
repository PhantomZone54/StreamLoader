#!/bin/bash

set -eo pipefail

# Make Sure The Environment Is Non-Interactive
export DEBIAN_FRONTEND=noninteractive

echo "::group:: Prepare R3ncod3r Tool"
printf "Installing Required Applications for R3ncod3r...\n"
cd "$(mktemp -d)"
wget -q "${FTOOL_ARC_URL}" || curl -sL "${FTOOL_ARC_URL}" -O
tar -xJf ff*.tar.xz --strip-components 1
sudo mv bin/* /usr/local/bin/
cd -
${FTOOL_CONVERTER} -version
echo "::endgroup::"
