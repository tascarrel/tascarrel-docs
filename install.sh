#!/bin/sh

set -eu

REPOSITORY=${TASCARREL_GITHUB_REPOSITORY:-tascarrel/tascarrel}
RELEASE=${TASCARREL_VERSION:-latest}
SOPS_VERSION=${TASCARREL_SOPS_VERSION:-3.13.3}
INSTALL_DIRECTORY=${HOME:-}/.local/bin
KVM_DEVICE=${TASCARREL_KVM_DEVICE:-/dev/kvm}
TEMPORARY_DIRECTORY=
STAGED_SERVER=
STAGED_CLIENT=

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'tascarrel installer: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [ -z "$STAGED_SERVER" ] || rm -f "$STAGED_SERVER"
  [ -z "$STAGED_CLIENT" ] || rm -f "$STAGED_CLIENT"
  if [ -n "$TEMPORARY_DIRECTORY" ]; then
    rm -rf "$TEMPORARY_DIRECTORY"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    require_command sudo
    sudo "$@"
  fi
}

download() {
  source_url=$1
  destination=$2
  if [ -n "${TASCARREL_RELEASE_BASE_URL:-}" ]; then
    curl -fsSL "$source_url" -o "$destination"
  else
    curl --proto '=https' --tlsv1.2 -fsSL "$source_url" -o "$destination"
  fi
}

download_https() {
  source_url=$1
  destination=$2
  curl --proto '=https' --tlsv1.2 -fsSL "$source_url" -o "$destination"
}

sha256_file() {
  file=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{ print $1 }'
  else
    fail "sha256sum or shasum is required"
  fi
}

detect_target() {
  system=$(uname -s)
  machine=$(uname -m)
  case "$system:$machine" in
    Darwin:arm64 | Darwin:aarch64)
      printf '%s\n' "aarch64-darwin"
      ;;
    Linux:x86_64 | Linux:amd64)
      printf '%s\n' "x86_64-linux"
      ;;
    Linux:aarch64 | Linux:arm64)
      printf '%s\n' "aarch64-linux"
      ;;
    *)
      fail "unsupported host: $system $machine"
      ;;
  esac
}

dependency_command() {
  environment_value=$1
  fallback=$2
  if [ -n "$environment_value" ]; then
    [ -x "$environment_value" ] || return 1
    printf '%s\n' "$environment_value"
  else
    command -v "$fallback"
  fi
}

qemu_available() {
  qemu=$(dependency_command "${TASCARREL_QEMU:-}" "$1") || return 1
  "$qemu" --version >/dev/null 2>&1
}

git_available() {
  git=$(dependency_command "${TASCARREL_GIT:-}" git) || return 1
  "$git" --version >/dev/null 2>&1
}

sops_available() {
  sops=$(dependency_command "${TASCARREL_SOPS:-}" sops) || return 1
  "$sops" --version >/dev/null 2>&1
}

qemu_command_for_target() {
  case "$1" in
    x86_64-linux)
      printf '%s\n' qemu-system-x86_64
      ;;
    aarch64-darwin | aarch64-linux)
      printf '%s\n' qemu-system-aarch64
      ;;
  esac
}

qemu_package_for_target() {
  package_manager=$1
  target=$2
  case "$package_manager:$target" in
    apt:x86_64-linux | dnf:x86_64-linux)
      printf '%s\n' qemu-system-x86
      ;;
    apt:aarch64-linux)
      printf '%s\n' qemu-system-arm
      ;;
    dnf:aarch64-linux)
      printf '%s\n' qemu-system-aarch64
      ;;
  esac
}

