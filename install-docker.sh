#!/usr/bin/env bash

set -Eeuo pipefail

log() { echo "[INFO] $1"; }
check() { echo "[CHECK] $1"; }
testlog() { echo "[TEST] $1"; }
error() { echo "[ERROR] $1" >&2; }

trap 'error "Installation failed on line $LINENO"; exit 1' ERR

wait_for_apt() {
  check "Waiting for apt locks to be released"
  while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || 
        sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || 
        sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    log "Another apt process is running. Waiting..."
    sleep 3
  done
}

check "Verifying sudo access"
sudo -v

check "Detecting operating system"
. /etc/os-release
DISTRO="$ID"
log "Detected $PRETTY_NAME"

check "Checking internet connectivity"
curl -fsSL https://download.docker.com >/dev/null

install_debian_family() {
  log "Using apt package manager"

  wait_for_apt
  sudo apt-get update -y

  wait_for_apt
  sudo apt-get install -y ca-certificates curl gnupg

  sudo install -m 0755 -d /etc/apt/keyrings

  curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | 
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  ARCH=$(dpkg --print-architecture)

  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null <<EOF
deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $VERSION_CODENAME stable
EOF

  wait_for_apt
  sudo apt-get update -y

  wait_for_apt
  sudo apt-get install -y 
    docker-ce 
    docker-ce-cli 
    containerd.io 
    docker-buildx-plugin 
    docker-compose-plugin
}

install_rhel_family() {
  if command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
  else
    PKG="yum"
  fi

  log "Using $PKG package manager"

  sudo $PKG -y install dnf-plugins-core || true

  sudo $PKG config-manager 
    --add-repo https://download.docker.com/linux/$DISTRO/docker-ce.repo

  sudo $PKG -y install 
    docker-ce 
    docker-ce-cli 
    containerd.io 
    docker-buildx-plugin 
    docker-compose-plugin
}

case "$DISTRO" in
  ubuntu|debian)
    install_debian_family
    ;;
  fedora|centos|rhel|rocky|almalinux)
    install_rhel_family
    ;;
  *)
    error "Unsupported distribution: $DISTRO"
    exit 1
    ;;
esac

log "Enabling and starting Docker"
sudo systemctl enable docker
sudo systemctl start docker

log "Adding user '$USER' to docker group"
sudo usermod -aG docker "$USER"

testlog "Checking Docker version"
sudo docker --version

testlog "Running hello-world test"
sudo docker run --rm hello-world

log "Cleaning package cache"
if command -v apt-get >/dev/null 2>&1; then
  wait_for_apt
  sudo apt-get clean
else
  sudo dnf clean all 2>/dev/null || sudo yum clean all
fi

log "Installation completed successfully"
log "Log out and back in to use Docker without sudo"

if [[ -f "$0" ]]; then
  log "Removing installer script"
  rm -- "$0"
else
  log "Installer was run via pipe. No file to remove"
fi
