#!/bin/sh

set -eu

REPOSITORY=${TASCARREL_GITHUB_REPOSITORY:-tascarrel/tascarrel}
RELEASE=${TASCARREL_VERSION:-latest}
INSTALL_DIRECTORY=${HOME:-}/.local/bin
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

download() {
  source_url=$1
  destination=$2
  if [ -n "${TASCARREL_RELEASE_BASE_URL:-}" ]; then
    curl -fsSL "$source_url" -o "$destination"
  else
    curl --proto '=https' --tlsv1.2 -fsSL "$source_url" -o "$destination"
  fi
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

case "${HOME:-}" in
  /*) ;;
  *) fail "HOME must name an absolute directory" ;;
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

require_command awk
require_command curl
require_command install
require_command mktemp
require_command sed
require_command sort
require_command tar
require_command uname

TARGET=$(detect_target)
ASSET="tascarrel-server-$TARGET.tar.gz"
if [ -n "${TASCARREL_RELEASE_BASE_URL:-}" ]; then
  RELEASE_BASE_URL=${TASCARREL_RELEASE_BASE_URL%/}
elif [ "$RELEASE" = "latest" ]; then
  RELEASE_BASE_URL="https://github.com/$REPOSITORY/releases/latest/download"
else
  RELEASE_BASE_URL="https://github.com/$REPOSITORY/releases/download/$RELEASE"
fi

TEMPORARY_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/tascarrel-install.XXXXXX")
trap cleanup 0
trap 'exit 1' 1 2 15

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