fail_kvm_access() {
  current_user=$(id -un)
  kvm_group=$(stat -c '%G' "$KVM_DEVICE" 2>/dev/null || printf '%s\n' kvm)
  current_groups=$(id -Gn)
  printf '%s\n' \
    "tascarrel installer: the current user cannot read and write $KVM_DEVICE" \
    "Device group: $kvm_group" >&2
  case " $current_groups " in
    *" $kvm_group "*)
      printf '%s\n' \
        "The user $current_user already belongs to $kvm_group." \
        "Check the permissions and udev rules for $KVM_DEVICE, then rerun the installer." >&2
      ;;
    *)
      printf '%s\n' \
        "Run: sudo usermod -aG '$kvm_group' '$current_user'" \
        "Then sign out and back in before rerunning the installer." >&2
      ;;
  esac
  exit 1
}

check_linux_preconditions() {
  if [ ! -e "$KVM_DEVICE" ]; then
    printf '%s\n' \
      "tascarrel installer: $KVM_DEVICE is not available" \
      "Enable hardware virtualization in the machine firmware, load the appropriate KVM kernel module, and rerun the installer." >&2
    exit 1
  fi
  if [ ! -r "$KVM_DEVICE" ] || [ ! -w "$KVM_DEVICE" ]; then
    fail_kvm_access
  fi
}

is_nixos() {
  [ -e /etc/NIXOS ] || command -v nixos-version >/dev/null 2>&1
}

missing_dependencies() {
  target=$1
  qemu_command=$(qemu_command_for_target "$target")
  missing=
  if ! qemu_available "$qemu_command"; then
    missing=QEMU
  fi
  if ! git_available; then
    missing="${missing}${missing:+, }Git"
  fi
  if ! sops_available; then
    missing="${missing}${missing:+, }SOPS"
  fi
  printf '%s\n' "$missing"
}

install_homebrew_dependencies() {
  target=$1
  command -v brew >/dev/null 2>&1 ||
    fail "Homebrew is required to install macOS dependencies: https://brew.sh/"
  set --
  qemu_command=$(qemu_command_for_target "$target")
  if ! qemu_available "$qemu_command"; then
    set -- "$@" qemu
  fi
  if ! git_available; then
    set -- "$@" git
  fi
  if ! sops_available; then
    set -- "$@" sops
  fi
  [ "$#" -eq 0 ] || brew install "$@"
}

install_pacman_dependencies() {
  target=$1
  set --
  qemu_command=$(qemu_command_for_target "$target")
  if ! qemu_available "$qemu_command"; then
    case "$target" in
      x86_64-linux)
        set -- "$@" qemu-system-x86 qemu-hw-usb-host
        ;;
      aarch64-linux)
        set -- "$@" qemu-system-aarch64 qemu-hw-usb-host
        ;;
    esac
  fi
  if ! git_available; then
    set -- "$@" git
  fi
  if ! sops_available; then
    set -- "$@" sops
  fi
  [ "$#" -eq 0 ] ||
    run_as_root pacman -S --needed --noconfirm "$@"
}

install_dnf_dependencies() {
  target=$1
  set --
  qemu_command=$(qemu_command_for_target "$target")
  if ! qemu_available "$qemu_command"; then
    set -- "$@" "$(qemu_package_for_target dnf "$target")"
  fi
  if ! git_available; then
    set -- "$@" git
  fi
  [ "$#" -eq 0 ] || run_as_root dnf install -y "$@"
  if ! sops_available; then
    case "$target" in
      x86_64-linux) sops_architecture=x86_64 ;;
      aarch64-linux) sops_architecture=aarch64 ;;
    esac
    run_as_root dnf install -y \
      "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-${SOPS_VERSION}-1.${sops_architecture}.rpm"
  fi
}

install_apt_dependencies() {
  target=$1
  set --
  qemu_command=$(qemu_command_for_target "$target")
  if ! qemu_available "$qemu_command"; then
    set -- "$@" "$(qemu_package_for_target apt "$target")"
  fi
  if ! git_available; then
    set -- "$@" git
  fi
  if [ "$#" -ne 0 ]; then
    run_as_root apt-get update
    run_as_root apt-get install -y "$@"
  fi
  if ! sops_available; then
    case "$target" in
      x86_64-linux) sops_architecture=amd64 ;;
      aarch64-linux) sops_architecture=arm64 ;;
    esac
    sops_package="$TEMPORARY_DIRECTORY/sops_${SOPS_VERSION}_${sops_architecture}.deb"
    download_https \
      "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_${sops_architecture}.deb" \
      "$sops_package"
    run_as_root apt-get install -y "$sops_package"
  fi
}

