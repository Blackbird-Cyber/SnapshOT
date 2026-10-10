# Live ISO boot menu branding

live-build copies `/usr/share/live/build/bootloaders/grub-pc/*` into the ISO's
`/boot/grub`, then copies `config/bootloaders/grub-pc/*` on top (`cp -af`), so
only the files here override upstream; everything else comes from live-build.

- `grub-pc/splash.png`: SnapshOT splash, 1920x1080. Its presence makes
  upstream `theme.cfg` select `live-theme/theme.txt`.
- `grub-pc/live-theme/theme.txt`: the SnapshOT menu layout.
- `grub-pc/config.cfg`: upstream file with `gfxmode=auto` instead of 800x600.

Both `grub-efi` and `grub-pc` bootloaders read this same directory.
Source assets live in `branding/`.
