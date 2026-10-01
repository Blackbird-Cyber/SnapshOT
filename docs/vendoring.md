# Vendoring: every non-apt tool carries its own runtime

Debian trixie ships exactly one of each runtime (Python 3.13 only, no Python 2,
one JDK), but the tools SnapshOT carries disagree: the ICS Python libraries are
happiest on 3.11, Ghidra wants a full JDK 21. So SnapshOT does **not** install
those tools against the OS interpreters. Instead:

> **Every non-apt tool lives under `/opt/snapshot/<tool>/` with its own pinned
> runtime, so versions coexist and nothing a tool needs touches the OS's own
> interpreters or `PATH`.**

Apt packages are still the first choice; this layer is only for software Debian
does not provide at the version we need.

## Layout on the image

```
/opt/snapshot/
  runtimes/cpython-3.11.16/        bin/python3, lib/..., MANIFEST   (shared, immutable)
  runtimes/temurin-jdk-21.0.12.1/  (only once an enabled tool references it)
  ics-python/   MANIFEST  venv/  bin/{ics-python,uadiscover,...,pymodbus-console}
  opcua-client/ MANIFEST  venv/  bin/opcua-client            (amd64 images only)
  plcscan/      MANIFEST  app/   bin/plcscan                 (runtime python, no venv)
  redpoint-nse/ MANIFEST  scripts/*.nse  LICENSE  (+ symlinks into nmap's script dir)
  bin/          symlinks -> ../<tool>/bin/<cmd>   <- the only dir ever put on PATH
```

Rules:

- A **runtime dir is never modified** after it is unpacked and made read-only.
- Runtimes live in a **shared versioned store** (`runtimes/<name>-<version>`), so
  two tools on the same runtime share one copy; each tool pins an exact runtime.
- A tool **never writes outside its own dir**, with one documented exception:
  data that plugs into an OS tool (Redpoint's NSE scripts are symlinked into
  `/usr/share/nmap/scripts/`, never binaries or runtimes). They are symlinks so
  provenance stays visible.
- The **only** dir added to `PATH` is `/opt/snapshot/bin`, and it is **appended**
  (login shells via `/etc/profile.d/snapshot-tools.sh`, the X session via
  `/etc/X11/Xsession.d/55snapshot-tools-path`) so the OS's own commands win.
- No vendored `python`/`java`/`pip` is ever reachable by its bare name. Each
  `/opt/snapshot/bin/<cmd>` is a wrapper that sets the tool's environment and
  `exec`s the real program with an absolute path.
- Wrappers hard-code absolute paths; **moving `/opt/snapshot` is not supported.**

### Wrappers

`scripts/vendor-install.py` generates one wrapper per `commands:` entry, e.g. for
`uadiscover=venv/bin/uadiscover` in the python tool `ics-python`:

```sh
#!/bin/sh
# SnapshOT wrapper for ics-python (generated at image build; docs/vendoring.md)
TOOL=/opt/snapshot/ics-python
RUNTIME=/opt/snapshot/runtimes/cpython-3.11.16
export PYTHONNOUSERSITE=1
export PYTHONDONTWRITEBYTECODE=1
export PATH="$TOOL/venv/bin:$RUNTIME/bin:$PATH"
exec "$TOOL/venv/bin/uadiscover" "$@"
```

- `commands: name=python` execs the venv python (or the runtime python when the
  tool has no venv); `name=python <path>` runs that script with it.
- Java tools export `JAVA_HOME=$RUNTIME` and prepend `$JAVA_HOME/bin`.
- `LD_LIBRARY_PATH="$TOOL/lib"` is added only when the tool actually unpacks a
  `lib/` dir.

### MANIFEST

