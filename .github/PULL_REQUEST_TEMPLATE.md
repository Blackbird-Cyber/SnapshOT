## What and why

<!-- What the change does, and the issue it closes, if any. -->

## Checks

<!-- Tick what you ran and paste the last lines of each. -->

- [ ] `scripts/check-installer.sh`
- [ ] `scripts/check-desktop.sh`
- [ ] `scripts/check-fieldkit.sh`
- [ ] `scripts/check-wiki.sh`
- [ ] `scripts/check-firefox-quiet.sh`
- [ ] `scripts/test-vendor-hooks.sh`
- [ ] `reuse lint`
- [ ] An image build (package lists, hooks or installer changes)

## Housekeeping

- [ ] Each changed package under `packages/` has a new `debian/changelog` entry.
- [ ] New third-party files are annotated in `REUSE.toml` and the package's `debian/copyright`.
- [ ] House style: no em-dashes, American spelling, no package versions in wiki pages.
