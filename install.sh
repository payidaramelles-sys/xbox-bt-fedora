#!/usr/bin/env bash
# Install the udev rule that gives your user access to a Bluetooth Xbox controller's
# hidraw node, so Steam Input and rumble work.
set -euo pipefail

RULE_NAME="72-xbox-bluetooth-hidraw.rules"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/etc/udev/rules.d/${RULE_NAME}"

if [[ ${EUID} -ne 0 ]]; then
    echo "This script needs root. Re-running with sudo..." >&2
    exec sudo -- bash "$0" "$@"
fi

install -m 0644 "${SRC_DIR}/${RULE_NAME}" "${DEST}"
echo "Installed ${DEST}"

udevadm control --reload-rules
udevadm trigger --subsystem-match=hidraw
echo "Reloaded udev rules."

cat <<'EOF'

Next steps:
  1. Reconnect the controller (power it off, then hold the pair button until it reconnects).
  2. Check the node permissions:
       ls -l /sys/class/hidraw/    # or: udevadm info -q all -n /dev/hidrawN
     The hidraw node for 045e:xxxx should be group input, mode 0660.
  3. Launch Steam and check Settings -> Controller: "Xbox One Controller" should appear
     with Steam Input enabled.

If rumble still does not work, see the Troubleshooting section of README.md.
EOF
