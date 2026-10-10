---
title: Quiet network defaults
summary: What SnapshOT masks and disables so the laptop never announces itself or sends unsolicited traffic onto a plant network.
---

A plant network is quiet and watched. A laptop that advertises itself, asks for
an address, syncs its clock or probes for internet access is noise at best and, on
a fragile segment, a disturbance. So SnapshOT ships **quiet on the wire**: the
operator brings an interface up deliberately, and until then the machine sends
nothing. The facts here come from
`config/hooks/normal/0300-snapshot-network-defaults.hook.chroot` and
`config/includes.chroot/etc/sysctl.d/99-snapshot-quiet.conf`.

## Masked services

These chatty or automatic services are masked, so they do not start even if
something asks for them:

- **avahi-daemon** (service and socket): no mDNS/DNS-SD advertising or querying.
  This is why [avahi-browse](../tools/recon/avahi-browse.md) shows nothing until
  the daemon is unmasked and started by hand, and why the menu's mDNS entry is
  [mDNS listen (passive)](../tools/recon/mdns-listen.md), which captures the
  announcements other hosts send without the daemon.
- **systemd-timesyncd**: no automatic NTP to a time server.

ModemManager is not masked because it is not on the image at all: nothing pulls
it in with recommended packages off, so nothing probes the serial and USB
adapters used for console work as modems.

## Name resolution

systemd-resolved is configured with **LLMNR off and multicast DNS off**
(`/etc/systemd/resolved.conf.d/snapshot-quiet.conf`), so the laptop does not emit
LLMNR or mDNS name queries that would reveal it on the segment.

## NetworkManager

NetworkManager (`/etc/NetworkManager/conf.d/snapshot-quiet.conf`) is set so that:

- it creates **no automatic wired connection profile** (`no-auto-default=*`), so
  plugging in a cable does not bring an interface up and start DHCP on its own;
  the operator connects deliberately;
- it runs **no connectivity check** (`connectivity.enabled=false`), so it never
  reaches out to test for internet access.

## Wi-Fi

NetworkManager joins Wi-Fi networks, and wired networks that use 802.1X, through
wpa_supplicant. The image ships with NetworkManager's
**Wi-Fi switch off** (`WirelessEnabled=false` in
`/var/lib/NetworkManager/NetworkManager.state`, written at build time), on the
live system and on every installed system:

- While the switch is off, NetworkManager leaves every Wi-Fi adapter
  `unavailable`: it does not scan, so the laptop sends no probe requests and
  joins nothing when it is carried onto a site.
- Turn Wi-Fi on deliberately, from the network icon in the panel (right-click,
  **Enable Wi-Fi**) or with `nmcli radio wifi on`, and off again with
  `nmcli radio wifi off`. An installed system remembers the choice across
  reboots; the live system starts with the switch off at every boot.
- The switch is also a soft block: switching Wi-Fi off blocks every Wi-Fi radio
  through rfkill and switching it on unblocks them (`sudo rfkill` lists the
  state). A monitor-mode survey therefore starts with an `rfkill unblock` of the
  survey adapter alone; the [airodump-ng](../tools/wireless/airodump-ng.md) page
  has the steps.
- Once the switch is on, NetworkManager scans in the background with every
  adapter it manages, and each scan sends probe requests. It uses a random MAC
  address for them (NetworkManager's default, `wifi.scan-rand-mac-address`); a
  connection uses the adapter's own address unless the profile sets another.

## IPv6

IPv6 stateless autoconfiguration and router-advertisement acceptance are turned
off (`net.ipv6.conf.all.autoconf=0`, `net.ipv6.conf.default.autoconf=0`,
`net.ipv6.conf.all.accept_ra=0`, `net.ipv6.conf.default.accept_ra=0`), so the
machine does not configure IPv6 addresses or react to router advertisements by
default. An operator can re-enable these when a task requires IPv6.

## The browser

Firefox ESR is held quiet by its own enterprise policy, which stops it making any
connection on its own; that is covered on the [browser](browser.md) page. The
repository's `scripts/check-firefox-quiet.sh` captures no packet while Firefox
shows the wiki.

## What this means on site

Connecting to a control segment is a deliberate act. The operator chooses the
interface, chooses active or passive, and announces active work to the site's
monitoring. The quiet defaults make listening the safe default and transmitting
a decision, which is the posture the [wire classes](../lifecycle/wire-classes.md)
and the passive-first doctrine assume.

## Related pages

- [Administration and capture](admin-and-capture.md): bringing interfaces up and
  capturing without root.
- [Browser](browser.md): the Firefox lockdown that keeps the browser silent.
- [Wire classes](../lifecycle/wire-classes.md): passive, active and writes, and
  why passive is the default.
