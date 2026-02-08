#!/usr/bin/env bash

###############################################################################
# Docker Uninstallation Script
#
# Supported distros:
# Debian, Ubuntu and Debian-based
# RHEL, CentOS, Rocky, AlmaLinux, Fedora and RHEL-based
# Arch Linux and Arch-based
# openSUSE Leap and Tumbleweed
#
# This script was created by Mozhi Works [mozhi.works].
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

log ""
log "This Docker uninstallation script was created by Mozhi Works [mozhi.works]. It removes Docker packages and related components. We are not responsible for any damage, data loss, or system issues that may occur. Use at your own risk."
log "Press ^C now to cancel if you do not want to continue. Waiting 5 seconds..."
log ""
sleep 5

log "Checking for root privileges"
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root. Try: sudo $0"
fi

log "Detecting Linux distribution"
if [ ! -f /etc/os-release ]; then
  error "/etc/os-release not found. Cannot detect distribution."
fi

source /etc/os-release
DISTRO_ID=$ID
DISTRO_LIKE=$ID_LIKE

log "Detected distro ID: $DISTRO_ID"
log "Detected distro family: $DISTRO_LIKE"

stop_docker() {
  log "Stopping Docker service if running"
  systemctl stop docker 2>/dev/null || true
  systemctl disable docker 2>/dev/null || true
}

uninstall_docker_debian() {
  log "Uninstalling Docker on a Debian-based distribution"

  stop_docker

  log "Removing Docker packages"
  apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true

  log "Removing unused dependencies"
  apt-get autoremove -y

  log "Removing Docker repository and keyrings"
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/keyrings/docker.gpg

  log "Updating package index"
  apt-get update -y
}

uninstall_docker_rhel() {
  log "Uninstalling Docker on an RHEL-based distribution"

  stop_docker

  if command -v dnf >/dev/null 2>&1; then
    log "Removing Docker packages with dnf"
    dnf -y remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true
  else
    log "Removing Docker packages with yum"
    yum -y remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true
  fi
}

uninstall_docker_arch() {
  log "Uninstalling Docker on an Arch-based distribution"

  stop_docker

  log "Removing Docker package"
  pacman -Rns --noconfirm docker || true
}

uninstall_docker_opensuse() {
  log "Uninstalling Docker on openSUSE"

  stop_docker

  log "Removing Docker package"
  zypper remove -y docker || true
}

log "Docker images, containers, and volumes in /var/lib/docker are NOT removed by default"

case "$DISTRO_ID" in
  ubuntu|debian)
    uninstall_docker_debian
    ;;
  fedora|centos|rhel|rocky|almalinux)
    uninstall_docker_rhel
    ;;
  arch)
    uninstall_docker_arch
    ;;
  opensuse*|sles)
    uninstall_docker_opensuse
    ;;
  *)
    if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
      uninstall_docker_debian
    elif [[ "$DISTRO_LIKE" == *"rhel"* || "$DISTRO_LIKE" == *"fedora"* ]]; then
      uninstall_docker_rhel
    else
      error "Unsupported or unknown distribution: $DISTRO_ID"
    fi
    ;;
esac

log "Docker uninstallation completed successfully"
