# Debian-based variant of the goclaw skeleton
#
# Alpine-based image (../goclaw/Dockerfile) is the primary target. This
# directory holds a Debian bookworm-slim variant for users who need a
# glibc base (e.g. some Python wheels, some node-gyp modules).
#
# Strategy: keep the image as small as possible. Same package set as the
# Alpine variant (ca-certificates, sudo, curl), but with apt instead of apk.
# No bash, no git baked in — opt in via the lazy shims (add-bash, add-git).

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        sudo \
        curl && \
    rm -rf /var/lib/apt/lists/*

COPY ./ROOT /

ENTRYPOINT [ "/entrypoint.sh" ]
