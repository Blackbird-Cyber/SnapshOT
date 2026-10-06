---
title: Administration and capture
summary: The sudo model, the locked root account, packet capture without root, serial access and the root terminal.
---

SnapshOT is administered through `sudo`, captures packets without root, and
reaches serial consoles without root, by putting the operator in the right
groups rather than by handing out the root password. This page is the operator's
reference; the detail and the QA checks are in the repository's
`docs/offline-install.md`.

## sudo, and the locked root account

The installed account created in Calamares is in group `sudo` and administers
the system with its own password; **root stays locked** (there is no root
password). `sudo` asks for the user's password and then remembers it for **60
minutes**, shared across every terminal, so repeated administrative commands do
not prompt each time. That timeout is set by
`config/hooks/normal/0500-snapshot-sudo.hook.chroot` in
`/etc/sudoers.d/snapshot-operator` (`timestamp_timeout=60`,
`timestamp_type=global`).

In the **live** session the rules are looser by design: live-config gives the
live user passwordless `sudo` (and a matching polkit rule) at boot, outside the
squashfs that the installer copies, so the installed system never inherits
either.

## Packet capture without root

The live and installed users are in group `wireshark`, so **Wireshark, tshark
and termshark capture without `sudo`**. At build time
`config/hooks/normal/0600-snapshot-wireshark.hook.chroot` answers
wireshark-common's install-setuid question so that `/usr/bin/dumpcap` is
`root:wireshark`, mode `0754`, with the `cap_net_raw` and `cap_net_admin`
capabilities; members of group `wireshark` run capture through it.

**`tcpdump` still needs `sudo`.** Among the recon tools, `fping` carries the
`cap_net_raw` capability and so needs no `sudo`; `arp-scan`, `netdiscover` and
live `p0f` and `nmap` raw/UDP scans do need it.

To confirm on a running system:

```sh
# You are in the capture group
groups | tr ' ' '\n' | grep -x wireshark
# dumpcap has the capture capabilities
getcap /usr/bin/dumpcap
# tshark lists the interfaces without sudo
tshark -D
```

## Serial and other device access

The user is in group `dialout`, so **serial consoles and USB serial adapters are
reached without `sudo`** (`/dev/ttyUSB0`, `/dev/ttyS0`). The user is also in
`plugdev`, `kvm`, `netdev`, `audio`, `video`, `cdrom`, `floppy` and `dip`, so
removable media, QEMU/KVM and SDR hardware work without root. The live user has
the same groups except `sudo`.

## The root terminal

For the occasional task that genuinely needs root, the top panel and the Whisker
favourites carry a **Root Terminal** launcher (it is also under Usual
Applications > System). It runs `pkexec xfce4-terminal --disable-server`, so
polkit asks for authorisation and then opens a root shell. Prefer `sudo` for
single commands and keep the root terminal for the few operations that need a
sustained root session.

## Related pages

- [Live session and install](live-and-install.md): where these groups and the
  sudo rule are set up.
- [Quiet network defaults](network-defaults.md): why an interface is silent
  until the operator brings it up.
- [tshark](../tools/traffic/tshark.md): capture that uses the `wireshark` group.
- [Evidence handling](../lifecycle/evidence-handling.md): the case folder and
  hashing conventions capture feeds.
