# SnapshOT build container. Pin the base by digest for a reproducible builder.
# TODO(release): replace the tag with a digest, e.g.
#   FROM debian@sha256:<digest>
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        live-build debootstrap \
        dpkg-dev debhelper build-essential \
        xorriso squashfs-tools \
        python3 python3-pip pipx \
        aptly diffoscope \
        ca-certificates git sudo faketime rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /snapshot
ENTRYPOINT ["/bin/bash"]
