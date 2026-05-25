FROM alexxit/go2rtc:1.9.4 AS go2rtc

FROM debian:12-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    nginx \
    supervisor \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy go2rtc binary from the official image
COPY --from=go2rtc /usr/local/bin/go2rtc /usr/local/bin/go2rtc
RUN chmod +x /usr/local/bin/go2rtc

# Install Python dependencies for API
COPY api/requirements.txt /app/api/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /app/api/requirements.txt

# Copy configuration files
COPY go2rtc.yaml /app/go2rtc.yaml
COPY www/ /var/www/html/
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /app/entrypoint.sh
COPY api/ /app/api/

RUN sed -i 's/\r$//' /app/entrypoint.sh /app/api/*.py && \
    chmod +x /app/entrypoint.sh && \
    chmod +x /app/api/*.py

# Expose ports
# 8080: Web UI
# 1984: go2rtc API and WebRTC
# 5000: Configuration API
# 5001: Status API
EXPOSE 8080 1984 5000 5001

# Use supervisor to manage multiple processes
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
