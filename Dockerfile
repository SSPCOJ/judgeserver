FROM debian:trixie-slim AS builder
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-1-${TARGETARCH}${TARGETVARIANT}-builder,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-cache-2-${TARGETARCH}${TARGETVARIANT}-builder,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "1";' > /etc/apt/apt.conf.d/keep-cache && \
    echo 'APT::Install-Recommends "0";' > /etc/apt/apt.conf.d/no-recommends && \
    echo 'APT::AutoRemove::RecommendsImportant "0";' >> /etc/apt/apt.conf.d/no-recommends && \
    apt-get update && \
    apt-get install -y libtool make cmake libseccomp-dev gcc python3 python3-venv

COPY Judger/ /app/
RUN mkdir /app/build && \
    cmake -S . -B build && \
    cmake --build build --parallel $(nproc)

RUN cd bindings/Python && \
    python3 -m venv .venv && \
    .venv/bin/pip3 install build && \
    .venv/bin/python3 -m build -w

FROM debian:trixie-slim
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

RUN apt-get update && apt-get install -y locales && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen

RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-1-${TARGETARCH}${TARGETVARIANT}-final,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-cache-2-${TARGETARCH}${TARGETVARIANT}-final,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "1";' > /etc/apt/apt.conf.d/keep-cache && \
    echo 'APT::Install-Recommends "0";' > /etc/apt/apt.conf.d/no-recommends && \
    echo 'APT::AutoRemove::RecommendsImportant "0";' >> /etc/apt/apt.conf.d/no-recommends && \
    needed="python3 pypy3 python3-venv libpython3-stdlib libpython3-dev golang temurin-21-jdk gcc-14 g++-14 nodejs strace" && \
    savedAptMark="$(apt-mark showmanual) $needed" && \
    apt-get update && \
    apt-get install -y ca-certificates curl gnupg && \
    curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "Types: deb" > /etc/apt/sources.list.d/adoptium.sources && \
    echo "URIs: https://packages.adoptium.net/artifactory/deb" >> /etc/apt/sources.list.d/adoptium.sources && \
    echo "Suites: bookworm" >> /etc/apt/sources.list.d/adoptium.sources && \
    echo "Components: main" >> /etc/apt/sources.list.d/adoptium.sources && \
    echo "Signed-By: /etc/apt/keyrings/adoptium.gpg" >> /etc/apt/sources.list.d/adoptium.sources && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "Types: deb" > /etc/apt/sources.list.d/nodesource.sources && \
    echo "URIs: https://deb.nodesource.com/node_20.x" >> /etc/apt/sources.list.d/nodesource.sources && \
    echo "Suites: nodistro" >> /etc/apt/sources.list.d/nodesource.sources && \
    echo "Components: main" >> /etc/apt/sources.list.d/nodesource.sources && \
    echo "Signed-By:/etc/apt/keyrings/nodesource.gpg" >> /etc/apt/sources.list.d/nodesource.sources && \
    apt-get update && \
    apt-get install -y $needed && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 14 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 14 && \
    # update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 12 && \
    # update-alternatives --install /usr/bin/go go /usr/lib/go-1.22/bin/go 22 && \
    rm -rf /usr/lib/jvm/temurin-21-jdk-*/jmods && \
    rm -rf /usr/lib/jvm/temurin-21-jdk-*/lib/src.zip && \
    apt-mark auto '.*' > /dev/null && \
    apt-mark manual $savedAptMark && \
    apt-get purge -y --auto-remove

COPY --from=builder --chmod=755 --link /app/output/libjudger.so /usr/lib/judger/libjudger.so
COPY --from=builder /app/bindings/Python/dist/ /app/

RUN --mount=type=cache,target=/root/.cache/pip,id=pip-cache-${TARGETARCH}${TARGETVARIANT}-final \
    python3 -m venv .venv && \
    CC=gcc .venv/bin/pip3 install --compile --no-cache-dir flask gunicorn idna psutil requests && \
    .venv/bin/pip3 install *.whl

COPY server/ /app/
RUN chmod -R u=rwX,go=rX /app/ && \
    chmod +x /app/entrypoint.sh && \
    gcc -shared -fPIC -o unbuffer.so unbuffer.c && \
    useradd -u 901 -r -s /sbin/nologin -M compiler && \
    useradd -u 902 -r -s /sbin/nologin -M code && \
    useradd -u 903 -r -s /sbin/nologin -M -G code spj && \
    mkdir -p /usr/lib/judger

RUN gcc --version && \
    g++ --version && \
    python3 --version && \
    java -version && \
    node --version

HEALTHCHECK --interval=5s CMD [ "/app/.venv/bin/python3", "/app/service.py" ]
EXPOSE 8080
ENTRYPOINT [ "/app/entrypoint.sh" ]
