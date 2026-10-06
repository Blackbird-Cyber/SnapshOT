user-supplied (Linux)
=====================

SnapshOT ships no third-party tools. If you want static helper binaries on
the stick (for example a static busybox for hosts with a crippled userland),
put them here. collect-triage.sh lists this folder in user-supplied.txt but
runs nothing from it: run such tools by hand, with output under results/.

Sticks are often mounted noexec: start tools with "sh <script>" or copy a
binary to a tmpfs only when you accept that footprint.
