---
title: KeePassXC
summary: Community-driven port of the Windows application “KeePass Password Safe”
folder: reporting
launchers: [org.keepassxc.KeePassXC.desktop]
ships_as: upstream-gui
package: keepassxc
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Create one database per client in the case folder and store the accounts the site issues for the engagement.
  lessons-learned: List the accounts used for the report, ask the site to change them, and retire the database with the case.
csf: [protect, govern]
attack_ics: []
attack_role: none
upstream: https://keepassxc.org/docs/
---

<!-- snapshot:facts -->

## What it is

KeePassXC is an offline password manager. It keeps entries (user name,
password, URL, notes, attachments, one-time password seeds) in a single
encrypted KDBX database file, unlocked with a password and optionally a key file
or a hardware key. It generates passwords and passphrases, can type an entry
into another window (Auto-Type) or copy it to the clipboard for a short time,
and has a command-line client, `keepassxc-cli`, for the same database. In
trixie, `keepassxc` is a transitional package; it installs `keepassxc-full`,
the build with every feature, including the browser integration and icon
download the image leaves unused.

## Why it is on SnapshOT

An engagement collects secrets: accounts the site issues for an HMI or a
switch, the passphrase of an encrypted evidence archive, the password of a
protected notes file. KeePassXC is the image's one place for them. Firefox's own
password manager is turned off by the image's policy for that reason (see
[the browser](../../platform/browser.md)), so device web logins are kept here
too. One database per client, in that client's case folder, means the
credentials are archived or destroyed together with the rest of the case.

## On the wire

!!! note "Passive: it never transmits"

    KeePassXC works on a local file and needs no network.

    - **Leave network features unused**, such as downloading website icons for
      entries: nothing about the client's devices should leave the laptop.
    - **Auto-Type types into whatever window has focus.** Check the window
      before using it, especially with a device's login page or a remote session
      open: a password typed into the wrong field is disclosed.
    - **A credential is not an authorization.** Holding an account for a
      controller or HMI does not mean you may log in now; the [rules of
      engagement](../../lifecycle/rules-of-engagement.md) and the engineer for
      that device decide.
    - **Lock it when you step away**, and keep the master password out of the
      notes and off the laptop.

## PICERL mapping

### Preparation

During [preparation](../../lifecycle/phases/preparation.md), create the client's
database in the case folder with a strong master password, one group per zone
or device type, and an entry for every account the site issues, with a note of
who issued it, for what and until when. Generate the passphrases for evidence
archives here too.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), list the
accounts used during the engagement for the report and the handover note, so the
site can change or disable each one. Default or shared credentials found on
devices are findings for the report (Insecure Credentials, T1694), not only
entries in the database. When the case is closed and its retention agreed, the
database goes with it; see the [reporting
handover](../../lifecycle/playbooks/reporting-handover.md) playbook.

## MITRE ATT&CK for ICS mapping

KeePassXC has no ATT&CK for ICS mapping: it stores the team's credentials and
neither detects nor investigates adversary activity. As context only: the
accounts a site issues for an engagement are exactly what an adversary would
use as Valid Accounts, so keeping them in one encrypted file, rather than in
notes, screenshots or browser storage, is a protective habit, not a detection.

## Quick start

The command-line client works on a database created in the application (the
steps after the commands).

```sh
# What the menu launcher runs
keepassxc
# Open the engagement's database
keepassxc ~/cases/site-a/site-a.kdbx
# Add a group for the HMIs (asks for the database password)
keepassxc-cli mkdir ~/cases/site-a/site-a.kdbx HMI
# Add a site-issued account; asks for the database and the entry password
keepassxc-cli add -u engineer --url https://192.0.2.10 -p \
    ~/cases/site-a/site-a.kdbx HMI/hmi01
# List every entry
keepassxc-cli ls -R ~/cases/site-a/site-a.kdbx
# Show an entry; the password stays hidden unless you add -s
keepassxc-cli show ~/cases/site-a/site-a.kdbx HMI/hmi01
# A 24-character password from all four character classes
keepassxc-cli generate -L 24 -l -U -n -s
# A six-word passphrase, for an evidence archive
keepassxc-cli diceware -W 6
```

The database is created once, in the application:

1. **Start it.** Open KeePassXC from 07 Reporting & Documentation.
2. **Create the database.** **Database > New Database** opens a short wizard.
   Under **General Database Information**, name it after the case; leave the
   **Encryption Settings** at their defaults; under **Database Credentials**,
   set a long passphrase (`keepassxc-cli diceware -W 6` makes one). Save it as
   `~/cases/site-a/site-a.kdbx`.
3. **Make groups.** **Groups > New Group** for each kind of device (HMI, PLC,
   Network), so the entries stay sorted.
4. **Add an entry.** Select a group and use **Entries > New Entry** (the
   toolbar's add button does the same). Fill in a title that names the device
   and host, the user name, the password, the URL (`https://192.0.2.10`) and,
   in the notes, who issued the account and when it expires. The generator
   button beside the password field makes a strong one; **Tools > Password
   Generator** works on its own as well.
5. **Use an entry.** Select it and use **Copy Username** and **Copy Password**
   from the Entries menu (or the right-click menu), then paste into the
   device's login page in Firefox. KeePassXC clears the clipboard again after
   a short time.
6. **Lock it.** **Database > Lock Database** whenever you step away, and in
   **Tools > Settings**, on the **Security** page, set **Lock databases after
   inactivity of** a few minutes.

## Output and evidence

The database is a single file in the case folder. Hash it when the engagement
closes so the archived copy can be checked, and never put it, or anything from
it, in the report:

```sh
CASE=~/cases/site-a
sha256sum "$CASE/site-a.kdbx" >> "$CASE/SHA256SUMS"
```

When the client's retention period ends, the database is destroyed with the
case, and the media it lived on are wiped with [nwipe](nwipe.md). See [evidence
handling](../../lifecycle/evidence-handling.md).

## Related tools

- [CherryTree](cherrytree.md): the notes, which refer to an entry by name
  instead of holding the secret.
- [nwipe](nwipe.md): wiping the media at the end of the case.
- Firefox ESR ([the browser](../../platform/browser.md)): its password manager
  is off, so device web logins come from here.

## Upstream documentation

- [KeePassXC documentation](https://keepassxc.org/docs/): the user guide,
  getting started and the `keepassxc-cli` reference.
