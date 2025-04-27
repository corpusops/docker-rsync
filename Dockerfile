# Largely inspired by hattps://github.com/awesome-containers:
# - https://github.com/awesome-containers/alpine-build-essential
# - https://github.com/awesome-containers/static-bash
# - https://github.com/awesome-containers/static-rsync

ARG ALPINE_VERSION=latest
ARG BUILD_ESSENTIAL_VERSION=3.17
ARG BASH_VERSION=5.2.15
FROM docker.io/alpine:$ALPINE_VERSION AS build
# hadolint ignore=DL3018
RUN apk add --no-cache \
        alpine-sdk \
        autoconf \
        automake \
        curl \
        bash \
        bind-tools \
        bison \
        coreutils \
        file \
        findutils \
        gettext \
        gettext-dev \
        gperf \
        jq \
        rsync \
        texinfo \
        wget \
        xz
# https://github.com/upx/upx
ARG UPX_VERSION=4.0.2
RUN set -xeu; \
    curl -#Lo upx.tar.xz \
        "https://github.com/upx/upx/releases/download/v$UPX_VERSION/upx-$UPX_VERSION-amd64_linux.tar.xz"; \
    tar -xvf upx.tar.xz --strip-components=1 "upx-$UPX_VERSION-amd64_linux/upx"; \
    chmod +x upx; \
    mv upx /usr/local/bin/upx; \
    rm -f upx.tar.xz

#
# BASH
#
FROM build AS bash-build
ARG BASH_VERSION=5.2.15
WORKDIR /src/bash
RUN set -xeu; \
    curl -#Lo bash.tar.gz \
        "https://ftp.gnu.org/gnu/bash/bash-$BASH_VERSION.tar.gz"; \
    tar -xvf bash.tar.gz --strip-components=1; \
    rm -f bash.tar.gz
COPY bash-patches/ .
RUN set -xeu; \
    patch configure < configure.patch; \
    patch m4/strtoimax.m4 < m4_strtoimax.patch
ARG CFLAGS="-Wno-parentheses -Wno-format-security -w -g -Os -static"
RUN set -xeu; \
    autoconf -f; \
    ./configure --without-bash-malloc; \
    make -j"$(nproc)"; \
    # make tests; \
    strip -s -R .comment --strip-unneeded bash; \
    chmod -cR 755 bash; \
    chown -cR 0:0 bash; \
    ! ldd bash && :; \
    ./bash --version

#
# RSYNC
#
FROM build AS rsync-build
RUN apk add --no-cache acl-dev acl-static attr-dev attr-static lz4-static lz4-dev zstd zstd-dev zstd-static openssl-dev openssl-libs-static perl popt-dev popt-static zlib-dev
# https://github.com/WayneD/rsync & https://rsync.samba.org/download.html
ARG RSYNC_VERSION=3.2.7
WORKDIR /src/rsync
RUN set -xeu; \
    curl -#Lo rsync.tar.gz \
        "https://download.samba.org/pub/rsync/src/rsync-$RSYNC_VERSION.tar.gz"; \
    tar -xvf rsync.tar.gz --strip-components=1; \
    rm -f rsync.tar.gz
ARG CFLAGS='-w -g -Os -static -flto=auto'
ARG LDFLAGS=''
RUN set -xeu; \
    ./configure --disable-xxhash; \
    make -j"$(nproc)"; \
    strip -s -R .comment --strip-unneeded rsync; \
    chmod -cR 755 rsync; \
    chown -cR 0:0 rsync; \
    ! ldd rsync && :; \
    ./rsync -V; \
    sed '1 s|!/.*|!/bin/bash|' -i rsync-ssl

##
## static bash+rsync image
##
FROM busybox:stable-musl AS bbox
FROM scratch AS final
COPY --from=bash-build  /src/bash/bash /bin/bash
COPY --from=bbox /bin/busybox /bin/
COPY --from=rsync-build /src/rsync/rsync /src/rsync/rsync-ssl /bin/
ENTRYPOINT ["/bin/bash"]
