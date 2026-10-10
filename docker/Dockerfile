# SnapshOT build container. The base is pinned by digest for a reproducible
# builder: debian:trixie-slim as of 2026-10-10 (the multi-arch index digest, so
# linux/amd64 and linux/arm64 both resolve). To move the pin, pull the tag and
# take `docker image inspect debian:trixie-slim --format '{{index .RepoDigests 0}}'`.
FROM debian@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a

ENV DEBIAN_FRONTEND=noninteractive
# mkdocs-material, python3-pymdownx and python3-yaml are snapshot-wiki's
# Build-Depends: dpkg-buildpackage builds the wiki in this container.
RUN apt-get update && apt-get install -y --no-install-recommends \
        live-build debootstrap \
        dpkg-dev debhelper build-essential \
        xorriso squashfs-tools \
        python3 python3-pip pipx \
        aptly diffoscope \
        ca-certificates git sudo faketime rsync \
        mkdocs-material python3-pymdownx python3-yaml \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /snapshot
ENTRYPOINT ["/bin/bash"]
