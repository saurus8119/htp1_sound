# Build Caldera using its own installer in the HTP-1-compatible ARMv7 userspace.
FROM arm32v7/debian:stretch

ENV DEBIAN_FRONTEND=noninteractive

RUN printf '%s\n' \
      'deb http://archive.debian.org/debian stretch main' \
      'deb http://archive.debian.org/debian-security stretch/updates main' \
      > /etc/apt/sources.list \
 && printf 'Acquire::Check-Valid-Until "false";\nAcquire::AllowInsecureRepositories "true";\n' \
      > /etc/apt/apt.conf.d/99archive \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends ca-certificates curl bash tar file systemd \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 --shell /bin/bash caldera

COPY build-target.sh /usr/local/bin/build-target
RUN chmod 0755 /usr/local/bin/build-target

USER caldera
ENV HOME=/home/caldera
WORKDIR /home/caldera

CMD ["/usr/local/bin/build-target"]
