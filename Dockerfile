# Use Node.js 22 LTS slim image as base
FROM node:22-slim

# Metadatos de la imagen
LABEL maintainer="DTI Team <j.arnaboldi@spb.gba.gov.ar>"
LABEL version="1.0.0"
LABEL description="DTI Intercom WebRTC SFU Server (based on MiroTalkSFU)"

# Set working directory
WORKDIR /src

# Set environment variable to skip downloading prebuilt workers
ENV MEDIASOUP_SKIP_WORKER_PREBUILT_DOWNLOAD="true"

# Install necessary system packages and dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        python3 \
        python3-pip \
        ffmpeg \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Rename config.template.js to config.js
COPY ./app/src/config.template.js ./app/src/config.js

# Copy package.json and install npm dependencies
COPY package.json .
RUN npm install

# Cleanup unnecessary packages and files to reduce image size
RUN apt-get purge -y --auto-remove \
    python3-pip \
    build-essential \
    && npm cache clean --force \
    && rm -rf /tmp/* /var/tmp/* /usr/share/doc/*

# Copy the application code
COPY app app
COPY public public

# Create directories for recordings and logs with correct permissions
RUN mkdir -p \
    app/rec \
    app/logs

# Create non-root user and set permissions (with pre-check if group exists)
RUN getent group mirotalk > /dev/null || groupadd -r mirotalk -g 1000 || groupadd -r mirotalk && \
    getent passwd mirotalk > /dev/null || useradd -u 1000 -r -g mirotalk -m -d /home/mirotalk -s /sbin/nologin -c "MiroTalk user" mirotalk || useradd -r -g mirotalk -m -d /home/mirotalk -s /sbin/nologin -c "MiroTalk user" mirotalk && \
    chown -R mirotalk:mirotalk /src

# Final permissions for special directories that need access
RUN chown -R mirotalk:mirotalk /src/app/rec /src/app/logs && \
    chmod -R 755 /src/app/rec /src/app/logs

# Create healthcheck script
RUN echo '#!/bin/sh\nwget -q --spider http://localhost:${PORT:-3010}/health || exit 1' > /src/healthcheck.sh && \
    chmod +x /src/healthcheck.sh

# Switch to non-root user
USER mirotalk

# Define healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 CMD ["/src/healthcheck.sh"]

# Set default command to start the application
CMD ["npm", "start"]
