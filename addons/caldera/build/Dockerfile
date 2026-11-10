# Debian 9 ARMHF userspace matching the HTP-1 baseline.
FROM arm32v7/debian:stretch

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99archive && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends ca-certificates curl bash tar file binutils libc-bin && \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 --shell /bin/bash caldera

COPY build-target.sh /usr/local/bin/build-target
RUN chmod 0755 /usr/local/bin/build-target

ENV HOME=/root
WORKDIR /root

CMD ["/usr/local/bin/build-target"]
