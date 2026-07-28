#!/bin/sh

set -eu

REPOSITORY_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/tascarrel-installer-test.XXXXXX")
MOCK_BIN="$TEST_ROOT/bin"
RELEASE_DIRECTORY="$TEST_ROOT/release"
PAYLOAD_DIRECTORY="$TEST_ROOT/payload"
TEST_HOME="$TEST_ROOT/home"
INSTALLER_TEST_LOG="$TEST_ROOT/commands.log"
INSTALLER_TEST_SERVICE_STATE="$TEST_ROOT/service-running"
KVM_DEVICE="$TEST_ROOT/kvm"

cleanup() {
  rm -rf "$TEST_ROOT"
}

write_executable() {
  destination=$1
  shift
  printf '%s\n' "$@" >"$destination"
  chmod +x "$destination"
}

assert_contains() {
  file=$1
  expected=$2
  if ! grep -F "$expected" "$file" >/dev/null; then
    printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
    exit 1
  fi
}

trap cleanup 0
mkdir -p "$MOCK_BIN" "$RELEASE_DIRECTORY" "$PAYLOAD_DIRECTORY" "$TEST_HOME"
: >"$INSTALLER_TEST_LOG"
: >"$KVM_DEVICE"

# The generated mock scripts expand these variables when the installer runs them.
# shellcheck disable=SC2016
write_executable "$MOCK_BIN/id" \
  '#!/bin/sh' \
  'case "${1:-}" in' \
  '  -u) printf "%s\n" 1000 ;;' \
  '  -un) printf "%s\n" tester ;;' \
  '  -Gn) printf "%s\n" tester ;;' \
  '  *) exit 1 ;;' \
  'esac'

# shellcheck disable=SC2016
write_executable "$MOCK_BIN/sudo" \
  '#!/bin/sh' \
  'printf "sudo" >>"$INSTALLER_TEST_LOG"' \
  'printf " %s" "$@" >>"$INSTALLER_TEST_LOG"' \
  'printf "\n" >>"$INSTALLER_TEST_LOG"' \
  'exec "$@"'

write_executable "$MOCK_BIN/systemctl" '#!/bin/sh' 'exit 0'
write_executable "$MOCK_BIN/journalctl" '#!/bin/sh' 'exit 0'

# shellcheck disable=SC2016
write_executable "$MOCK_BIN/apt-get" \
  '#!/bin/sh' \
  'printf "apt-get" >>"$INSTALLER_TEST_LOG"' \
  'printf " %s" "$@" >>"$INSTALLER_TEST_LOG"' \
  'printf "\n" >>"$INSTALLER_TEST_LOG"' \
  'case " $* " in' \
  '  *" qemu-system-x86 "*)' \
  '    printf "#!/bin/sh\nprintf \"QEMU emulator version 1\\n\"\n" >"$MOCK_BIN/qemu-system-x86_64"' \
  '    chmod +x "$MOCK_BIN/qemu-system-x86_64"' \
  '    ;;' \
  '  *"sops_"*".deb "*)' \
  '    printf "#!/bin/sh\nprintf \"sops 1\\n\"\n" >"$MOCK_BIN/sops"' \
  '    chmod +x "$MOCK_BIN/sops"' \
  '    ;;' \
  'esac'

# shellcheck disable=SC2016
write_executable "$MOCK_BIN/curl" \
  '#!/bin/sh' \
  'source_url=' \
  'destination=' \
  'while [ "$#" -gt 0 ]; do' \
  '  case "$1" in' \
  '    -o)' \
  '      destination=$2' \
  '      shift 2' \
  '      ;;' \
  '    --proto)' \
  '      shift 2' \
  '      ;;' \
  '    -*) shift ;;' \
  '    *)' \
  '      source_url=$1' \
  '      shift' \
  '      ;;' \
  '  esac' \
  'done' \
  'case "$source_url" in' \
  '  file://*) cp "${source_url#file://}" "$destination" ;;' \
  '  https://github.com/getsops/sops/*) : >"$destination" ;;' \
  '  *) printf "Unexpected URL: %s\n" "$source_url" >&2; exit 1 ;;' \
  'esac'

write_executable "$PAYLOAD_DIRECTORY/tascarrel" '#!/bin/sh' 'exit 0'
# shellcheck disable=SC2016
write_executable "$PAYLOAD_DIRECTORY/tascarrelctl" \
  '#!/bin/sh' \
  'case "$1 ${2:-}" in' \
  '  "install --server")' \
  '    printf "%s\n" install >>"$INSTALLER_TEST_LOG"' \
  '    ;;' \
  '  "daemon status")' \
  '    [ -e "$INSTALLER_TEST_SERVICE_STATE" ]' \
  '    ;;' \
  '  "daemon start")' \
  '    printf "%s\n" start >>"$INSTALLER_TEST_LOG"' \
  '    : >"$INSTALLER_TEST_SERVICE_STATE"' \
  '    ;;' \
  '  "daemon restart")' \
  '    printf "%s\n" restart >>"$INSTALLER_TEST_LOG"' \
  '    ;;' \
  '  *) exit 1 ;;' \
  'esac'

