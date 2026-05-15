#!/bin/bash
set -e

# Default values for printer IPs and access codes. These can be overridden by
# PRINTER{N}_IP, PRINTER{N}_CODE, PRINTER{N}_NAME, PRINTER{N}_SERIAL, and
# PRINTER{N}_MODEL environment variables.
export MAX_PRINTERS=${MAX_PRINTERS:-16}

for i in $(seq 1 "$MAX_PRINTERS"); do
  ip_var="PRINTER${i}_IP"
  code_var="PRINTER${i}_CODE"
  name_var="PRINTER${i}_NAME"
  serial_var="PRINTER${i}_SERIAL"
  model_var="PRINTER${i}_MODEL"

  export "$ip_var=${!ip_var:-}"
  export "$code_var=${!code_var:-}"
  export "$name_var=${!name_var:-Printer $i}"
  export "$serial_var=${!serial_var:-}"
  export "$model_var=${!model_var:-}"
done

# Create log directory
mkdir -p /var/log/supervisor

echo "Starting Bambu Labs Farm Monitor"
echo "========================================"
echo "Web UI: http://localhost:8080"
echo "go2rtc API: http://localhost:1984"
echo "Config API: http://localhost:5000"
echo "Status API: http://localhost:5001"
echo "========================================"
echo "First time setup: Navigate to the Web UI to configure your printers"
echo "========================================"

# Create initial printer configuration JSON if it doesn't exist
if [ ! -f /app/config/printers.json ]; then
  echo "Creating initial printer configuration..."
  mkdir -p /app/config

  python3 <<'PY'
import json
import os

max_printers = int(os.environ.get("MAX_PRINTERS", "16"))
printers = []

for printer_id in range(1, max_printers + 1):
    ip = os.environ.get(f"PRINTER{printer_id}_IP", "").strip()
    access_code = os.environ.get(f"PRINTER{printer_id}_CODE", "").strip()
    if not ip or not access_code:
        continue

    printer = {
        "id": printer_id,
        "name": os.environ.get(f"PRINTER{printer_id}_NAME", f"Printer {printer_id}"),
        "ip": ip,
        "access_code": access_code,
        "serial": os.environ.get(f"PRINTER{printer_id}_SERIAL", ""),
    }

    model = os.environ.get(f"PRINTER{printer_id}_MODEL", "").strip()
    if model:
        printer["model"] = model

    printers.append(printer)

with open("/app/config/printers.json", "w", encoding="utf-8") as config_file:
    json.dump({"printers": printers}, config_file, indent=2)
    config_file.write("\n")

if printers:
    print(f"Loaded {len(printers)} printers from environment variables")
else:
    print("No configuration found. Creating empty config - use Web UI to setup printers...")
PY
  echo "Initial configuration created at /app/config/printers.json"
else
  echo "Using existing configuration at /app/config/printers.json"
fi

# Generate go2rtc.yaml from the active printer configuration. Bambu Lab cameras
# expose RTSP-over-TLS on port 322, which go2rtc supports directly as rtspx.
echo "Generating go2rtc configuration..."
python3 <<'PY'
import json
from urllib.parse import quote

with open("/app/config/printers.json", "r", encoding="utf-8") as config_file:
    config = json.load(config_file)

stream_lines = []
for printer in config.get("printers", []):
    printer_id = printer.get("id")
    name = str(printer.get("name", f"Printer {printer_id}")).replace("\n", " ")
    ip = str(printer.get("ip", "")).strip()
    access_code = str(printer.get("access_code", "")).strip()

    if not printer_id or not ip or not access_code:
        continue

    encoded_code = quote(access_code, safe="")
    stream_lines.append(f"  # Printer {printer_id}: {name}")
    stream_lines.append(f"  printer{printer_id}: \"rtspx://bblp:{encoded_code}@{ip}:322/streaming/live/1\"")
    stream_lines.append("")

lines = ["streams:"] + stream_lines if stream_lines else ["streams: {}"]

lines.extend([
    "# API settings",
    "api:",
    "  listen: \":1984\"",
    "  origin: \"*\"",
    "",
    "# WebRTC settings",
    "webrtc:",
    "  listen: \":8555\"",
    "",
    "# Log settings",
    "log:",
    "  level: info",
    "  format: text",
])

with open("/app/go2rtc.yaml", "w", encoding="utf-8") as go2rtc_file:
    go2rtc_file.write("\n".join(lines))
    go2rtc_file.write("\n")
PY

echo "Configuration generated successfully!"

# Execute the command passed to the entrypoint
exec "$@"
