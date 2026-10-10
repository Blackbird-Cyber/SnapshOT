#!/usr/bin/env bash
# Provenance check for the SnapshOT repository: no attribution trailers or
# "generated with" lines in commit messages, and no embedded manifests or EXIF
# chunks in tracked PNG files. Runs on tracked files and, when given a commit
# range, on the messages of those commits.
#
#   scripts/check-provenance.sh                # tracked files only
#   scripts/check-provenance.sh origin/main..HEAD   # plus the commit messages in the range
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
bad=0

if [ "${1:-}" != "" ]; then
    msgs=$(git log --format='%H%x09%s%n%b' "$1" || true)
    if printf '%s\n' "$msgs" | grep -qiE '^Co-Authored-By:|Generated with'; then
        echo "ERROR commit messages in $1 carry attribution lines:" >&2
        printf '%s\n' "$msgs" | grep -niE '^Co-Authored-By:|Generated with' >&2
        bad=1
    else
        echo "ok   commit messages in $1 carry no attribution lines"
    fi
fi

while IFS= read -r f; do
    if grep -a -qE 'caBX|eXIf' "$f"; then
        echo "ERROR $f carries an embedded manifest or EXIF chunk" >&2; bad=1
    fi
done < <(git ls-files '*.png')
[ "$bad" = 0 ] && echo "ok   tracked PNG files carry no embedded manifests"

if git grep -qiE 'Generated with [A-Za-z]|^Co-Authored-By:' -- . ':!scripts/check-provenance.sh'; then
    echo "ERROR tracked files carry attribution text:" >&2
    git grep -niE 'Generated with [A-Za-z]|^Co-Authored-By:' -- . ':!scripts/check-provenance.sh' >&2; bad=1
else
    echo "ok   tracked files carry no attribution text"
fi

[ "$bad" = 0 ] && echo "== check-provenance: OK ==" || { echo "== check-provenance: FAIL ==" >&2; exit 1; }
