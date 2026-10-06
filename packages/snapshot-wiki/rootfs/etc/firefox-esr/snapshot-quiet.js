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

// Remote Settings: Firefox otherwise fetches its startup bundle and polls for
// changes. The data: URL is what Mozilla's own test profiles use to keep a
// browser off the network.
pref("services.settings.server", "data:,#remote-settings-dummy/v1", locked);

// Certificate revocation lists and intermediates arrive through Remote Settings.
pref("security.remote_settings.crlite_filters.enabled", false, locked);
pref("security.remote_settings.intermediates.enabled", false, locked);
