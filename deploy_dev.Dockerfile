FROM golang:1.18.3-buster as build

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

ENV GOLANG_VERSION 1.18.3

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
    url=; \
    case "$arch" in \
    'amd64') \
    url='https://dl.google.com/go/go1.18.3.linux-amd64.tar.gz'; \
    sha256='956f8507b302ab0bb747613695cdae10af99bbd39a90cae522b7c0302cc27245'; \
    ;; \
    'armel') \
    export GOARCH='arm' GOARM='5' GOOS='linux'; \
    ;; \
    'armhf') \
    url='https://dl.google.com/go/go1.18.3.linux-armv6l.tar.gz'; \
    sha256='b8f0b5db24114388d5dcba7ca0698510ea05228b0402fcbeb0881f74ae9cb83b'; \
    ;; \
    'arm64') \
    url='https://dl.google.com/go/go1.18.3.linux-arm64.tar.gz'; \
    sha256='beacbe1441bee4d7978b900136d1d6a71d150f0a9bb77e9d50c822065623a35a'; \
    ;; \
    'i386') \
    url='https://dl.google.com/go/go1.18.3.linux-386.tar.gz'; \
    sha256='72b73da021397a3a1ce182c19d2a890a5346bfe80885d9dd7d1ff04ce6597938'; \
    ;; \
    'mips64el') \
    export GOARCH='mips64le' GOOS='linux'; \
    ;; \
    'ppc64el') \
    url='https://dl.google.com/go/go1.18.3.linux-ppc64le.tar.gz'; \
    sha256='5d42bd252e7af9f854df92e46bb2e88be7b2fb310cc937c0fe091afd8c4f2016'; \
    ;; \
    's390x') \
    url='https://dl.google.com/go/go1.18.3.linux-s390x.tar.gz'; \
    sha256='ebb4efddec5bbd22bdd9c87137cb3dd59e874b5dfcf93d00bef351c60d2c7401'; \
    ;; \
    *) echo >&2 "error: unsupported architecture '$arch' (likely packaging update needed)"; exit 1 ;; \
    esac; \
    build=; \
    if [ -z "$url" ]; then \
    # https://github.com/golang/go/issues/38536#issuecomment-616897960
    build=1; \
    url='https://dl.google.com/go/go1.18.3.src.tar.gz'; \
    sha256='0012386ddcbb5f3350e407c679923811dbd283fcdc421724931614a842ecbc2d'; \
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
