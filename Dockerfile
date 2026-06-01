FROM alexxit/go2rtc:1.9.4 AS go2rtc
FROM mythikwolf/bambu-farm-monitor:3.4.1 AS bambu-camera-assets

FROM debian:12-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    libcurl4 \
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

# Copy Bambu camera wrapper runtime assets from the last known-good image.
# The native rtspx path is unreliable for some users, so go2rtc streams are fed
# through BambuP1SCam wrapper scripts without requiring local build_assets.
COPY --from=bambu-camera-assets /app/BambuP1SCam /app/BambuP1SCam
COPY --from=bambu-camera-assets /app/libBambuSource.so /app/libBambuSource.so
COPY --from=bambu-camera-assets /app/libbambu_networking.so /app/libbambu_networking.so
RUN chmod +x /app/BambuP1SCam && \
    chmod a+r /app/libBambuSource.so /app/libbambu_networking.so

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
    chmod +x /app/api/*.py && \
    chmod -R a+rX /var/www/html

# Expose ports
# 8080: Web UI
# 1984: go2rtc API and WebRTC
# 5000: Configuration API
# 5001: Status API
EXPOSE 8080 1984 5000 5001

# Use supervisor to manage multiple processes
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