Each runtime and tool gets `/opt/snapshot/<name>/MANIFEST` (key=value: `name`,
`type`, `version`, `arch`, `runtime`, `url`, `sha256`, `license`, `built`,
`commands`). `built` is `SOURCE_DATE_EPOCH` in ISO 8601 — manifests carry **no
wall-clock values**, so the image stays reproducible. Every manifest is also
copied to `/usr/share/snapshot/vendor/<name>.manifest`, and hook 0900 dumps that
glob plus `ls /opt/snapshot/bin` into `BUILD-MANIFEST.txt`.

## The lock — `vendor/sources.lock`

Stanza text (blank-line separated, `key: value`), one stanza per artifact. Fields:

| field | meaning |
|---|---|
| `type` | `runtime` \| `python` \| `java` \| `data` |
| `kind` | `tarball` \| `zip` \| `git-archive` \| `deb` (archive handling; `deb` is reserved — not yet implemented) |
| `arch` | `noarch` \| `amd64` \| `arm64` \| `amd64, arm64` (which images get it) |
| `url` / `sha256` | an arch-independent artifact |
| `url.<arch>` / `sha256.<arch>` | one artifact per architecture |
| `size` | optional expected byte count, verified after download |
| `strip` | top-level dirs to strip on extraction (default 0) |
| `runtime` | the runtime stanza this tool pins |
| `requirements` | a `requirements.in` for a venv (python tools); the per-arch locks `requirements.<arch>.txt` sit beside it |
| `commands` | `name=exec, ...` (exec relative to the tool dir) |
| `install` | `nmap-scripts` (symlink *.nse into nmap) \| `copy` (default) |
| `enabled` | `true` (default) \| `false` — disabled stanzas are validated, never fetched |
| `license` | recorded in the MANIFEST |

`sha256: TODO` is filled by `vendor.py update-hashes`; `vendor.py fetch` refuses
to proceed on a `TODO`. Only runtimes referenced by an **enabled** tool are ever
fetched, staged or installed (so JDK 21 does not ship until Ghidra is enabled).

## The one online step — `scripts/vendor.py`

Run on a networked host with Docker (the Mac is fine) **before** `build.sh`:

```
python3 scripts/vendor.py status                 # table of the lock + what is fetched
python3 scripts/vendor.py update-hashes          # fill TODO sha256 (downloads once)
python3 scripts/vendor.py fetch --arch all       # download runtimes + build wheelhouses
python3 scripts/vendor.py verify                 # recheck sha256 under vendor/src
```

`scripts/fetch-vendor.sh` is a thin shim for `vendor.py fetch`.

Per **python** tool and arch, `fetch` runs inside a throwaway `debian:trixie`
container with `--platform linux/<arch>` (arm64 native on Apple Silicon, amd64
emulated — it only resolves and downloads, so minutes not hours). It unpacks that
arch's pinned CPython, runs `pip-compile --generate-hashes` to produce
`requirements.<arch>.txt`, then `pip download --require-hashes --no-deps
--only-binary=:all:` into `wheelhouse/<arch>`. Because it uses the **exact target
interpreter**, markers and the ABI resolve correctly and no cross-platform pip
flags are needed. `--only-binary=:all:` is the gate: any package without a wheel
for the target makes the step fail, naming it.

The generated `requirements.<arch>.txt` are committed (hash-pinned locks). The
`wheelhouse/<arch>` dirs and the `vendor/src/**` archives are **gitignored**, so
anyone building must run `vendor.py fetch` first. A build without the vendor layer
still works: `build.sh` warns and stages nothing (set `SNAPSHOT_VENDOR_REQUIRED=1`
to make "enabled but not fetched" an error).

