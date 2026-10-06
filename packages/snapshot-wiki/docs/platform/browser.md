---
title: Firefox ESR, locked down
summary: What the Firefox enterprise policy turns off so the browser never calls home, and what that costs.
---

Firefox ESR is on the image to show this wiki and to reach the web interfaces of
PLCs, HMIs and switches on an engagement. By default a browser is one of the
chattiest programs on a machine, so SnapshOT holds it quiet with an enterprise
policy. The authoritative detail is in the repository's `docs/wiki.md` ("Firefox
ESR"); this is the operator's summary.

## What the lockdown does

`/etc/firefox/policies/policies.json` is the enterprise policy Debian's
firefox-esr reads (confirmed with `about:policies`; the `/etc/firefox-esr/policies/`
path is **not** read). It turns off, among other things:

- telemetry, studies and Nimbus rollouts;
- Remote Settings, and application and extension updates;
- Firefox accounts and push;
- DNS over HTTPS, captive-portal and connectivity checks, prefetching and
  speculative connections;
- Safe Browsing;
- search suggestions and sponsored and new-tab content;
- the password manager ([KeePassXC](../tools/reporting/keepassxc.md) is the
  credential store on the image).

It sets this wiki as the home page. **JavaScript and `file://` stay on**: the
wiki needs both. A few preferences the policy engine refuses to set ("not allowed
for stability reasons": the `toolkit.telemetry.*` keys, Normandy and the health
report) are set instead in `/etc/firefox-esr/snapshot-quiet.js`, which Debian's
firefox-esr reads alongside its own defaults.

The repository's `scripts/check-firefox-quiet.sh` proves the result: no packet
leaves the machine while Firefox shows the wiki.

## What it costs

Turning off Remote Settings means Firefox **does not receive certificate
revocation and intermediate updates, add-on blocklists, or updated search and
security lists**. Safe Browsing is off, so the browser does not check sites or
downloads against Google's lists. The password manager is off, so credentials
live in KeePassXC, not the browser. These are the price of a browser that never
calls home, and they are acceptable because the image is **re-imaged rather than
updated in place**: a drifted browser is replaced with a fresh image, not patched
online. See [field updates](field-updates.md).

## Why it is the default browser

The wiki and HTML links open in firefox-esr through a deliberate chain: the
launcher runs `exo-open --launch WebBrowser`, which reads
`/etc/xdg/xfce4/helpers.rc` (`WebBrowser=debian-sensible-browser`; the file is a
link to SnapshOT's copy, with xfce4-helpers' own diverted aside), and
`debian-sensible-browser` runs `sensible-browser`, which runs `x-www-browser`,
the alternative firefox-esr registers. `/etc/xdg/mimeapps.list`
sends HTML and http(s) links to `firefox-esr.desktop`. The stock Firefox helper
cannot be used because its binary list does not include `firefox-esr`.

## Related pages

- [Quiet network defaults](network-defaults.md): the system-level side of the
  same posture.
- [Field updates](field-updates.md): why a never-updated browser is acceptable.
- [Using this wiki](using-this-wiki.md): opening and searching the wiki in this
  browser.
