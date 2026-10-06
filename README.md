<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="branding/exports/snapshot-lockup-red-transparent.png">
    <img src="branding/exports/snapshot-lockup-black-transparent.png" width="520" alt="SnapshOT">
  </picture>
</p>

<p align="center">
  An offline, reproducible Debian image for OT/ICS assessment and client engagements, by Blackbird Cyber.
</p>

<!-- Static badges: the repository is private, so shields.io cannot read its
     releases. Once it is public, the release badge can become
     https://img.shields.io/github/v/release/Blackbird-Cyber/SnapshOT?include_prereleases
     scripts/release.sh rewrites the release badge, the pin badge and the download links. -->
<p align="center">
  <img src="https://img.shields.io/badge/Debian-13_trixie-A81D33?logo=debian&amp;logoColor=white" alt="Debian 13 trixie">
  <img src="https://img.shields.io/badge/Calamares-3.3-2A2C2F" alt="Calamares 3.3">
  <img src="https://img.shields.io/badge/Xfce-4.20-2A2C2F?logo=xfce&amp;logoColor=white" alt="Xfce 4.20">
  <img src="https://img.shields.io/badge/encryption-LUKS2-2A2C2F" alt="LUKS2">
  <img src="https://img.shields.io/badge/snapshot_pin-2026--09--01-2A2C2F" alt="snapshot.debian.org pin">
  <img src="https://img.shields.io/badge/arch-amd64_%7C_arm64-2A2C2F" alt="amd64 | arm64">
  <a href="https://github.com/Blackbird-Cyber/SnapshOT/releases/tag/v0.1.0"><img src="https://img.shields.io/badge/pre--release-v0.1.0-F1000E" alt="release"></a>
</p>

SnapshOT is a Debian 13 (trixie) live image built with `live-build`, in the way Kali
is built, but pinned to a single snapshot.debian.org timestamp so that every build of a
release resolves the same packages. It boots to an Xfce desktop with OT/ICS discovery,
traffic, protocol, firmware, radio, forensics and reporting tools, and installs to disk with LUKS2
encryption without any network. Between clients the laptop is wiped and re-imaged.

## Download

<p align="center">
  <a href="https://github.com/Blackbird-Cyber/SnapshOT/releases/download/v0.1.0/snapshot-amd64.hybrid.iso"><img src="https://img.shields.io/badge/Download-amd64_ISO-F1000E?style=for-the-badge&amp;logo=debian&amp;logoColor=white" alt="Download the amd64 ISO"></a>
  <a href="https://github.com/Blackbird-Cyber/SnapshOT/releases/download/v0.1.0/snapshot-arm64.hybrid.iso"><img src="https://img.shields.io/badge/Download-arm64_ISO-F1000E?style=for-the-badge&amp;logo=linux&amp;logoColor=white" alt="Download the arm64 ISO"></a>
</p>

<!-- release-table:start -->
**v0.1.0** (pre-release): Debian trixie pinned to snapshot.debian.org `20260901T022952Z`.

