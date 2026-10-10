# Contributing to SnapshOT

Bug reports, tool requests and pull requests are welcome. Report security
problems privately, as [SECURITY.md](SECURITY.md) describes, not in an issue.

## Before you start

- Open an issue first for anything larger than a fix: a new tool, a new menu
  folder, a change to the network defaults or the installer. The
  [tool request](https://github.com/Blackbird-Cyber/SnapshOT/issues/new/choose)
  form asks what the maintainers need to decide: the license, what the tool does
  on the wire and which response phase it serves.
- A tool must work offline, come from the pinned Debian snapshot or the vendor
  layer ([docs/vendoring.md](docs/vendoring.md)), and get a page in the SnapshOT
  Wiki.

## Build and check

Everything runs in Docker; see [docs/build.md](docs/build.md) for the
requirements. The checks take from seconds to a few minutes each:

```sh
scripts/check-installer.sh    # installer configuration, every package changelog, the sudo hook
scripts/check-desktop.sh      # menus, launchers and Xfce defaults
scripts/check-fieldkit.sh     # field kit collectors, USB tools and package build
scripts/check-wiki.sh         # strict wiki build and the wiki's own rules
scripts/check-provenance.sh   # no attribution lines in commits, no embedded manifests in images
docker run --rm -v "$PWD":/repo -w /repo python:3.11-slim-trixie \
  sh -c 'pip install -q "reuse[charset-normalizer]" && reuse lint'
```

`check-wiki.sh` and `check-firefox-quiet.sh` default to `linux/arm64` for Apple
Silicon; set `SNAPSHOT_CHECK_PLATFORM=linux/amd64` on an x86-64 host. Run the
checks that cover the files you changed, and a full image build
(`docker/build-in-docker.sh`) for changes to package lists, hooks or the
installer.

## Branches and pull requests

- One branch per change, and one pull request per branch.
- A change to a package under `packages/` adds an entry to that package's
  `debian/changelog` with a new version.
- Say in the pull request which checks you ran and what they printed; the pull
  request template asks for it.

## House style

- **SnapshOT** in prose, `snapshot` in package names, paths and commands.
- Plain declarative sentences, American spelling, no marketing adjectives.
- No em-dashes; use a colon, a comma or brackets. `check-wiki.sh` fails on them
  in the wiki.
- Wiki pages name no package versions: they change with the pin, and the build
  manifest has them. [docs/wiki.md](docs/wiki.md) is the authoring guide.
- Copyright and licenses are recorded by path in [`REUSE.toml`](REUSE.toml), not
  in file headers. A file that is not Blackbird Cyber's work, or not under the
  default license of its folder, needs an annotation there and a stanza in its
  package's `debian/copyright`. `reuse lint` must pass.

## Licensing of contributions

Contributions are accepted under the license of the files they change, inbound
equal to outbound: code, configuration and packaging under the
[Apache License 2.0](LICENSE) (section 5 covers contributions), the wiki and
`docs/` under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). There is
no contributor license agreement. Brand assets are not open for contributions;
see [TRADEMARKS.md](TRADEMARKS.md).

By taking part you agree to the [code of conduct](CODE_OF_CONDUCT.md).
