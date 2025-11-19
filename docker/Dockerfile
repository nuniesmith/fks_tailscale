# Tailscale Connector Node
# Based on official Tailscale image with enhancements for Kubernetes

FROM tailscale/tailscale:latest

# Install additional tools for monitoring and debugging
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    netcat-openbsd \
    iputils

# Create directory for Tailscale state
RUN mkdir -p /var/lib/tailscale

# Copy helper scripts
COPY scripts/*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Health check script
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD tailscale status --json | jq -e '.Self' > /dev/null || exit 1

# Default command
# Tailscale will use TS_HOSTNAME environment variable if set
CMD ["tailscaled"]

