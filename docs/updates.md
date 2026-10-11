# Updating SnapshOT in the field

Primary model: **re-image**. Build a new release ISO, wipe, reinstall. This also
clears prior-client data: the reset between engagements.

Secondary model: a signed offline apt repository on a USB stick for adding a
package without a full re-image. Build it on a networked Debian host with aptly,
gnupg and debian-archive-keyring installed, as the user whose GnuPG keyring holds
the signing key (no root needed):
```
scripts/make-update-usb.sh /media/<user>/<stick> <package>...
```
`scripts/make-update-usb.sh --help` lists the options. What the script does:

- It mirrors `trixie main` from the snapshot pin in `config/snapshot.env` and
  nothing else: no `trixie-security` or `trixie-updates` suite and no other
  component. It checks the snapshot's `Release` signature against
  debian-archive-keyring.
- It downloads and keeps only the named packages (aptly package queries, usually
  plain names). The filter runs without `-with-deps`, so a package whose
  dependencies are not already on the laptop needs them named too. A named
  package that is not in `trixie main` at the pin stops the script.
- With no package named, it keeps all of `trixie main`. At the 2026-09-01 pin
  that is 103,210 files and 154.5 GiB for amd64 and arm64 together (110.8 GiB
  for amd64 alone), downloaded once into the work directory and copied once to
  the stick: plan on 160 GiB free on the host, a 256 GB stick and hours of
  download. The largest file is 2.96 GiB, so a FAT32 stick works.
- The repository carries both image architectures, amd64 and arm64, so one stick
  serves every SnapshOT laptop; apt on the laptop fetches only its own
  architecture's index. Set `SNAPSHOT_UPDATE_ARCHES` to narrow it, for example
  `SNAPSHOT_UPDATE_ARCHES=amd64` when no arm64 laptop is in the field.
- It signs the repository with the key named in `SNAPSHOT_GPG_KEY` (a key ID,
  fingerprint or user ID), or with gpg's default key when that is unset, and
  publishes it to `snapshot-cache/` on the stick. It then checks the signature
  with `gpgv` against that key's public half alone, and prints the key's
  fingerprint and the laptop-side commands below.
- It refuses to start without a stick path, without aptly, gpg, gpgv or
  debian-archive-keyring, without a secret key to sign with, or when
  `snapshot-cache/` on the stick already holds files.

aptly 1.6 (trixie) publishes to a local directory only through a filesystem
endpoint in its config file, so the script writes a config of its own and does
not read `~/.aptly.conf` or touch `~/.aptly`. Its work directory (aptly's config,
database and downloaded packages) is made under `$TMPDIR`, default `/var/tmp`
(on a new trixie install `/tmp` is a tmpfs, held in RAM), and removed when the script exits. Set
`SNAPSHOT_UPDATE_POOL` to a directory to keep the downloaded packages between
runs: a re-run, or a large run that was interrupted, then downloads only what is
missing. The endpoint copies files to the stick (`linkMethod: copy`), because FAT
and exFAT take neither hard links nor symlinks. The repository has no `Contents`
indexes; apt does not read them.

## The signing key

No signing key ships in the tree or on the image, and the script never creates
one. Create it once on the build host and keep it there:
```
gpg --quick-gen-key "SnapshOT updates (<your organization>)" ed25519 sign 2y
```
apt in trixie checks signatures with Sequoia's `sqv`, which rejects weak keys
and SHA-1 signatures; ed25519, or RSA of 3072 bits or more, is fine. Renew the
key before it expires (`gpg --quick-set-expire`) and give the laptops the renewed
public key.

## On the laptop

Never trust an unsigned repository, and never add `[trusted=yes]`. Give each
laptop the public key once, by a channel other than the stick it is meant to
check:
```
gpg --export <fingerprint> > snapshot-update.gpg                         # build host
sudo install -D -m 0644 snapshot-update.gpg /etc/apt/keyrings/snapshot-update.gpg   # laptop
```
Then, with the stick mounted (the desktop mounts it at `/media/<user>/<label>`; a
label without spaces keeps the path simple), add a `sources.list.d` entry that
trusts only that key, install, and remove the entry:
```
echo 'deb [signed-by=/etc/apt/keyrings/snapshot-update.gpg] file:/media/<user>/<label>/snapshot-cache trixie main' \
  | sudo tee /etc/apt/sources.list.d/snapshot-update.list
sudo apt-get update
sudo apt-get install <package>...
sudo rm /etc/apt/sources.list.d/snapshot-update.list
```
While the entry points at a stick that is not mounted, `apt-get update` fails
with "no longer has a Release file".

## Testing the script

To try the script without a stick or a large download, pass an empty directory
and two or three small packages; only those are downloaded. A throwaway key in a
scratch keyring keeps your own keyring out of it:
```
export GNUPGHOME="$(mktemp -d)"
gpg --batch --passphrase '' --quick-gen-key "update stick test" ed25519 sign 1d
scripts/make-update-usb.sh "$(mktemp -d)" hello jq libjq1 libonig5
```
The fix for trixie's aptly was verified this way in `debian:trixie` containers on
amd64 and arm64: repositories built into a directory and onto FAT32 and exFAT
images, then mounted read-only in a clean container that had only the public key
in `/etc/apt/keyrings`. `apt-get update` passed signature verification with no
warnings, `apt-get install` took `jq`, `hello` and `bash-completion`
(Architecture: all) from the `file:` source, and `apt-cache policy` showed that
source. With the wrong key, an edited `InRelease`, an edited `Release` (with
`InRelease` removed) or an edited `Packages` index, `apt-get update` failed and
nothing installed; an edited `.deb` failed `apt-get install` with a hash
mismatch.
