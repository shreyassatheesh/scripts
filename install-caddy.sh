#!/usr/bin/env bash

###############################################################################
# Caddy Installation Script
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
log "This Caddy installation script was created by Mozhi Works [mozhi.works]. We wrapped common Caddy installation commands into a single script for convenience. We are not responsible for any damage, data loss, or system issues that may occur. Use at your own risk."
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

install_caddy_debian() {
  log "Installing Caddy on a Debian-based distribution"

  log "Updating package index"
  apt-get update -y

  log "Installing prerequisite packages"
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

  log "Adding Caddy GPG key"
  curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

  log "Adding Caddy repository"
  curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    -o /etc/apt/sources.list.d/caddy-stable.list

  log "Updating package index after adding Caddy repo"
  apt-get update -y

  log "Installing Caddy package"
  apt-get install -y caddy
}

install_caddy_rhel() {
  log "Installing Caddy on an RHEL-based distribution"

  if command -v dnf >/dev/null 2>&1; then
    log "Adding Caddy repository"
    dnf -y install 'dnf-command(config-manager)'
    dnf config-manager --add-repo https://dl.cloudsmith.io/public/caddy/stable/rpm.repo

    log "Installing Caddy package"
    dnf -y install caddy
  else
    log "Adding Caddy repository"
    yum -y install yum-utils
    yum-config-manager --add-repo https://dl.cloudsmith.io/public/caddy/stable/rpm.repo

    log "Installing Caddy package"
    yum -y install caddy
  fi
}

install_caddy_arch() {
  log "Installing Caddy on an Arch-based distribution"

  log "Synchronizing package database"
  pacman -Sy --noconfirm

  log "Installing Caddy package"
  pacman -S --noconfirm caddy
}

install_caddy_opensuse() {
  log "Installing Caddy on openSUSE"

  log "Adding Caddy repository"
  zypper addrepo -f https://dl.cloudsmith.io/public/caddy/stable/rpm.repo caddy-stable || true

  log "Refreshing repositories"
  zypper refresh

  log "Installing Caddy package"
  zypper install -y caddy
}

case "$DISTRO_ID" in
  ubuntu|debian)
    install_caddy_debian
    ;;
  fedora|centos|rhel|rocky|almalinux)
    install_caddy_rhel
    ;;
  arch)
    install_caddy_arch
    ;;
  opensuse*|sles)
    install_caddy_opensuse
    ;;
  *)
    if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
      install_caddy_debian
    elif [[ "$DISTRO_LIKE" == *"rhel"* || "$DISTRO_LIKE" == *"fedora"* ]]; then
      install_caddy_rhel
    else
      error "Unsupported or unknown distribution: $DISTRO_ID"
    fi
    ;;
esac

log "Enabling Caddy service to start on boot"
systemctl enable caddy

log "Starting Caddy service"
systemctl start caddy

log "Verifying Caddy installation"
caddy version || error "Caddy installation verification failed"

log "Caddy installation completed successfully"