archive="$RELEASE_DIRECTORY/tascarrel-server-x86_64-linux.tar.gz"
tar -czf "$archive" -C "$PAYLOAD_DIRECTORY" tascarrel tascarrelctl
sha256sum "$archive" >"$archive.sha256"

export INSTALLER_TEST_LOG INSTALLER_TEST_SERVICE_STATE MOCK_BIN
export PATH="$MOCK_BIN:/usr/bin:/bin"
export HOME="$TEST_HOME"
export TASCARREL_KVM_DEVICE="$KVM_DEVICE"
export TASCARREL_RELEASE_BASE_URL="file://$RELEASE_DIRECTORY"

first_output="$TEST_ROOT/first-output.log"
sh "$REPOSITORY_ROOT/install.sh" >"$first_output" 2>&1
assert_contains "$INSTALLER_TEST_LOG" "sudo apt-get update"
assert_contains "$INSTALLER_TEST_LOG" "sudo apt-get install -y qemu-system-x86"
assert_contains "$INSTALLER_TEST_LOG" "sops_3.13.3_amd64.deb"
assert_contains "$INSTALLER_TEST_LOG" "install"
assert_contains "$INSTALLER_TEST_LOG" "start"
assert_contains "$first_output" "Tascarrel is running at http://127.0.0.1:8272"
test -x "$TEST_HOME/.local/bin/tascarrel"
test -x "$TEST_HOME/.local/bin/tascarrelctl"

second_output="$TEST_ROOT/second-output.log"
sh "$REPOSITORY_ROOT/install.sh" >"$second_output" 2>&1
assert_contains "$second_output" "Host dependencies are already installed."
assert_contains "$INSTALLER_TEST_LOG" "restart"

rm -f "$MOCK_BIN/qemu-system-x86_64" "$MOCK_BIN/sops"
HOME="$TEST_ROOT/pacman-home"
INSTALLER_TEST_SERVICE_STATE="$TEST_ROOT/pacman-service-running"
export HOME INSTALLER_TEST_SERVICE_STATE
mkdir -p "$HOME"
# shellcheck disable=SC2016
write_executable "$MOCK_BIN/pacman" \
  '#!/bin/sh' \
  'printf "pacman" >>"$INSTALLER_TEST_LOG"' \
  'printf " %s" "$@" >>"$INSTALLER_TEST_LOG"' \
  'printf "\n" >>"$INSTALLER_TEST_LOG"' \
  'printf "#!/bin/sh\nprintf \"QEMU emulator version 1\\n\"\n" >"$MOCK_BIN/qemu-system-x86_64"' \
  'printf "#!/bin/sh\nprintf \"sops 1\\n\"\n" >"$MOCK_BIN/sops"' \
  'chmod +x "$MOCK_BIN/qemu-system-x86_64" "$MOCK_BIN/sops"'
sh "$REPOSITORY_ROOT/install.sh" >"$TEST_ROOT/pacman-output.log" 2>&1
assert_contains "$INSTALLER_TEST_LOG" \
  "pacman -S --needed --noconfirm qemu-system-x86 qemu-hw-usb-host sops"

rm -f "$MOCK_BIN/pacman" "$MOCK_BIN/qemu-system-x86_64" "$MOCK_BIN/sops"
HOME="$TEST_ROOT/dnf-home"
INSTALLER_TEST_SERVICE_STATE="$TEST_ROOT/dnf-service-running"
export HOME INSTALLER_TEST_SERVICE_STATE
mkdir -p "$HOME"
# shellcheck disable=SC2016
write_executable "$MOCK_BIN/dnf" \
  '#!/bin/sh' \
  'printf "dnf" >>"$INSTALLER_TEST_LOG"' \
  'printf " %s" "$@" >>"$INSTALLER_TEST_LOG"' \
  'printf "\n" >>"$INSTALLER_TEST_LOG"' \
  'case " $* " in' \
  '  *" qemu-system-x86 "*)' \
  '    printf "#!/bin/sh\nprintf \"QEMU emulator version 1\\n\"\n" >"$MOCK_BIN/qemu-system-x86_64"' \
  '    chmod +x "$MOCK_BIN/qemu-system-x86_64"' \
  '    ;;' \
  '  *"sops-3.13.3-1.x86_64.rpm "*)' \
  '    printf "#!/bin/sh\nprintf \"sops 1\\n\"\n" >"$MOCK_BIN/sops"' \
  '    chmod +x "$MOCK_BIN/sops"' \
  '    ;;' \
  'esac'
