FROM golang as build

# go mod Installation source, container environment variable addition will override the default variable value
ENV GO111MODULE=on
ENV GOPROXY=https://goproxy.cn,direct

# Set up the working directory
WORKDIR /Open-IM-Server
# add all files to the container
COPY . .

WORKDIR /Open-IM-Server/script
RUN chmod +x *.sh

RUN /bin/sh  -x -c ./build_all_service.sh

#Blank image Multi-Stage Build
FROM ubuntu:focal
#RUN ls /etc/apt/trusted.gpg.d
#RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
#RUN apt-get update && apt-get install -y gpg
#RUN gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
#RUN apt-get update && apt-get install gpg
#RUN gpg --recv-keys 871920D1991BC93C
#RUN gpg --export 871920D1991BC93C| apt-key add -
#RUN rm -rf /var/lib/apt/lists/*
RUN sed -i -e 's/archive.ubuntu.com/mirrors.nhanhoa.com/g' /etc/apt/sources.list
RUN sed -i -e 's/security.ubuntu.com/mirrors.nhanhoa.com/g' /etc/apt/sources.list
RUN apt-get update && apt-get install -y wget zsh gpg
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.2/zsh-in-docker.sh)"
# RUN sed -i 's|http|https|g' /etc/apt/sources.list

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    g++ \
    gcc \
    libc6-dev \
    make \
    pkg-config \
    ; \
    rm -rf /var/lib/apt/lists/*

ENV PATH /usr/local/go/bin:$PATH

ENV GOLANG_VERSION 1.19beta1

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
    url=; \
    case "$arch" in \
    'amd64') \
    url='https://dl.google.com/go/go1.19beta1.linux-amd64.tar.gz'; \
    sha256='7d4df5bb5f94acf23edeb5a87f962696e6c6a2ea0b58280433deea79f9a231d3'; \
    ;; \
    'armel') \
    export GOARCH='arm' GOARM='5' GOOS='linux'; \
    ;; \
    'armhf') \
    url='https://dl.google.com/go/go1.19beta1.linux-armv6l.tar.gz'; \
    sha256='2406789dbcf6933a0e22e842aff1d05224ca4f9aba9be7190d55213428e5456f'; \
    ;; \
    'arm64') \
    url='https://dl.google.com/go/go1.19beta1.linux-arm64.tar.gz'; \
    sha256='b4dc2ddcc6e93488a8d23e155ba2a7501e754f5991289ecba33b3c5a52946bea'; \
    ;; \
    'i386') \
    url='https://dl.google.com/go/go1.19beta1.linux-386.tar.gz'; \
    sha256='554ec1024cf8b04b2f744ce7864787de3736995d71b8f181cf811f7af263b24e'; \
    ;; \
    'mips64el') \
    export GOARCH='mips64le' GOOS='linux'; \
    ;; \
    'ppc64el') \
    url='https://dl.google.com/go/go1.19beta1.linux-ppc64le.tar.gz'; \
    sha256='3111fc6ff05dbca7a3b993a155b5ae007f12a5345fce831c695236931ad2b773'; \
    ;; \
    's390x') \
    url='https://dl.google.com/go/go1.19beta1.linux-s390x.tar.gz'; \
    sha256='576720c8c0118b47ba4aa4cb4c8773c1148f69c6ae0334618f8fd8ace15e5b6e'; \
    ;; \
    *) echo >&2 "error: unsupported architecture '$arch' (likely packaging update needed)"; exit 1 ;; \
    esac; \
    build=; \
    if [ -z "$url" ]; then \
    # https://github.com/golang/go/issues/38536#issuecomment-616897960
    build=1; \
    url='https://dl.google.com/go/go1.19beta1.src.tar.gz'; \
    sha256='f463e5a5c25eebdea06d7ae3890c91de2f3795304e9fa350505804d826ec2683'; \
    echo >&2; \
    echo >&2 "warning: current architecture ($arch) does not have a compatible Go binary release; will be building from source"; \
    echo >&2; \
    fi; \
    \
    wget -O go.tgz.asc "$url.asc"; \
    wget -O go.tgz "$url" --progress=dot:giga; \
    echo "$sha256 *go.tgz" | sha256sum -c -; \
    \
    # https://github.com/golang/go/issues/14739#issuecomment-324767697
    GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
    # https://www.google.com/linuxrepositories/
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796'; \
    # let's also fetch the specific subkey of that key explicitly that we expect "go.tgz.asc" to be signed by, just to make sure we definitely have it
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys '2F52 8D36 D67B 69ED F998  D857 78BD 6547 3CB3 BD13'; \
    gpg --batch --verify go.tgz.asc go.tgz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" go.tgz.asc; \
    \
    tar -C /usr/local -xzf go.tgz; \
    rm go.tgz; \
    \
    if [ -n "$build" ]; then \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends golang-go; \
    \
    export GOCACHE='/tmp/gocache'; \
    \
    ( \
    cd /usr/local/go/src; \
    # set GOROOT_BOOTSTRAP + GOHOST* such that we can build Go successfully
    export GOROOT_BOOTSTRAP="$(go env GOROOT)" GOHOSTOS="$GOOS" GOHOSTARCH="$GOARCH"; \
    ./make.bash; \
    ); \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # remove a few intermediate / bootstrapping files the official binary release tarballs do not contain
    rm -rf \
    /usr/local/go/pkg/*/cmd \
    /usr/local/go/pkg/bootstrap \
    /usr/local/go/pkg/obj \
    /usr/local/go/pkg/tool/*/api \
    /usr/local/go/pkg/tool/*/go_bootstrap \
    /usr/local/go/src/cmd/dist/dist \
    "$GOCACHE" \
    ; \
    fi; \
    \
    go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"


RUN apt-get update && apt-get install apt-transport-https && apt-get install procps\
    &&apt-get install net-tools
#Non-interactive operation
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get install -y vim curl tzdata gawk
#Time zone adjusted to East eighth District
RUN ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && dpkg-reconfigure -f noninteractive tzdata


#set directory to map logs,config file,script file.
VOLUME ["/Open-IM-Server/logs","/Open-IM-Server/config","/Open-IM-Server/script","/Open-IM-Server/db/sdk"]

#Copy scripts files and binary files to the blank image
COPY --from=build /Open-IM-Server/script /Open-IM-Server/script
COPY --from=build /Open-IM-Server/bin /Open-IM-Server/bin

WORKDIR /Open-IM-Server/script
RUN go install github.com/cespare/reflex@latest && go install github.com/go-delve/delve/cmd/dlv@latest
CMD ["./docker_start_all.sh"]
