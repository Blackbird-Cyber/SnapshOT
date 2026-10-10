# Security policy

## Reporting a vulnerability

Report a vulnerability through GitHub's private vulnerability reporting:
open the repository's **Security** tab and choose **Report a vulnerability**, or
go straight to the
[new advisory form](https://github.com/Blackbird-Cyber/SnapshOT/security/advisories/new).
Do not open a public issue for a vulnerability.

Include the image version and architecture (`cat /etc/snapshot-release`), whether
the system was live or installed, and the steps that show the problem. The
maintainers reply in the advisory and coordinate any fix and disclosure there.

## Scope

In scope: what this repository builds and ships.

- the SnapshOT image configuration: package lists, hooks, network defaults,
  the sudo and capture setup, the installer configuration;
- SnapshOT's own packages (`snapshot-*` and `calamares-settings-snapshot`),
  including the field kit collectors and the Firefox ESR policy;
- the scripts in `scripts/` and the vendor layer's fetch, pinning and install
  steps.

Out of scope: vulnerabilities in the Debian packages and third-party tools that
the image carries. Report those upstream, to Debian or to the tool's project. If
SnapshOT's configuration makes an upstream problem worse, that part is in scope.

## Use

SnapshOT is a platform for authorized OT engagements. Testing a report against
systems you do not own or have no permission to test is not covered by this
policy.

There is no bug bounty.
