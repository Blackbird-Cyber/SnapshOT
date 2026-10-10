---
title: The vendor layer
summary: What /opt/snapshot is, how the vendored tools are wrapped and recorded, which tools are vendored, and which are defined but disabled.
---

Some tools SnapshOT needs are not in Debian at the version the image wants, or
need a runtime Debian ships only one of. Rather than install them against the
operating system's own interpreters, SnapshOT carries them in a **vendor layer**
under `/opt/snapshot`, each with its own pinned runtime. This page is the
operator's overview; the full mechanics are in the repository's
`docs/vendoring.md`, and the exact contents of a given image are in its
[build manifest](build-manifest.md).

## What /opt/snapshot is

Every non-apt tool lives under `/opt/snapshot/<tool>/` with its own pinned
runtime, so versions coexist and nothing a tool needs touches the operating
system's interpreters or `PATH`. The shared runtimes (a pinned CPython 3.11 for
the Python tools) live in `/opt/snapshot/runtimes/` and are read-only once
installed.

The **only** directory added to `PATH` is `/opt/snapshot/bin`, and it is
*appended*, so the operating system's own commands always win. Each entry there
is a wrapper that sets the tool's environment and execs the real program by
absolute path. A vendored tool is therefore reached by its bare name once it is
on `PATH`, or by its full path `/opt/snapshot/<tool>/bin/<cmd>`, which is what the
menu launchers use.

## How a vendored tool is recorded

Each runtime and tool carries a `MANIFEST` recording its name, version,
architecture, runtime, source URL, SHA-256 and license. Every manifest is also
copied to `/usr/share/snapshot/vendor/<name>.manifest`, and the build's manifest
hook folds that set, plus a listing of `/opt/snapshot/bin`, into
[`BUILD-MANIFEST.txt`](build-manifest.md). So the build manifest is the single
place that says exactly which vendored tools and runtimes an image contains.

Data that plugs into an operating-system tool is the one documented exception to
"a tool never writes outside its own dir": the
[Redpoint NSE](../tools/recon/redpoint-nse.md) scripts are symlinked into nmap's
script directory, as symlinks so their provenance stays visible.

!!! note "The vendor layer is a build-time choice"

    An image includes the vendor layer only when the one online fetch step ran
    before the build. A build without that step still produces a working image,
    just without these tools, and their launchers stay hidden. Check an image's
    [build manifest](build-manifest.md) to see what it actually carries.

## What is vendored

When the vendor layer is present, it provides:

- the **ICS Python tools**: pymodbus (with pyserial for serial Modbus),
  pycomm3, BACpypes3, BAC0, asyncua and python-snap7, with the OPC UA
  command-line tools (03 Protocol Tools);
- the **opcua-client** GUI (03 Protocol Tools, amd64 only: PyQt5 publishes no
  Linux aarch64 wheels);
- [**plcscan**](../tools/protocols/plcscan.md) (03 Protocol Tools);
- the [**Redpoint NSE**](../tools/recon/redpoint-nse.md) scripts (01 Recon &
  Discovery), symlinked into nmap.

## What is defined but disabled

Several tools are kept in the lock as disabled stanzas so their shape is
recorded, but are not fetched or installed. Each has a short "not shipped" page
explaining what it would add and why it is out of scope (from `docs/vendoring.md`,
"Out of scope and why"):

- [GRASSMARLIN](../tools/recon/grassmarlin.md): archived; Java 8 and JavaFX with
  an x86-only native library, unsupported on this image.
- [Zeek](../tools/traffic/zeek.md) with the CISA ICSNPP parsers: ships as an OBS
  `.deb` that pulls apt dependencies; a placeholder, with ICSNPP needing a
  working Zeek.
- [s7scan](../tools/protocols/s7scan.md): a Python 3 fork that would need scapy
  pinned in its own venv; not yet vendored.
- [Ghidra](../tools/firmware/ghidra.md): pinned but disabled. It is about
  435 MiB plus the JDK it runs on, which would push the amd64 image toward
  GitHub's 2 GiB release-asset limit.
- [firmware-mod-kit](../tools/firmware/firmware-mod-kit.md): needs its own build
  stage; a placeholder.
- [searchsploit / Exploit-DB](../tools/reference/exploitdb-searchsploit.md): a
  large offline dataset that needs its own data stage; a placeholder.

Arkime (full-packet capture) is also a disabled placeholder with no tool page.

## Libraries considered and dropped

Three Python packages were tried for the ICS Python tools and left out, because
the vendor layer installs only pinned wheels:

- **pydnp3**: published only as a source release, with no wheel; installing it
  would need a native build stage. DNP3 in a capture is decoded by
  [tshark](../tools/traffic/tshark.md) and
  [Wireshark](../tools/traffic/wireshark.md) instead.
- **cpppo**: every release pins a version of its greenery dependency that
  publishes no wheel. [pycomm3](../tools/protocols/pycomm3.md) covers
  EtherNet/IP.
- **pymodbus-repl** (the pymodbus console): its last release only runs with
  pymodbus 3.7.0 to 3.7.2, older than the pinned pymodbus.
  [mbpoll](../tools/protocols/mbpoll.md) is the interactive Modbus client, and
  the [pymodbus](../tools/protocols/pymodbus.md) library stays.

## Related pages

- [Build manifest](build-manifest.md): the record of exactly which vendored
  tools and runtimes an image contains.
- [Architectures](architectures.md): which vendored tools are amd64 only and why.
- [Field updates](field-updates.md): re-imaging to change the toolset.
