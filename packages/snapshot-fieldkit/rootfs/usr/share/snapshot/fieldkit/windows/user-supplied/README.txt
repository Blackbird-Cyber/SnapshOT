user-supplied (Windows)
=======================

SnapshOT ships no third-party collectors: the Sysinternals and KAPE licenses
do not allow redistribution. Download them yourself from Microsoft and Kroll
on a trusted machine, check their signatures, and copy them here.

Used automatically when present, in the full profile only:

    autorunsc.exe / autorunsc64.exe
        Run as: autorunsc -accepteula -nobanner -a * -c -h
        Output: results\<HOST>_<STAMP>\autoruns.csv
    sigcheck.exe / sigcheck64.exe
        Run on each running binary as: sigcheck -accepteula -nobanner -c -h <file>
        Output: results\<HOST>_<STAMP>\sigcheck.csv

Footprint: -accepteula writes the EulaAccepted value under
HKCU\Software\Sysinternals\<tool> on the target. The collector logs it in
run.log. Signature checks may try to fetch certificate revocation lists if
the host has a network route; leave these tools out on hosts where that
matters.

Listed but not run:

    kape.exe / gkape.exe
        KAPE needs targets and modules chosen for the case; run it by hand,
        with its output on this stick, after the SnapshOT collector.

Anything else here is listed in user-supplied.txt and left alone. The quick
profile lists this folder only. The cmd fallback never runs these tools.
