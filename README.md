# SnapshOT

A Blackbird Cyber product: an offline, reproducible Debian image for OT/ICS
reconnaissance and client engagements. Built like Kali (Debian `live-build`), but pinned to a single
`snapshot.debian.org` timestamp so every build is repeatable, and installable at
an air-gapped site with no network. Full-disk LUKS2 encryption via the installer.
Wipe and re-image between clients.

See the full design in `docs/` and the approved plan referenced there.

## Layout
- `auto/`, `config/` — live-build project (snapshot pin, package lists, hooks, includes).
- `packages/` — SnapshOT branding packages: `snapshot-themes`, `snapshot-boot`,
  `snapshot-menu`, `calamares-settings-snapshot`.
- `branding/` — SnapshOT brand assets (source of truth; packages carry copies).
- Desktop: the live/installed Xfce desktop (dark SnapshOT-Dark theme, Papirus-Dark
  icons, one top panel with a Whisker menu, tools in numbered folders) is set up by
  `snapshot-themes` and `snapshot-menu`; see [`docs/desktop.md`](docs/desktop.md).
- `vendor/` — pinned inputs for the per-tool runtime layer: the lock and the
  committed per-arch `requirements.<arch>.txt`; wheelhouses and archives are
  fetched, not committed. See [`docs/vendoring.md`](docs/vendoring.md).
- `scripts/` — `vendor.py` (online: fetch runtimes + per-arch wheelhouses),
  `build.sh`, `test-vendor-hooks.sh`, `verify-repro.sh`, `make-update-usb.sh`.
- `docker/` — pinned build container.

## Download
Prebuilt images are on the [releases page](https://github.com/Blackbird-Cyber/SnapshOT/releases).
Current release: **v0.1.0**, Debian trixie pinned to snapshot.debian.org
`20260901T022952Z`.

| Image | For | Boot | Size | SHA-256 |
|---|---|---|---|---|
| [snapshot-amd64.hybrid.iso](https://github.com/Blackbird-Cyber/SnapshOT/releases/download/v0.1.0/snapshot-amd64.hybrid.iso) | x86-64 laptops | BIOS + UEFI | 1.61 GiB | `35d5da86cf245e90416014062bf83542e4a523ac64578016cac5a9ea21fc7c14` |
| [snapshot-arm64.hybrid.iso](https://github.com/Blackbird-Cyber/SnapshOT/releases/download/v0.1.0/snapshot-arm64.hybrid.iso) | arm64 VMs on Apple Silicon (UTM, Parallels, VMware Fusion) and UEFI arm64 hardware | UEFI | 1.63 GiB | `66c81e0fb7f4ebf11a09ea749cb74581c692c39d63cc171b7aa3f7041f15f244` |

- The arm64 image does not boot Apple Silicon hardware directly; run it in a VM.
- Write the amd64 image to USB with `dd if=snapshot-amd64.hybrid.iso of=/dev/sdX bs=4M conv=fsync`
  or Ventoy. Verify with `shasum -a 256 <file>` against the table or the release's
  `SHA256SUMS`.
- Live session: user `snapshot`, password `live`. Boots into the dark SnapshOT
  Xfce desktop with the Kali-style tool menu. Install from the desktop icon
  (Calamares, offline, LUKS2).
- v0.1.0 omits the vendor layer; run `python3 scripts/vendor.py fetch` (Docker +
  network) before building to include the per-tool `/opt/snapshot` runtimes and
  tools (ICS Python libraries, OPC UA GUI client, plcscan, Redpoint NSE). See
  [`docs/vendoring.md`](docs/vendoring.md).

## Build (on Debian trixie, or via docker/)
```
python3 scripts/vendor.py fetch --arch all     # once, online (Docker): runtimes + per-arch wheelhouses
sudo scripts/build.sh                          # produces snapshot-amd64.hybrid.iso
SNAPSHOT_ARCH=arm64 sudo scripts/build.sh      # arm64 (UEFI only), on an arm64 host
docker/build-in-docker.sh                      # same, inside the pinned container (macOS too)
scripts/verify-repro.sh                        # optional: build twice, compare sha256
scripts/release.sh v0.1.0 --prerelease         # publish ISOs as a GitHub release (needs gh)
```

## Status
Scaffold complete and branded, with the tool-isolation vendor layer in place:
`vendor/sources.lock` v2 pins each non-apt tool's own runtime and
`scripts/vendor.py` fetches them into `/opt/snapshot/<tool>/`
(see [`docs/vendoring.md`](docs/vendoring.md)). Before a first real build: set the
snapshot pin in `config/snapshot.env`, run `python3 scripts/vendor.py fetch`, and
replace the `example.invalid` product/support URLs and maintainer address in
`packages/`. This tree is authored on macOS; builds run on a Debian host.

## Scope note
SnapshOT is a defensive/assessment platform for authorized OT engagements. The
default image is OT-focused and passive-first; a general IT/exploitation toolset
is an opt-in overlay, not part of the standard image. Commercial and vendor tools
are never committed here.
