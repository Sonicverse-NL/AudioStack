FROM ubuntu:22.04
LABEL maintainer="Sonicverse <info@sonicverse.nl>" \
        github="https://github.com/Sonicverse-NL/AudioStack"

# Install dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    icecast2 \
    liquidsoap \
    ffmpeg \
    curl \
    net-tools \
    mime-support && \
    rm -rf /var/cache/apt/*

# Create icecast user and necessary directories
RUN adduser --system --group --no-create-home icecast && \
    mkdir -p /etc/liquidsoap /var/log/icecast2 /var/run/icecast2 && \
    chown -R icecast:icecast /var/log/icecast2 /var/run/icecast2 /etc/liquidsoap

# Copy entrypoint script and icecast config
# and make them executable
COPY entrypoint.sh /entrypoint.sh
COPY icecast.xml /etc/icecast2/icecast.xml
RUN chmod +x /entrypoint.sh && \
    chown icecast:icecast /etc/icecast2/icecast.xml

# Removed listener tracker functionality

EXPOSE 3000 \
       3001 \
       3002

ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["sh", "-c", "su -s /bin/sh icecast -c 'icecast2 -c /etc/icecast2/icecast.xml' && su -s /bin/sh icecast -c 'liquidsoap /etc/liquidsoap/config.liq'"]

