#!/usr/bin/env bash
# Installs Terraform, kubectl, eksctl, Stratus Red Team and Python libs into ~/bin (persists in CloudShell $HOME).
set -euo pipefail
mkdir -p ~/bin && cd /tmp
grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/bin:$PATH
ARCH=$(uname -m); [[ "$ARCH" == "x86_64" ]] && A=amd64 || A=arm64

TF_VER="${TF_VER:-1.9.8}"
echo "▶ terraform $TF_VER"
curl -fsSLo tf.zip "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_${A}.zip"
unzip -o -q tf.zip -d ~/bin && rm tf.zip

echo "▶ kubectl (stable)"
K=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSLo ~/bin/kubectl "https://dl.k8s.io/release/${K}/bin/linux/${A}/kubectl" && chmod +x ~/bin/kubectl

echo "▶ eksctl (latest)"
curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${A}.tar.gz" | tar xz -C ~/bin

echo "▶ stratus red team (latest)"
SA=$( [[ $A == amd64 ]] && echo x86_64 || echo arm64 )
URL=$(curl -fsSL https://api.github.com/repos/DataDog/stratus-red-team/releases/latest \
      | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 | grep -i "linux_${SA}.tar.gz" | head -1)
if [[ -n "$URL" ]]; then curl -fsSL "$URL" | tar xz -C ~/bin stratus || echo "  (stratus install failed — Day 2 has a fallback)"; else echo "  (could not resolve stratus asset — Day 2 has a fallback)"; fi

echo "▶ python libs"
python3 -m pip install --user --quiet boto3 cryptography cedarpy 2>/dev/null || python3 -m pip install --user --quiet boto3 cryptography

echo
terraform version | head -1; kubectl version --client 2>/dev/null | head -1; eksctl version; stratus version 2>/dev/null || true
echo "✅ tools installed. Open a new shell or: export PATH=\$HOME/bin:\$PATH"
