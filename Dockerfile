FROM debian:12-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    nginx \
    supervisor \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Download go2rtc binary directly
RUN curl -L https://github.com/AlexxIT/go2rtc/releases/download/v1.9.4/go2rtc_linux_amd64 -o /usr/local/bin/go2rtc \
    && chmod +x /usr/local/bin/go2rtc

# Copy BambuP1SCam and required libraries from build_assets
COPY build_assets/BambuP1SCam /app/BambuP1SCam
COPY build_assets/libBambuSource.so /app/libBambuSource.so
COPY build_assets/libbambu_networking.so /app/libbambu_networking.so
RUN chmod +x /app/BambuP1SCam

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

RUN chmod +x /app/entrypoint.sh && \
    chmod +x /app/api/*.py

# Expose ports
# 8080: Web UI
# 1984: go2rtc API and WebRTC
# 5000: Configuration API
# 5001: Status API
EXPOSE 8080 1984 5000 5001

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