`build.sh` stages the arch's layer with `vendor.py stage --arch <arch> --dest
config/includes.chroot/usr/local/share/snapshot/vendor`. Hooks 0100/0200 run
`vendor-install.py runtimes` then `tools finish` offline in the chroot.

## Size budget (per arch, this enabled set)

| artifact | amd64 | arm64 |
|---|---|---|
| CPython 3.11.16 runtime (download) | ~30 MiB | ~30 MiB |
| ics-python wheelhouse (39 wheels) | ~13 MiB | ~13 MiB |
| opcua-client wheelhouse (19 wheels, incl. PyQt5) | ~74 MiB | n/a |
| plcscan + Redpoint archives | ~76 KiB | ~76 KiB |

Ghidra (disabled) is 456 MiB and pulls the 180+ MiB JDK; enabling it pushes the
ISO past GitHub's 2 GiB asset limit (`release.sh` splits).

## Recipes

### Add a runtime

Add a `type: runtime` stanza with `url.<arch>`/`sha256.<arch>` (or `url`/`sha256`
for noarch) and `strip`. `vendor.py update-hashes` fills a `TODO`. The runtime is
only fetched/installed once an **enabled** tool sets `runtime: <name>`.

### Add a Python tool

1. Create `vendor/python/<tool>/requirements.in` (pin exact versions).
2. Add a `type: python` stanza: `runtime:`, `requirements:
   vendor/python/<tool>/requirements.in`, `arch:`, and `commands:` mapping each
   wrapper name to `venv/bin/<script>` (or `python`).
3. `vendor.py fetch --only <tool> --arch all`, commit `requirements.<arch>.txt`.
4. Add a launcher (see `docs/desktop.md`) pointing `Exec`/`TryExec` at
   `/opt/snapshot/<tool>/bin/<cmd>`.
5. `scripts/test-vendor-hooks.sh arm64` (and `amd64`).

### Add a Java tool

`type: java`, `runtime: temurin-jdk-21.0.12.1` (flip the JDK to `enabled: true`),
`kind: zip`/`tarball`, `strip`, `commands: name=app/<launcher>`.

### Add a data set that plugs into an OS tool

`type: data`, `install: nmap-scripts` (currently the only supported target).
`*.nse` are symlinked into `/usr/share/nmap/scripts/` and `script.db` is rebuilt
and `LC_ALL=C` sorted. For plain reference data, use `install: copy` (default).

## Licenses recorded

Each MANIFEST records a `license`; bundled `LICENSE`/`COPYING` files are copied to
`/opt/snapshot/<tool>/LICENSE`.

| artifact | license |
|---|---|
| CPython runtimes (python-build-standalone) | PSF-2.0 (bundles OpenSSL etc. under their own terms) |
| Temurin JDK 21 | GPL-2.0-with-Classpath-Exception |
| ics-python wheels | per package: pymodbus BSD-3, pymodbus-repl BSD-3, pycomm3 MIT, asyncua LGPL-3.0, bacpypes3 MIT, BAC0 LGPL-3.0, python-snap7 MIT |
| opcua-client | GPL-3.0 (PyQt5 GUI) |
| plcscan (eloraux fork) | GPL-3.0 |
| Redpoint NSE | Nmap license (same as Nmap; see bundled `LICENSE`) |
| Ghidra | Apache-2.0 |

## Out of scope and why

- **pydnp3** — sdist only (no wheel); would need a native build stage. Dropped.
- **cpppo** — every release pins `greenery<3.0`, and no greenery below 3.0
  publishes a wheel, so it cannot be installed under the wheels-only,
  `--require-hashes` contract. Dropped; **pycomm3 already covers EtherNet/IP**.
- **GRASSMARLIN** — archived; Java 8 + JavaFX and an x86-only JNetPcap native lib.
  Unsupported on this image.
- **zeek / ICSNPP** — zeek ships as an OBS `.deb` into `/opt/zeek` and pulls apt
  dependencies (the documented exception to "self-contained"); ICSNPP needs a
  working zeek. Defined as disabled placeholders.
- **arkime** — `.deb` into `/opt/arkime`, no published stable sha. Placeholder.
- **s7scan** — a Python 3 fork (desvert) would need scapy pinned in its own venv;
  not yet vendored. Placeholder.
- **firmware-mod-kit / exploitdb** — need their own build/large data stages.
  Placeholders.

These stay in the lock as `enabled: false` stanzas so the shape is recorded; they
are validated but never fetched.