install_linux_dependencies() {
  target=$1
  if command -v pacman >/dev/null 2>&1; then
    install_pacman_dependencies "$target"
  elif command -v dnf >/dev/null 2>&1; then
    install_dnf_dependencies "$target"
  elif command -v apt-get >/dev/null 2>&1; then
    install_apt_dependencies "$target"
  else
    fail "could not find a supported package manager (pacman, dnf, or apt-get)"
  fi
}

ensure_host_dependencies() {
  target=$1
  case "$target" in
    aarch64-darwin)
      command -v launchctl >/dev/null 2>&1 ||
        fail "launchctl is unavailable; Tascarrel requires macOS LaunchAgents"
      ;;
    *-linux)
      if is_nixos; then
        fail "NixOS installations must use the Tascarrel Home Manager module: https://tascarrel.dev/docs/getting-started/installation/#nixos"
      fi
      command -v systemctl >/dev/null 2>&1 ||
        fail "systemctl is unavailable; Tascarrel requires systemd user services on Linux"
      command -v journalctl >/dev/null 2>&1 ||
        fail "journalctl is unavailable; Tascarrel requires the systemd journal on Linux"
      systemctl --user show-environment >/dev/null 2>&1 ||
        fail "the systemd user manager is unavailable; log in through a systemd user session and rerun the installer"
      require_command stat
      check_linux_preconditions
      ;;
  esac

  missing=$(missing_dependencies "$target")
  if [ -z "$missing" ]; then
    say "Host dependencies are already installed."
    return
  fi

  say "Installing missing host dependencies: $missing"
  case "$target" in
    aarch64-darwin)
      install_homebrew_dependencies "$target"
      ;;
    *-linux)
      install_linux_dependencies "$target"
      ;;
  esac

  missing=$(missing_dependencies "$target")
  [ -z "$missing" ] ||
    fail "host dependencies are still unavailable after installation: $missing"
}

case "${HOME:-}" in
  /*) ;;
  *) fail "HOME must name an absolute directory" ;;
esac
case "$KVM_DEVICE" in
  /*) ;;
  *) fail "TASCARREL_KVM_DEVICE must name an absolute path" ;;
esac
case "$REPOSITORY" in
  */*) ;;
  *) fail "invalid GitHub repository: $REPOSITORY" ;;
esac
case "$REPOSITORY" in
  *[!A-Za-z0-9._/-]*) fail "invalid GitHub repository: $REPOSITORY" ;;
esac
case "$RELEASE" in
  "" | *[!A-Za-z0-9._-]*) fail "invalid release: $RELEASE" ;;
esac
case "$SOPS_VERSION" in
  "" | *[!0-9.]* | .* | *.) fail "invalid SOPS version: $SOPS_VERSION" ;;
esac

require_command awk
require_command curl
require_command id
require_command install
require_command mktemp
require_command sed
require_command sort
require_command tar
require_command uname

TARGET=$(detect_target)
TEMPORARY_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/tascarrel-install.XXXXXX")
trap cleanup 0
trap 'exit 1' 1 2 15

ensure_host_dependencies "$TARGET"

ASSET="tascarrel-server-$TARGET.tar.gz"
if [ -n "${TASCARREL_RELEASE_BASE_URL:-}" ]; then
  RELEASE_BASE_URL=${TASCARREL_RELEASE_BASE_URL%/}
elif [ "$RELEASE" = "latest" ]; then
  RELEASE_BASE_URL="https://github.com/$REPOSITORY/releases/latest/download"
else
  RELEASE_BASE_URL="https://github.com/$REPOSITORY/releases/download/$RELEASE"
