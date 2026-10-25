
# ARMv7 Debian 9 userspace provides the intended glibc 2.24 baseline.
FROM arm32v7/debian:stretch

ENV DEBIAN_FRONTEND=noninteractive

RUN printf '%s\n' \
      'deb http://archive.debian.org/debian stretch main contrib non-free' \
      'deb http://archive.debian.org/debian-security stretch/updates main contrib non-free' \
      > /etc/apt/sources.list \
 && printf 'Acquire::Check-Valid-Until "false";\nAcquire::AllowInsecureRepositories "true";\n' \
      > /etc/apt/apt.conf.d/99archive \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      xz-utils \
      tar \
      gzip \
      make \
      gcc \
      g++ \
      cmake \
      pkg-config \
      autoconf \
      automake \
      libtool \
      m4 \
      dpkg-dev \
      file \
      binutils \
      patchelf \
      xmltoman \
      vim-common \
      libsodium-dev \
      uuid-dev \
      libavutil-dev \
      libavcodec-dev \
      libavformat-dev \
      libasound2-dev \
      libavahi-client-dev \
      libssl-dev \
      libsoxr-dev \
      libconfig-dev \
      libpopt-dev \
      libgcrypt20-dev \
      libxml2-dev \
 && command -v xxd \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build-target.sh /usr/local/bin/build-target

RUN sed -i 's/\r$//' /usr/local/bin/build-target \
 && chmod +x /usr/local/bin/build-target

CMD ["/usr/local/bin/build-target"]
