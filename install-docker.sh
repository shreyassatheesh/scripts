#!/usr/bin/env bash

###############################################################################
# mozhi.works Docker Installer
#
# This script is provided by mozhi.works. We wrapped common Docker install
# commands into a single installer script for convenience. We are NOT
# responsible for any damage, data loss, or system issues that may occur.
# Use at your own risk.
###############################################################################

set -e

LOG_PREFIX="[INFO]"

log() {
  echo "${LOG_PREFIX} $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Check for root privileges
log "Checking for root privileges"
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root. Try: sudo $0"
fi

# Detect Linux distribution
log "Detecting Linux distribution"
if [ ! -f /etc/os-release ]; then
  error "/etc/os-release not found. Cannot detect distribution."
fi

source /etc/os-release
DISTRO_ID=$ID
DISTRO_LIKE=$ID_LIKE

log "Detected distro ID: $DISTRO_ID"
log "Detected distro family: $DISTRO_LIKE"

install_docker_debian() {
  ###########################################################################
  # Supported: Debian, Ubuntu, Linux Mint, Pop!_OS and other Debian-based
  ###########################################################################
  log "Installing Docker on a Debian-based distribution"

  log "Updating package index"
  apt-get update -y

  log "Installing prerequisite packages"
  apt-get install -y ca-certificates curl gnupg lsb-release

  log "Adding Docker GPG key"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$DISTRO_ID/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  log "Adding Docker repository"
  echo \
    "deb [arch=$(dpkg --print-architecture) \
    signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/$DISTRO_ID \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  log "Updating package index after adding Docker repo"
  apt-get update -y

  log "Installing Docker Engine"
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_rhel() {
  ###########################################################################
  # Supported: RHEL, CentOS, Rocky Linux, AlmaLinux, Fedora and RHEL-based
  ###########################################################################
  log "Installing Docker on an RHEL-based distribution"

  log "Installing dnf/yum utilities"
  if command -v dnf >/dev/null 2>&1; then
    dnf -y install dnf-plugins-core
    log "Adding Docker repository"
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    log "Installing Docker Engine"
    dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    yum -y install yum-utils
    log "Adding Docker repository"
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    log "Installing Docker Engine"
    yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
}

install_docker_arch() {
  ###########################################################################
  # Supported: Arch Linux and Arch-based distributions
  ###########################################################################
  log "Installing Docker on an Arch-based distribution"

  log "Synchronizing package database"
  pacman -Sy --noconfirm

  log "Installing Docker package"
  pacman -S --noconfirm docker
}

install_docker_opensuse() {
  ###########################################################################
  # Supported: openSUSE Leap and Tumbleweed
  ###########################################################################
  log "Installing Docker on openSUSE"

  log "Refreshing repositories"
  zypper refresh

  log "Installing Docker package"
  zypper install -y docker
}

# Select installer based on distro
case "$DISTRO_ID" in
  ubuntu|debian)
    install_docker_debian
    ;;
  fedora|centos|rhel|rocky|almalinux)
    install_docker_rhel
    ;;
  arch)
    install_docker_arch
    ;;
  opensuse*|sles)
    install_docker_opensuse
    ;;
  *)
    if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
      install_docker_debian
    elif [[ "$DISTRO_LIKE" == *"rhel"* || "$DISTRO_LIKE" == *"fedora"* ]]; then
      install_docker_rhel
    else
      error "Unsupported or unknown distribution: $DISTRO_ID"
    fi
    ;;
esac

# Enable and start Docker service
log "Enabling Docker service to start on boot"
systemctl enable docker

log "Starting Docker service"
systemctl start docker

log "Verifying Docker installation"
docker --version || error "Docker installation verification failed"

log "Docker installation completed successfully"
