// SnapshOT: keep Firefox ESR quiet on the wire (shipped by snapshot-wiki).
//
// Debian's firefox-esr reads every *.js in /etc/firefox-esr as system
// preferences (browser/defaults/syspref is a symlink to this directory).
// /etc/firefox/policies/policies.json does most of the work; these are the
// preferences its "Preferences" policy refuses ("not allowed for stability
// reasons"), so they are set here instead. Debian's own firefox-esr.js in this
// directory is left untouched.
//
// Verified with scripts/check-firefox-quiet.sh: no packet leaves the machine
// while Firefox shows the wiki.

// Telemetry and health reports (DisableTelemetry covers most of these too).
pref("toolkit.telemetry.enabled", false, locked);
pref("toolkit.telemetry.unified", false, locked);
pref("toolkit.telemetry.archive.enabled", false, locked);
pref("toolkit.telemetry.server", "", locked);
pref("datareporting.healthreport.uploadEnabled", false, locked);

// Normandy / Shield studies (DisableFirefoxStudies covers the UI).
pref("app.normandy.enabled", false, locked);
pref("app.normandy.api_url", "", locked);
pref("app.shield.optoutstudies.enabled", false, locked);

// Remote Settings (blocklists, certificate data, search configuration and the
// Nimbus rollouts that ride on it). The pinned Firefox ESR 140 has no policy
// for it: DisableRemoteSettingsAndAcceptSecurityConsequences and
// DisableRemoteImprovements arrive in a later ESR, and 140 reports them as
// unknown policies. Release builds ignore a services.settings.server override,
// so its three hosts resolve to loopback inside Firefox instead and no DNS
// query or connection leaves the machine. Without this, a new profile on ESR
// 140 contacts firefox.settings.services.mozilla.com within seconds of
// starting (found with scripts/check-firefox-quiet.sh against the pinned
// firefox-esr). The two prefs below keep its certificate consumers from asking.
pref("network.dns.localDomains", "firefox.settings.services.mozilla.com,firefox-settings-attachments.cdn.mozilla.net,content-signature-2.cdn.mozilla.net", locked);
pref("security.remote_settings.crlite_filters.enabled", false, locked);
pref("security.remote_settings.intermediates.enabled", false, locked);
