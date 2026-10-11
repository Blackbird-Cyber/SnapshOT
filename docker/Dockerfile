# SnapshOT build container. The base is pinned by digest for a reproducible
# builder: the multi-arch index digest, so linux/amd64 and linux/arm64 both
# resolve.
# Tag debian:trixie-slim, the images built 2026-09-18; pinned 2026-10-10 from
# the locally cached tag. Checked 2026-10-11 with `docker buildx imagetools
# inspect`: an OCI image index for linux/amd64, linux/arm64/v8 and six other
# platforms, every image labeled trixie-slim. Docker Hub's tag has moved to a
# newer build since. To move the pin, read the index digest from the registry,
# not from a cached pull: `docker buildx imagetools inspect debian:trixie-slim`.
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