| Image | Hardware | Boot | Size | SHA-256 |
|---|---|---|---|---|
| [snapshot-amd64.hybrid.iso](https://github.com/Blackbird-Cyber/SnapshOT/releases/download/v0.1.0/snapshot-amd64.hybrid.iso) | x86-64 laptops and VMs | BIOS + UEFI | 1.61 GiB | `35d5da86cf245e90416014062bf83542e4a523ac64578016cac5a9ea21fc7c14` |
| [snapshot-arm64.hybrid.iso](https://github.com/Blackbird-Cyber/SnapshOT/releases/download/v0.1.0/snapshot-arm64.hybrid.iso) | arm64 VMs (UTM, Parallels, VMware Fusion on Apple Silicon) and UEFI arm64 hardware | UEFI | 1.63 GiB | `66c81e0fb7f4ebf11a09ea749cb74581c692c39d63cc171b7aa3f7041f15f244` |

Checksums: [`SHA256SUMS`](https://github.com/Blackbird-Cyber/SnapshOT/releases/download/v0.1.0/SHA256SUMS)
<!-- release-table:end -->

All releases are on the [releases page](https://github.com/Blackbird-Cyber/SnapshOT/releases).
Read [Status and known issues](#status-and-known-issues) before installing v0.1.0.

### Verify the download

Compare the hash with the table or with `SHA256SUMS` from the same release:

```sh
sha256sum -c --ignore-missing SHA256SUMS            # Linux, next to the downloaded ISO
shasum -a 256 snapshot-amd64.hybrid.iso             # macOS
certutil -hashfile snapshot-amd64.hybrid.iso SHA256 # Windows
```

GitHub limits a release asset to 2 GiB, and the amd64 image with the vendor layer is
larger, so it is published in parts. Any image over the limit is published as
`snapshot-<arch>.hybrid.iso.part-aa`, `.part-ab`, ...; join the parts in order, then
verify the joined file (`SHA256SUMS` always lists the whole ISO):

```sh
cat snapshot-amd64.hybrid.iso.part-* > snapshot-amd64.hybrid.iso
```

On Windows: `copy /b snapshot-amd64.hybrid.iso.part-aa + snapshot-amd64.hybrid.iso.part-ab snapshot-amd64.hybrid.iso`.

### Write to USB or run in a VM

- **Linux:** `sudo dd if=snapshot-amd64.hybrid.iso of=/dev/sdX bs=4M conv=fsync status=progress`
  (`/dev/sdX` is the whole stick, not a partition; everything on it is lost).
- **macOS:** `diskutil unmountDisk /dev/diskN`, then
  `sudo dd if=snapshot-amd64.hybrid.iso of=/dev/rdiskN bs=4m`.
- **balenaEtcher** works as is. **Rufus**: when it asks, choose **DD Image** mode, not
  ISO mode. **Ventoy**: copy the ISO onto the Ventoy stick.
- **VMs:** enable UEFI firmware, give the VM 4 GB of RAM (8 GB or more to run Autopsy)
  and a 20 GB disk. Use the
  arm64 image for UTM, Parallels or VMware Fusion on Apple Silicon; it does not boot an
  Apple Silicon Mac directly. To test the offline install, remove the VM's network
  adapter.

## amd64 and arm64 images

Both images come from the same tree and pin. They differ only where the hardware
or upstream software requires it:

| | amd64 | arm64 |
|---|---|---|
| Use it on | x86-64 laptops, desktops and VMs (VMware, VirtualBox, Hyper-V, QEMU/KVM) | arm64 VMs on Apple Silicon (UTM, Parallels, VMware Fusion) and UEFI arm64 hardware; it does not boot an Apple Silicon Mac directly |
| Live ISO boots with | BIOS or UEFI | UEFI only |
| Installed bootloader | GRUB for BIOS (`grub-pc-bin`) or UEFI (`grub-efi-amd64`), matching how the live system started; EFI system partition only on UEFI installs | GRUB for UEFI (`grub-efi-arm64`) |
| Kernel | Debian `linux-image-amd64` | Debian `linux-image-arm64` |
| CPU microcode | `intel-microcode`, `amd64-microcode` | none (x86-only packages) |
| OPC UA GUI client (*opcua-client*) | yes | no: PyQt5 publishes no Linux aarch64 wheels, and the vendor layer installs wheels only |
| *Autopsy* 4.23.1 | yes, with its own Temurin 21 JRE, a `libtsk_jni` built from The Sleuth Kit 4.15.0, and the GStreamer plugins and `lsof` it uses | no: its release ships JavaFX and other native libraries for x86-64 Linux only, and upstream does not support arm64 Linux |
| The Sleuth Kit CLI, TestDisk/PhotoRec | yes | yes |
| Image size with the vendor layer (approx.) | about 2.6 GiB, published in two parts | about 1.7 GiB |

Everything else is the same on both: the Debian package lists, the other vendored tools
(ICS Python libraries and OPC UA command-line tools, plcscan, Redpoint NSE), the desktop,
the installer and the network defaults. Launchers for amd64-only tools ship on both
images and are hidden on arm64.

## Live session and install

The live session logs in automatically as user `snapshot`; the password `live` is only
needed to unlock the screen (`sudo` and the installer do not ask for it in the live
session).

**Install SnapshOT** on the desktop starts Calamares, which copies the live system to
disk and uses no network. Choose **Erase disk** and **Encrypt system**:

- Layout: EFI system partition (UEFI), a 1 GiB unencrypted `/boot`, and the root
  filesystem (ext4 by default) inside LUKS2. Swap is off by default; if chosen, it is
  a file inside the encrypted root (no hibernation).
- First boot: the SnapshOT GRUB menu, then the boot splash asks for the disk passphrase
  once, then the LightDM login.
- Administration: the account created in the installer is in group `sudo`, with its
  password; root stays locked. The password is remembered for 60 minutes across
  terminals.
- Packet capture: the live and installed users are in group `wireshark`, so
  Wireshark, tshark and termshark capture without `sudo`; `tcpdump` still needs it.
- The installer removes the live-session packages (`live-boot`, `live-config`,
  `user-setup`) and Calamares itself; the installed desktop has no Install icon.

The details, the module configuration and the QA checklist are in
[docs/offline-install.md](docs/offline-install.md). The layout and the removals above
come with the next image; see [Status and known issues](#status-and-known-issues).

## What's inside

- **Base:** Debian 13 trixie, Linux 6.12, Xfce 4.20 with LightDM, NetworkManager.
  Installed with no recommended packages. Shell tools: `git`, `vim`, `nano`, `tmux`,
  `htop`, `jq`, `curl`, `wget`, `rsync`, `tree`, `p7zip-full`, `python3` with `pip`,
  `venv` and `pipx`.
- **Firmware:** `firmware-linux`, `firmware-linux-nonfree`, `firmware-iwlwifi`,
  `firmware-realtek`, `firmware-atheros`, `firmware-misc-nonfree`; Intel and AMD CPU
  microcode on amd64.
- **Desktop:** v0.1.0 ships a light Xfce desktop with the SnapshOT wallpaper, a
  SnapshOT menu with a category per tool group, and the SnapshOT GRUB and Plymouth
  themes. The next release brings the Kali-style desktop: the SnapshOT-Dark theme,
  Papirus-Dark icons, one top panel with the Whisker menu, and the tools in eight
  numbered folders ([docs/desktop.md](docs/desktop.md)):

| Folder | Tools |
|---|---|
| 01 Recon & Discovery | nmap (with its ICS scripts), *Redpoint NSE*, netdiscover, arp-scan, p0f, fping, nbtscan, passive mDNS listen (tshark) |
| 02 Traffic Analysis | Wireshark, tshark, termshark, tcpdump, tcpflow, tcpreplay, Suricata, Scapy |
| 03 Protocol Tools | mbpoll; *pymodbus, pycomm3, BACpypes3, BAC0, asyncua and python-snap7* with the *OPC UA command-line tools*; *opcua-client* (GUI, amd64 only); *plcscan* |
| 04 Firmware & Hardware | binwalk, flashrom, OpenOCD, sigrok-cli, PulseView, sdcc, minicom, picocom, tio, screen, QEMU |
| 05 Wireless & SDR | airodump-ng, rtl-sdr (rtl_eeprom dongle check, rtl_power), gqrx; strictly receive-only |
| 06 Forensics & Response | SnapshOT field triage kit (USB prepare and import, read-only Windows and Linux collectors; [docs/fieldkit.md](docs/fieldkit.md)), The Sleuth Kit, TestDisk/PhotoRec; *Autopsy* (amd64 only) |
| 07 Reporting & Documentation | LibreOffice, CherryTree, Flameshot, pandoc, KeePassXC, nwipe |
| 08 Reference | offline reference folder, the build manifest, the SnapshOT Wiki |

Items in *italics* are the **vendor layer**: software Debian does not ship, pinned in
[`vendor/sources.lock`](vendor/sources.lock) and installed under `/opt/snapshot/<tool>/`,
each with its own pinned runtime (CPython 3.11 for the Python tools, a Temurin 21 JRE for
Autopsy) and reached through
`/opt/snapshot/bin` on `PATH`. It is fetched before a build with
`python3 scripts/vendor.py fetch --arch all` (Docker and network); a build without that
step still produces a working image, just without these tools. **v0.1.0 does not include
the vendor layer.** Zeek with the CISA ICSNPP parsers, Arkime, s7scan, firmware-mod-kit,
Exploit-DB and GRASSMARLIN are defined in the lock but disabled (not yet vendored, or in
GRASSMARLIN's case x86-only Java 8); Ghidra is pinned but disabled because it and its JDK
add about 650 MB. See [docs/vendoring.md](docs/vendoring.md). Everything else comes from
the Debian package lists in [`config/package-lists/`](config/package-lists/).

**The SnapshOT Wiki** documents every tool above against the OT incident-response
lifecycle (SANS PICERL, NIST CSF 2.0, MITRE ATT&CK for ICS): what each tool does, how it
behaves on the wire, a quick start for using it, and where it fits in each phase, with
rules of engagement, playbooks, protocol primers and a guide to the platform itself. It
is a static site of about 13 MB in `/usr/share/snapshot/wiki` (package `snapshot-wiki`),
and works with no network: search, tags and the interactive graphs run offline. Open it
from **08 Reference > SnapshOT Wiki** or the Whisker favourites; it is also the
browser's home page. See [docs/wiki.md](docs/wiki.md).

**Firefox ESR**, the one package in
[`config/package-lists/snapshot-reference.list.chroot`](config/package-lists/snapshot-reference.list.chroot),
shows the wiki and is the browser for PLC, HMI and switch web interfaces; it is in
Usual Applications > Internet. `snapshot-wiki` locks it down: an enterprise policy and
system preferences stop it making any connection on its own (no telemetry, updates, Safe
Browsing, DNS over HTTPS or Remote Settings), and its password manager is off in favour
of KeePassXC. The price is listed under [Status and known issues](#status-and-known-issues).
Firefox adds about 275 MiB to the image.

## Security posture

- **Quiet on the wire.** avahi and systemd-timesyncd are masked, and ModemManager is
  not installed; systemd-resolved has LLMNR and mDNS off; NetworkManager does not
  check connectivity and creates no automatic wired profile; IPv6 autoconfiguration
  and router advertisements are off. Interfaces come up only when the operator brings
  them up. avahi-browse needs the masked daemon, so the menu's mDNS entry is a passive
  tshark listener on udp 5353 instead. Firefox ESR runs under an enterprise policy that
  stops it calling home (`scripts/check-firefox-quiet.sh` captures no packet while it
  shows the wiki).
- **Receive-only radio.** The SDR slice is RTL-SDR and gqrx, hardware that can only
  listen; it answers "is something transmitting here that is not in the asset
  inventory?" with a passive sweep, and airodump-ng is the only 802.11 entry. HackRF,
  GNU Radio and SoapySDR are deliberately not installed, and there is no key-cracking
  launcher.
- **Encryption at rest.** The installer sets up LUKS2 on the root filesystem. `/boot`
  holds only the kernel, initramfs and GRUB files and is not encrypted.
- **Small, fixed install.** No recommended packages, and no network during the
  install: Calamares copies the live image.
- **One client per image.** Re-image between engagements instead of updating in place;
  [docs/updates.md](docs/updates.md) covers the signed offline USB mirror (one stick
  serves amd64 and arm64 laptops) for the exception.
- **Scope.** SnapshOT is a defensive and assessment platform for authorized OT
  engagements only. The default toolset is OT-focused and passive-first.

## Reproducible builds

Every apt source in the build points at one snapshot.debian.org timestamp
(`SNAPSHOT_DEBIAN_PIN` in [`config/snapshot.env`](config/snapshot.env)), and files are
stamped with the matching `SOURCE_DATE_EPOCH`, so two builds of a release from the same
pin resolve the same packages. Each image records where it came from:

- `/etc/snapshot-release`: version, architecture, Debian pin, `SOURCE_DATE_EPOCH` and
  the build commit.
- `/usr/share/snapshot/reference/BUILD-MANIFEST.txt`: the same, plus the kernel, every
  installed package with its version, and the vendor layer.

[`scripts/verify-repro.sh`](scripts/verify-repro.sh) builds twice from a clean state
and compares the two ISOs, running diffoscope when they differ.

## Build from source

```sh
python3 scripts/vendor.py fetch --arch all     # once, online (Docker): runtimes and tools for the vendor layer
scripts/check-installer.sh                     # validate the installer configuration
scripts/check-desktop.sh                       # validate the desktop menu and launchers
scripts/check-fieldkit.sh                      # validate the field kit collectors and USB tools
scripts/check-wiki.sh                          # build and validate the SnapshOT Wiki
scripts/check-firefox-quiet.sh                 # prove Firefox ESR sends nothing on its own (slow)
scripts/test-vendor-hooks.sh [arch]            # install the fetched vendor layer in a trixie container and smoke-test it
SNAPSHOT_ARCH=arm64 docker/build-in-docker.sh  # arm64, in the build container (native on Apple Silicon)
docker/build-in-docker.sh                      # amd64 (emulated on Apple Silicon, much slower)
sudo scripts/build.sh                          # directly on a Debian trixie host
```

The ISO lands in the repository root and the log in `build/build.log`. Requirements,
the vendor layer and the offline mechanics are in [docs/build.md](docs/build.md) and
[docs/vendoring.md](docs/vendoring.md).
Maintainers publish with [`scripts/release.sh`](scripts/release.sh), which also
refreshes the download table above.

## Repository layout

| Path | Contents |
|---|---|
| [`auto/`](auto/), [`config/`](config/) | the live-build project: snapshot pin, package lists, hooks, files copied into the image, boot menu |
| [`packages/`](packages/) | SnapshOT's own Debian packages: `snapshot-themes`, `snapshot-boot` (GRUB and Plymouth), `snapshot-menu`, `snapshot-fieldkit` (the field triage kit), `snapshot-wiki` (the offline wiki and the Firefox ESR policy), `calamares-settings-snapshot` (the installer) |
| [`branding/`](branding/) | brand assets, the source for the copies in `packages/` |
| [`vendor/`](vendor/) | the lock and per-arch requirement files for the vendor layer, `recipes/` (source builds) and `setup/` (per-tool install steps); runtimes, wheelhouses, archives and build output are fetched or built, not committed |
| [`scripts/`](scripts/) | build, `vendor.py` and `vendor-install.py`, the installer, desktop, field kit and wiki checks, the Firefox network check, the vendor layer test, reproducibility test, update USB, release |
| [`docker/`](docker/) | the build container |
| [`docs/`](docs/) | build, vendoring, desktop, field kit, wiki, offline install and field updates |

## Status and known issues

- **v0.1.0 cannot install to disk.** Its installer stops at the display-manager step,
  and the encrypted layout it would have written does not boot: Calamares formats
  LUKS2 with Argon2id, which Debian's GRUB cannot unlock. Use v0.1.0 as a live system
  only. The fixes are in this tree (`calamares-settings-snapshot` 0.1.3,
  `snapshot-boot` 0.1.1) and ship with the next image.
- An image only includes the vendor layer when `python3 scripts/vendor.py fetch` ran
  before the build; v0.1.0 has none of it.
- Autopsy on Linux is a subset of the Windows build: upstream lists Recent Activity as
  partial and LEAPP, plaso, OCR, YARA, HEIF and video thumbnails as unsupported, and
  SnapshOT ships it without the Windows binaries those modules call.
- No hibernation: swap, when chosen, is a file inside the encrypted root and the
  installer writes no resume parameter.
- Firefox ESR receives no certificate revocation or intermediate-certificate updates,
  add-on blocklists or security-list updates: Remote Settings is held off so the browser
  never calls home, and the pinned ESR 140 has no policy for it, so its hosts resolve to
  loopback ([docs/wiki.md](docs/wiki.md)). Re-image rather than update in place.
- Product and support URLs and the package maintainer address are `example.invalid`
  placeholders.

## Licensing

SnapshOT is assembled from Debian packages and third-party tools. Each keeps its own
license; on a running system the terms are in `/usr/share/doc/<package>/copyright`.
