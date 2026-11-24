#!/usr/bin/env bash
# Lab 2.2 · install Stratus Red Team (DataDog, Apache-2.0) into ~/bin in CloudShell.
# https://github.com/DataDog/stratus-red-team
set -euo pipefail
mkdir -p "$HOME/bin"
ARCH=$(uname -m); [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
URL=$(curl -fsSL https://api.github.com/repos/DataDog/stratus-red-team/releases/latest \
  | jq -r --arg a "$ARCH" '.assets[] | select(.name | test("Linux_" + $a + "\\.tar\\.gz$")) | .browser_download_url' | head -1)
[[ -z "$URL" ]] && { echo "Could not find a Linux_$ARCH release asset"; exit 1; }
echo "==> downloading $URL"
curl -fsSL "$URL" | tar -xz -C "$HOME/bin" stratus
chmod +x "$HOME/bin/stratus"
"$HOME/bin/stratus" version
echo 'Add to PATH:  export PATH="$HOME/bin:$PATH"'
