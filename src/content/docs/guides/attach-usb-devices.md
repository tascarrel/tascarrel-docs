---
order: 8
description: Forward a Linux host USB device to a running workspace.
---

# Attach USB Devices

USB forwarding is available only on Linux hosts. Enable it and restart the
workspace:

```toml
[features]
usb = true
```

Select the USB control in the running workspace and choose a device. Tascarrel
reports missing usbfs permissions or ownership by another workspace. Attaching
does not start a stopped workspace, and one physical device can belong to only
one workspace at a time.

Every pod in the workspace can see the forwarded kernel and raw USB device
nodes. Hardware may still allow only one effective user, so treat the device as
part of the workspace trust boundary.

The attachment ends when you detach it, stop the workspace, or unplug the
device. Reconnecting requires another explicit attachment.
