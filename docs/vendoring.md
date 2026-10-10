# Vendoring: every non-apt tool carries its own runtime

Debian trixie ships exactly one of each runtime (Python 3.13 only, no Python 2,
one JDK), but the tools SnapshOT carries disagree: the ICS Python libraries are
happiest on 3.11, and a tool like Ghidra would need a full JDK 21. So SnapshOT
does **not** install those tools against the OS interpreters. Instead:

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
  ics-python/   MANIFEST  venv/  bin/{ics-python,uadiscover,...,uahistoryread}
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
`type`, `version`, `arch`, `runtime`, `url`, `sha256`, `uses`, `setup`,
`license`, `built`, `commands`). `uses` is `<build>@<version>:<build.sha256>`
for each source build the tool consumed. `built` is `SOURCE_DATE_EPOCH` in ISO
8601: manifests carry **no wall-clock values**, so the image stays
reproducible. Every manifest is also
copied to `/usr/share/snapshot/vendor/<name>.manifest`, and hook 0900 dumps that
glob plus `ls /opt/snapshot/bin` into `BUILD-MANIFEST.txt`.

## The lock: `vendor/sources.lock`

Stanza text (blank-line separated, `key: value`), one stanza per artifact. Fields:

| field | meaning |
|---|---|
| `type` | `runtime` \| `python` \| `java` \| `data` \| `build` (`build`: fetched and built by `vendor.py`, never installed alone) |
| `kind` | `tarball` \| `zip` \| `git-archive` \| `deb` (archive handling; `deb` is reserved, not yet implemented) |
| `arch` | `noarch` \| `amd64` \| `arm64` \| `amd64, arm64` (which images get it) |
| `url` / `sha256` | an arch-independent artifact |
| `url.<arch>` / `sha256.<arch>` | one artifact per architecture |
| `size` | optional expected byte count, verified after download |
| `strip` | top-level dirs to strip on extraction (default 0) |
| `runtime` | the runtime stanza this tool pins |
| `requirements` | a `requirements.in` for a venv (python tools); the per-arch locks `requirements.<arch>.txt` sit beside it |
| `commands` | `name=exec, ...` (exec relative to the tool dir) |
| `install` | `nmap-scripts` (symlink *.nse into nmap) \| `copy` (default) |
| `build` | the recipe script under `vendor/recipes/` (`type: build`) |
| `build.sha256.<arch>` | sha256 of the build's `SHA256SUMS` (a `TODO` is filled by `update-hashes`) |
| `uses` | build stanzas whose output the tool's setup consumes |
| `setup` | `vendor/setup/<tool>.py`, run in the chroot after extraction |
| `enabled` | `true` (default) \| `false`; disabled stanzas are validated, never fetched |
| `license` | recorded in the MANIFEST |

`sha256: TODO` is filled by `vendor.py update-hashes`; `vendor.py fetch` refuses
to proceed on a `TODO`. A runtime is fetched, staged and installed if and only if
an **enabled** tool references it; the runtime's own `enabled` is ignored (so the
JDK 21 does not ship until Ghidra is enabled). The same holds for source builds
and the tools that `uses:` them.

## The one online step: `scripts/vendor.py`

Run on a networked host with Docker (the Mac is fine) **before** `build.sh`:

```
python3 scripts/vendor.py status                 # table of the lock + what is fetched
python3 scripts/vendor.py update-hashes          # fill TODO sha256 (downloads once)
python3 scripts/vendor.py fetch --arch all       # download, run source builds, build wheelhouses
python3 scripts/vendor.py verify                 # recheck sha256 under vendor/src
```

`scripts/fetch-vendor.sh` is a thin shim for `vendor.py fetch`.

Per **python** tool and arch, `fetch` runs inside a throwaway `debian:trixie`
container with `--platform linux/<arch>` (arm64 native on Apple Silicon, amd64
emulated: it only resolves and downloads, so minutes not hours). It unpacks that
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

## Source builds (`type: build`)

