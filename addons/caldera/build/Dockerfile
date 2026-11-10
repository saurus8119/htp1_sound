# Newer ARMHF runtime donor. Caldera requires GLIBC 2.30 and newer C++ ABI.
FROM arm32v7/debian:bullseye AS caldera-runtime

# Keep the runtime donor minimal; copy its shared-library set into the add-on.
RUN apt-get update && \
    apt-get install -y --no-install-recommends libc6 libstdc++6 libgcc-s1 && \
    rm -rf /var/lib/apt/lists/*

# Debian 9 userspace matches the HTP-1 build baseline for running the installer.
FROM arm32v7/debian:stretch

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99archive && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends ca-certificates curl bash tar file binutils libc-bin libasound2 && \
    rm -rf /var/lib/apt/lists/*

# Include the complete matching glibc loader/runtime and C++ runtime from Bullseye.
COPY --from=caldera-runtime /lib/arm-linux-gnueabihf/ /opt/caldera-runtime/lib/arm-linux-gnueabihf/
COPY --from=caldera-runtime /lib/ld-linux-armhf.so.3 /opt/caldera-runtime/lib/ld-linux-armhf.so.3
COPY --from=caldera-runtime /usr/lib/arm-linux-gnueabihf/ /opt/caldera-runtime/usr/lib/arm-linux-gnueabihf/

RUN useradd --create-home --uid 1000 --shell /bin/bash caldera

COPY build-target.sh /usr/local/bin/build-target
RUN chmod 0755 /usr/local/bin/build-target

ENV HOME=/root
WORKDIR /root

CMD ["/usr/local/bin/build-target"]
