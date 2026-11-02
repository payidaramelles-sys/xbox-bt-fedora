# xbox-bt-fedora

Fix Steam Input and rumble for a **Bluetooth-connected Xbox controller on Fedora** (and most other Linux distributions) with a single udev rule.

## The problem

Pair an Xbox Wireless Controller over Bluetooth and everything looks fine: the kernel binds `hid-microsoft`, `/dev/input/js0` and an event node appear, buttons and sticks work. But the `hidraw` node created for the Bluetooth device is owned by `root` with mode `0600`:

```
crw-------. 1 root root 241, 0 Nov  2 21:40 /dev/hidraw3
```

Steam and SDL talk to the controller through HIDAPI on that `hidraw` node — for rumble, for Steam Input's full feature set (paddles, share button, trigger motors). With root-only permissions those features silently fall back or fail, while the basic gamepad still works, which makes it look like a Steam bug.

USB-connected controllers are usually fine, because the `xpad`/`hid-microsoft` USB path already ships a rule granting `uaccess`. The Bluetooth path does not.

## The fix

One rule:

```
SUBSYSTEM=="hidraw", KERNELS=="*0005:045E:*", TAG+="uaccess", MODE="0660"
```

- `0005` is the Bluetooth bus, `045E` is Microsoft (Xbox) as USB vendor.
- `TAG+="uaccess"` gives the user of the active seat an ACL on the node.
- `MODE="0660"` additionally makes it group-readable for the `input` group.

## Install

```bash
git clone https://github.com/<you>/xbox-bt-fedora.git
cd xbox-bt-fedora
sudo ./install.sh
```

Then power the controller off and on again (or re-pair it) so udev recreates the node.

Manual install, if you prefer:

```bash
sudo install -m 0644 72-xbox-bluetooth-hidraw.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=hidraw
```

## Verify

```bash
# Find the controller's hidraw node
for h in /sys/class/hidraw/hidraw*; do
  udevadm info -q property -p "$h" | grep -q 'HID_ID=0005:0000045E' && echo "$h"
done

# Permissions should now be rw for your user (ACL) and group input
ls -l /dev/hidrawN
getfacl /dev/hidrawN 2>/dev/null | grep "user:$(id -un)"
```

Then open Steam → **Settings → Controller**. The controller should be listed as *Xbox One Controller* with **Steam Input** enabled, and rumble should work in the controller test screen.

## Troubleshooting

**No hidraw node at all.** The kernel did not bind the HID driver. Check `dmesg | grep -i -E 'xbox|microsoft|hid'`. If the controller paired but no `hidraw` node appeared, remove the pairing and pair again — BlueZ sometimes needs a fresh bond after a kernel update.

**Rule installed, still root-only.** Check the rule's filename number. `TAG+="uaccess"` is applied by `73-seat-late.rules`, so a rule numbered **73 or higher cannot use it**. Rename to `72-…` (this repo already does).

**Rumble still missing but Steam Input sees the controller.** Your controller may need `xpadneo`/`xone`. As of Fedora 44 neither is packaged in the official repositories; they must be built from source with `akmods` (Secure Boot must be off or the module signed).

**Controller disconnects under load (Wi-Fi/BT coexistence).** Unrelated to permissions; usually 2.4 GHz interference. Try a USB Bluetooth dongle or move the antenna.

## Tested on

| | |
|---|---|
| Distro | Fedora 44 |
| Kernel | 7.2.13-200.fc44.x86_64 |
| Controller | Xbox Wireless Controller, `045e:0b13` (Bluetooth) |
| Steam | Steam Input, `xboxone` config set |

## License

MIT
