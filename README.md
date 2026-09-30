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
- `vendor/` — pinned inputs for non-apt software (Python wheelhouse, source tools).
- `scripts/` — `fetch-vendor.sh` (online), `build.sh`, `verify-repro.sh`, `make-update-usb.sh`.
- `docker/` — pinned build container.

## Build (on Debian trixie, or via docker/)
```
scripts/fetch-vendor.sh        # once, online: build wheelhouse + fetch source tools
sudo scripts/build.sh          # produces snapshot-*.iso
scripts/verify-repro.sh        # optional: build twice, compare sha256
```

## Status
Scaffold complete and branded. Before a first real build: set the snapshot pin
in `config/snapshot.env`, fill `vendor/sources.lock` URLs/hashes, and replace the
`example.invalid` product/support URLs and maintainer address in `packages/`.
This tree is authored on macOS; builds run on a Debian host.

## Scope note
SnapshOT is a defensive/assessment platform for authorized OT engagements. The
default image is OT-focused and passive-first; a general IT/exploitation toolset
is an opt-in overlay, not part of the standard image. Commercial and vendor tools
are never committed here.