Some tools need a native piece no upstream publishes for Linux. The one recipe in
the tree, `sleuthkit-jni`, is the worked example: it built `libtsk_jni.so` from
The Sleuth Kit 4.15.0 for Autopsy, whose TSK jar only carries Windows DLLs. It is
disabled together with Autopsy (see [Out of scope and why](#out-of-scope-and-why)),
so no current build fetches or runs it; the stanza and
`vendor/recipes/sleuthkit-jni.sh` stay as the recorded shape.

- The recipe lives in `vendor/recipes/<name>.sh` (lock key `build:`). `fetch`
  runs it for every arch an enabled tool `uses:` it on; `update-hashes` runs it
  for each arch whose `build.sha256.<arch>` is `TODO`.
- It runs in a throwaway `$SNAPSHOT_TRIXIE_IMAGE` (`debian:trixie`) container
  of the target arch with the repo at `/work`. `vendor/recipes/lib/pinned-apt.sh`
  points apt at the snapshot pin from `config/snapshot.env` only and downgrades
  the base image to it, so the build links against exactly the libraries the
  image ships. The recipe gets `BUILD_SRC` (the pinned source archive),
  `BUILD_STRIP`, `BUILD_OUT`, `SNAPSHOT_DEBIAN_PIN`, `SNAPSHOT_DIST`,
  `SOURCE_DATE_EPOCH`, `HOST_UID` and `HOST_GID`.
- Output goes to `vendor/src/<arch>/<name>/out/` (gitignored). `vendor.py`
  writes `SHA256SUMS` of that tree there, and the lock records the sha256 of
  `SHA256SUMS`. `fetch`, `verify` and `stage` check it on the host, and
  `vendor-install.py` checks it and every listed file again in the chroot.
- A mismatch means the pin moved or the build is not reproducible. Review the
  change, then clear the value to `TODO` and rerun `update-hashes --only <name>`.
  Recipes build in fixed paths and link with `--build-id=none` so the output is
  bit-for-bit the same per pin.
- When it was enabled, the amd64 `libtsk_jni` took about 3 to 5 minutes
  emulated on Apple Silicon.

## Post-install setup (`setup:`)

A tool with `setup: vendor/setup/<tool>.py` is staged with that script.
`vendor-install.py tools` runs it with the image's `python3`, as root and
offline, after the archive is unpacked and its LICENSE recorded, and before the
wrappers, `chmod go-w`, the MANIFEST and the mtime clamp. Its environment:

| variable | value |
|---|---|
| `SNAPSHOT_TOOL` | `/opt/snapshot/<tool>` |
| `SNAPSHOT_APP` | `/opt/snapshot/<tool>/app` (the unpacked archive) |
| `SNAPSHOT_ARCH` | the image arch |
| `SNAPSHOT_RUNTIME` | `/opt/snapshot/runtimes/<runtime>`, when the tool has one |
| `SNAPSHOT_BUILD_<NAME>` | the verified `out/` dir of each `uses:` build (`sleuthkit-jni` -> `SNAPSHOT_BUILD_SLEUTHKIT_JNI`) |
| `SOURCE_DATE_EPOCH` | the pin's epoch |

A non-zero exit fails the image build. After setup, every non-`python`
`commands:` target must exist and be executable, which catches exec bits lost
in a zip.

`vendor/setup/autopsy.py`, kept with the disabled `autopsy` stanza, is the
worked example. It did `unix_setup.sh`'s job for a read-only tree: it set
`jdkhome` in `etc/autopsy.conf` to the Temurin JRE, put `libtsk_jni.so` into the
TSK jar as `NATIVELIBS/amd64/linux/libtsk_jni.so` (the only place TSK loads it
from), moved the embedded Solr's pid file and logs to `~/.autopsy/dev`, restored
the exec bits the zip does not store, pruned about 885 MiB of Windows/macOS-only
payload while keeping the OCR language packs the first start copies, and copied
the Sleuth Kit license texts. Its docstring and comments record why each step
was needed.

## Size budget (per arch, this enabled set)

| artifact | amd64 | arm64 |
|---|---|---|
| CPython 3.11.16 runtime (download) | ~30 MiB | ~30 MiB |
| ics-python wheelhouse (20 wheels) | ~7.3 MiB | ~7.5 MiB |
| opcua-client wheelhouse (19 wheels, incl. PyQt5) | ~74 MiB | n/a |
| plcscan + Redpoint archives | ~76 KiB | ~76 KiB |

With this set both ISOs are expected to stay under GitHub's 2 GiB release-asset
limit; `release.sh` splits any image that exceeds it. Ghidra (disabled) is about
435 MiB (the lock's 456,551,841-byte zip) and pulls the 180+ MiB JDK on both
arches, which would push the amd64 image toward that limit. Autopsy (disabled)
was the largest item on amd64: a 1.16 GiB zip (1808 MiB unpacked) installed as
about 925 MiB after the prune removed about 885 MiB, plus 158 MiB for its
Temurin JRE and 0.9 MiB of `sleuthkit-jni` output. The October 6 builds from
82115b8, the last with Autopsy, measured 2.53 GiB (2,721,531,904 bytes) on amd64
and 1.72 GiB (1,845,573,632 bytes) on arm64; neither was published.

The v0.2.1 images, built from 8a5ba28 without Autopsy, measured 1.75 GiB
(1,879,400,448 bytes) on amd64 and 1.71 GiB (1,837,686,784 bytes) on arm64,
both under the limit, so neither is split.

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

`type: java`, `runtime: temurin-jdk-21.0.12.1` (or the JRE when the tool needs
no `javac`), `kind: zip`/`tarball`, `strip`, `commands: name=app/<launcher>`.
The runtime ships once the tool is enabled.

A tool that needs a native piece built from source or a fix-up after
extraction adds `uses: <build stanza>` and `setup: vendor/setup/<tool>.py` (see
[Source builds](#source-builds-type-build) and
[Post-install setup](#post-install-setup-setup)); the disabled `autopsy` stanza
in the lock shows both. A tool that `uses:` a build needs that build stanza
enabled too, or `vendor.py fetch` stops.

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
| Temurin JDK 21, Temurin JRE 21 (both disabled) | GPL-2.0-with-Classpath-Exception |
| ics-python wheels | per package (from wheel metadata / bundled LICENSE): pymodbus BSD-3-Clause, pyserial BSD-3-Clause, pycomm3 MIT, asyncua LGPL-3.0+, bacpypes3 MIT, BAC0 LGPL-3.0, python-snap7 MIT |
| opcua-client | GPL (opcua-client, unversioned) + GPL-3.0 (PyQt5) |
| plcscan (eloraux fork) | GPL-3.0 |
| Redpoint NSE | Nmap license (same as Nmap; see bundled `LICENSE`) |
| Ghidra (disabled) | Apache-2.0 |
| Autopsy (disabled) | Apache-2.0; bundled third-party components under their own terms (see the release's notices) |
| The Sleuth Kit `libtsk_jni.so` build (disabled, with Autopsy) | IPL-1.0 and CPL-1.0 (libtsk), Apache-2.0 (Java bindings) |

The disabled rows are pinned in the lock but not on the image.

## Out of scope and why

- **pydnp3**: sdist only (no wheel); would need a native build stage. Dropped.
- **cpppo**: every release pins `greenery<3.0`, and no greenery below 3.0
  publishes a wheel, so it cannot be installed under the wheels-only,
  `--require-hashes` contract. Dropped; **pycomm3 already covers EtherNet/IP**.
- **pymodbus-repl** (`pymodbus.console`, the `pymodbus-console` command): dead
  upstream: its last release, 2.0.4 (August 2024), imports `ModbusAsciiFramer`
  from `pymodbus.transaction`, which pymodbus 3.7.3 and later no longer export,
  so it only runs with pymodbus 3.7.0-3.7.2. Dropped rather than holding pymodbus
  back at 3.7.2; **`mbpoll` (Debian) is the interactive Modbus client**, and the
  pymodbus library (with pyserial for `ModbusSerialClient`) stays in `ics-python`.
- **Autopsy** (with the Temurin JRE 21 and the `sleuthkit-jni` build that only it
  used): disabled on 2026-10-07. Autopsy is Windows-first and its Linux build is
  a documented subset (upstream lists Recent Activity as partial and LEAPP,
  plaso, OCR, YARA, HEIF and video thumbnails as unsupported on Linux), and
  fitting it into an offline, read-only, quiet-on-the-wire image kept exposing
  new assumptions: a TSK JNI library no release ships for Linux, Java 21, OCR
  language data its first start copies, a JRE module (`jdk.unsupported.desktop`)
  its JavaFX panels need, and an update check. It was amd64 only as well: its
  JavaFX jars and other native parts are x86-64, and upstream does not support
  arm64 Linux. **The Sleuth Kit and TestDisk/PhotoRec stay on both arches**, and
  Autopsy belongs on a separate analysis workstation (its Windows build,
  installed by the operator and not redistributed) that receives the case folder
  and its `SHA256SUMS` after the field kit hand-off
  ([docs/fieldkit.md](fieldkit.md#hand-off-to-an-analysis-workstation)).
- **GRASSMARLIN**: archived; Java 8 + JavaFX and an x86-only JNetPcap native lib.
  Unsupported on this image.
- **zeek / ICSNPP**: zeek ships as an OBS `.deb` into `/opt/zeek` and pulls apt
  dependencies (the documented exception to "self-contained"); ICSNPP needs a
  working zeek. Defined as disabled placeholders.
- **arkime**: `.deb` into `/opt/arkime`, no published stable sha. Placeholder.
- **s7scan**: a Python 3 fork (desvert) would need scapy pinned in its own venv;
  not yet vendored. Placeholder.
- **firmware-mod-kit / exploitdb**: need their own build/large data stages.
  Placeholders.

These stay in the lock as `enabled: false` stanzas so the shape is recorded; they
are validated but never fetched.
