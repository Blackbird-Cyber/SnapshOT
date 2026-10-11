# SnapshOT trademark policy

SnapshOT's code is licensed under the Apache License 2.0 and its documentation
under CC BY 4.0. Those licenses cover copyright. They do not grant any right to
use the names and logos below (Apache License 2.0, section 6). This page says
how you may use them. It is modeled on the Kali Linux trademark policy and is
shorter.

## The marks

Blackbird Cyber, LLC claims these as its marks:

- the name **SnapshOT** for an operating system image, its tools and its
  documentation;
- the SnapshOT mark: viewfinder corners around a frame with a 45 degree cut,
  and the app icons drawn from it;
- the SnapshOT lockups (the wordmark with the mark), the splash and the title
  card;
- the name **Blackbird Cyber** and the Blackbird bird mark.

The artwork is in [`branding/`](branding/) and in the package slots listed in
[`branding/README.md`](branding/README.md). Those files are licensed under
[`LicenseRef-Blackbird-Brand`](LICENSES/LicenseRef-Blackbird-Brand.txt), not
under the Apache License or CC BY 4.0. [`REUSE.toml`](REUSE.toml) lists every
path it covers.

## Uses that need no permission

- Naming SnapshOT and linking to this repository or its releases.
- Screenshots of SnapshOT in articles, talks, training material and reports.
- Saying that a course, a lab image or a tool is "based on SnapshOT" or "built
  with SnapshOT", when that is true and SnapshOT is not part of its name.
- Redistributing the official images from the
  [releases page](https://github.com/Blackbird-Cyber/SnapshOT/releases)
  unmodified, with the branding intact.
- Building and running an unmodified copy of this repository.

## Uses that need written permission

- The SnapshOT name or marks on a modified build or a derived distribution.
- A product, project, service or company name that contains "SnapshOT" or a
  name that could be confused with it.
- Domain names, social media accounts and app store listings that contain the
  name.
- Merchandise.
- Any use that suggests Blackbird Cyber made, endorses or supports something it
  did not.

## How to rebrand a fork

A fork that changes the image may keep the code and the documentation under
their licenses, but not the SnapshOT name or marks. Replace or remove:

- [`branding/`](branding/), the source of every asset below;
- in [`packages/snapshot-themes`](packages/snapshot-themes/): the wallpaper
  under `usr/share/backgrounds/`, the hicolor icons under `usr/share/icons/`
  and the LightDM greeter settings;
- [`packages/snapshot-boot`](packages/snapshot-boot/): the GRUB theme and the
  Plymouth splash;
- in [`packages/calamares-settings-snapshot`](packages/calamares-settings-snapshot/):
  `etc/calamares/branding/snapshot/` (logo, icon, banner, slideshow and the
  product strings in `branding.desc`);
- [`config/bootloaders/grub-pc/splash.png`](config/bootloaders/grub-pc/splash.png),
  the live boot menu background, and the ISO identity in
  [`auto/config`](auto/config) (`--iso-application`, `--iso-volume`,
  `--iso-publisher`);
- the wiki's logo and favicon in
  [`packages/snapshot-wiki/assets/img/`](packages/snapshot-wiki/assets/img/) and
  its `site_name`, `site_author` and `copyright` in
  [`mkdocs.yml`](packages/snapshot-wiki/mkdocs.yml);
- the product name in package descriptions, menu folder names and
  `/etc/snapshot-release`.

Package names, file paths and the `snapshot` user name are technical
identifiers. A fork may keep them, provided its name, artwork and descriptions
do not present it as SnapshOT.

## Asking

Open an issue on [GitHub](https://github.com/Blackbird-Cyber/SnapshOT/issues)
and describe the use. The answer comes in the issue.