sh "$REPOSITORY_ROOT/install.sh" >"$TEST_ROOT/dnf-output.log" 2>&1
assert_contains "$INSTALLER_TEST_LOG" "dnf install -y qemu-system-x86"
assert_contains "$INSTALLER_TEST_LOG" \
  "sops/releases/download/v3.13.3/sops-3.13.3-1.x86_64.rpm"

rm -f "$MOCK_BIN/dnf" "$MOCK_BIN/qemu-system-x86_64" "$MOCK_BIN/sops"
HOME="$TEST_ROOT/homebrew-home"
INSTALLER_TEST_SERVICE_STATE="$TEST_ROOT/homebrew-service-running"
export HOME INSTALLER_TEST_SERVICE_STATE
mkdir -p "$HOME"
darwin_archive="$RELEASE_DIRECTORY/tascarrel-server-aarch64-darwin.tar.gz"
cp "$archive" "$darwin_archive"
sha256sum "$darwin_archive" >"$darwin_archive.sha256"
# shellcheck disable=SC2016
write_executable "$MOCK_BIN/uname" \
  '#!/bin/sh' \
  'case "$1" in' \
  '  -s) printf "%s\n" Darwin ;;' \
  '  -m) printf "%s\n" arm64 ;;' \
  'esac'
write_executable "$MOCK_BIN/launchctl" '#!/bin/sh' 'exit 0'
# shellcheck disable=SC2016
write_executable "$MOCK_BIN/brew" \
  '#!/bin/sh' \
  'printf "brew" >>"$INSTALLER_TEST_LOG"' \
  'printf " %s" "$@" >>"$INSTALLER_TEST_LOG"' \
  'printf "\n" >>"$INSTALLER_TEST_LOG"' \
  'printf "#!/bin/sh\nprintf \"QEMU emulator version 1\\n\"\n" >"$MOCK_BIN/qemu-system-aarch64"' \
  'printf "#!/bin/sh\nprintf \"sops 1\\n\"\n" >"$MOCK_BIN/sops"' \
  'chmod +x "$MOCK_BIN/qemu-system-aarch64" "$MOCK_BIN/sops"'
sh "$REPOSITORY_ROOT/install.sh" >"$TEST_ROOT/homebrew-output.log" 2>&1
assert_contains "$INSTALLER_TEST_LOG" "brew install qemu sops"

rm -f "$MOCK_BIN/brew" "$MOCK_BIN/launchctl" "$MOCK_BIN/uname"
rm -f "$MOCK_BIN/qemu-system-aarch64" "$MOCK_BIN/sops"
HOME="$TEST_HOME"
INSTALLER_TEST_SERVICE_STATE="$TEST_ROOT/service-running"
export HOME INSTALLER_TEST_SERVICE_STATE

missing_kvm_output="$TEST_ROOT/missing-kvm-output.log"
if TASCARREL_KVM_DEVICE="$TEST_ROOT/missing-kvm" \
  sh "$REPOSITORY_ROOT/install.sh" >"$missing_kvm_output" 2>&1; then
  printf 'Installer accepted a missing KVM device\n' >&2
  exit 1
fi
assert_contains "$missing_kvm_output" "$TEST_ROOT/missing-kvm is not available"
assert_contains "$missing_kvm_output" "Enable hardware virtualization"

chmod 000 "$KVM_DEVICE"
inaccessible_kvm_output="$TEST_ROOT/inaccessible-kvm-output.log"
if sh "$REPOSITORY_ROOT/install.sh" >"$inaccessible_kvm_output" 2>&1; then
  printf 'Installer accepted an inaccessible KVM device\n' >&2
  exit 1
fi
assert_contains "$inaccessible_kvm_output" "cannot read and write $KVM_DEVICE"
assert_contains "$inaccessible_kvm_output" "sudo usermod -aG"
assert_contains "$inaccessible_kvm_output" "sign out and back in"

write_executable "$MOCK_BIN/nixos-version" '#!/bin/sh' 'printf "%s\n" 1'
nixos_output="$TEST_ROOT/nixos-output.log"
if sh "$REPOSITORY_ROOT/install.sh" >"$nixos_output" 2>&1; then
  printf 'Installer accepted NixOS\n' >&2
  exit 1
fi
assert_contains "$nixos_output" "must use the Tascarrel Home Manager module"
assert_contains "$nixos_output" "/installation/#nixos"

printf 'Installer end-to-end checks passed.\n'
