# History rewrite of 2026-10-10

The repository's history was rewritten once, on 2026-10-10, after v0.2.0 was
published and before the repository goes public. Every commit hash changed.
What changed in the commits:

- the attribution trailer that most commit messages carried was removed;
- the commits made through the GitHub web editor, which carried a work mailbox
  as the author address, now carry the same GitHub noreply identity as the rest;
- the brand PNG files in every historical commit had their embedded
  content-credential and EXIF chunks removed, the same change that the current
  files received; pixels are unchanged.

Nothing else changed: file contents, trees, dates and the order of commits are
the same, and the two release tags of the time were re-created on the rewritten commits.
Both were later withdrawn in favor of v0.2.1, which was built from the rewritten
history.

| Commit before | Commit after | What it is |
|---|---|---|
| 2fba3d1 | 88ba816 | v0.1.0 build commit |
| 290c2eb | a4d0da9 | v0.1.0 tag target; the tag and its release were withdrawn on 2026-10-10 |
| 3a77bad | 5150f10 | v0.2.0 build commit; the images' `/etc/snapshot-release` records `3a77bad` |
| a3d7d25 | 8193eab | v0.2.0 tag target; the tag and its release were withdrawn on 2026-10-10 |
| e2af6a6 | 2637f9d | last commit before the rewrite |

[`commit-map-2026-10-10.txt`](commit-map-2026-10-10.txt) maps every old hash
to its new one (old first, new second, one pair per line). A full backup of the
pre-rewrite repository is kept outside the repository as a git bundle on the
build Mac (`SnapshOT-pre-rewrite-2026-10-10.bundle`, beside the checkout).

GitHub keeps a branch ref for each pull request, which would have kept the ten
merged pull requests' original commits reachable. The repository was therefore
recreated from the rewritten history on the same day, with only `main`, the two
tags and the two releases; the pull request history ended with the old
repository. See the "Before going public" note in [status.md](status.md).