fi

ARCHIVE="$TEMPORARY_DIRECTORY/$ASSET"
CHECKSUM="$ARCHIVE.sha256"

say "Downloading Tascarrel for $TARGET..."
download "$RELEASE_BASE_URL/$ASSET" "$ARCHIVE"
download "$RELEASE_BASE_URL/$ASSET.sha256" "$CHECKSUM"

EXPECTED_SHA256=$(awk 'NR == 1 { print $1; exit }' "$CHECKSUM")
case "$EXPECTED_SHA256" in
  *[!0-9A-Fa-f]* | "") fail "release checksum is invalid" ;;
esac
[ "${#EXPECTED_SHA256}" -eq 64 ] || fail "release checksum is invalid"
ACTUAL_SHA256=$(sha256_file "$ARCHIVE")
[ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ] || fail "release checksum does not match"

ARCHIVE_CONTENTS=$(tar -tzf "$ARCHIVE" | sed 's|^\./||' | sort)
EXPECTED_CONTENTS=$(printf '%s\n' tascarrel tascarrelctl)
[ "$ARCHIVE_CONTENTS" = "$EXPECTED_CONTENTS" ] ||
  fail "release archive must contain only tascarrel and tascarrelctl"
tar -xzf "$ARCHIVE" -C "$TEMPORARY_DIRECTORY"
DOWNLOADED_SERVER="$TEMPORARY_DIRECTORY/tascarrel"
DOWNLOADED_CLIENT="$TEMPORARY_DIRECTORY/tascarrelctl"
[ -f "$DOWNLOADED_SERVER" ] && [ ! -L "$DOWNLOADED_SERVER" ] ||
  fail "release archive does not contain a regular tascarrel server"
[ -f "$DOWNLOADED_CLIENT" ] && [ ! -L "$DOWNLOADED_CLIENT" ] ||
  fail "release archive does not contain a regular tascarrelctl executable"

mkdir -p "$INSTALL_DIRECTORY"
STAGED_SERVER=$(mktemp "$INSTALL_DIRECTORY/.tascarrel.XXXXXX")
STAGED_CLIENT=$(mktemp "$INSTALL_DIRECTORY/.tascarrelctl.XXXXXX")
install -m 0755 "$DOWNLOADED_SERVER" "$STAGED_SERVER"
install -m 0755 "$DOWNLOADED_CLIENT" "$STAGED_CLIENT"
mv -f "$STAGED_SERVER" "$INSTALL_DIRECTORY/tascarrel"
STAGED_SERVER=
mv -f "$STAGED_CLIENT" "$INSTALL_DIRECTORY/tascarrelctl"
STAGED_CLIENT=

if [ -z "${TASCARREL_HOME:-}" ]; then
  TASCARREL_HOME="$HOME/.tascarrel"
fi
case "$TASCARREL_HOME" in
  /*) ;;
  *) fail "TASCARREL_HOME must name an absolute directory" ;;
esac
TASCARREL_INSTALL_BIN_DIR=$INSTALL_DIRECTORY
export TASCARREL_HOME TASCARREL_INSTALL_BIN_DIR

say "Installing the Tascarrel service..."
"$INSTALL_DIRECTORY/tascarrelctl" install --server "$INSTALL_DIRECTORY/tascarrel"
if "$INSTALL_DIRECTORY/tascarrelctl" daemon status >/dev/null 2>&1; then
  say "Restarting the Tascarrel service..."
  "$INSTALL_DIRECTORY/tascarrelctl" daemon restart
else
  say "Starting the Tascarrel service..."
  "$INSTALL_DIRECTORY/tascarrelctl" daemon start
fi
"$INSTALL_DIRECTORY/tascarrelctl" daemon status >/dev/null 2>&1 ||
  fail "the Tascarrel service is not active; inspect it with $INSTALL_DIRECTORY/tascarrelctl daemon logs"
say "Tascarrel is running at http://tascarrel.localhost:8272"
