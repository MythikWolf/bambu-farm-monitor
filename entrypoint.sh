#!/bin/bash
set -e

# =============================================================================
# entrypoint.sh for bambu-farm-monitor
# Stream method is selected based on printer model:
#   - X1C, X1, X2D, P2S, H2S, H2D  -> rtspx:// direct connection (port 322)
#   - P1S, P1P, A1             -> BambuP1SCam start_stream_local (port 6000)
#
# Configuration priority:
#   1. /app/config/printers.json  (Web UI config - preferred)
#   2. PRINTER1-PRINTER16 environment variables (legacy/alternative)
# =============================================================================

# Create log directory
mkdir -p /var/log/supervisor

echo "Starting Bambu Labs Farm Monitor"
echo "========================================"
echo "Web UI: http://localhost:8080"
echo "go2rtc API: http://localhost:1984"
echo "Config API: http://localhost:5000"
echo "Status API: http://localhost:5001"
echo "========================================"

# Create a dummy BambuNetworkEngine.conf to bypass config check
echo "Creating dummy BambuNetworkEngine.conf..."
cat > /app/BambuNetworkEngine.conf <<CONF
{
  "country_code": "us",
  "last_monitor_machine": "dummy",
  "user": {
    "user_id": "0",
    "token": "dummy_token"
  }
}
CONF

echo "Creating stream configuration..."

# =============================================================================
# Use python3 to handle all config logic cleanly
# Avoids bash pipe subshell variable scope issues
# =============================================================================
python3 << 'PYEOF'
import json
import os
import stat

CONFIG_FILE = '/app/config/printers.json'
GO2RTC_YAML = '/app/go2rtc.yaml'

RTSPX_MODELS = {'x1c', 'x1', 'x2d', 'p2s', 'h2s', 'h2d'}

def uses_rtspx(model):
    return str(model).lower() in RTSPX_MODELS

def write_stream_script(printer_id, ip, code):
    path = f'/app/stream{printer_id}.sh'
    content = f"""#!/bin/bash
export LD_LIBRARY_PATH=/app:$LD_LIBRARY_PATH
cd /app
exec ./BambuP1SCam start_stream_local -s {ip} -a {code}
"""
    with open(path, 'w') as f:
        f.write(content)
    os.chmod(path, 0o755)

def build_from_json(config):
    printers = [p for p in config.get('printers', []) if p.get('ip') and p.get('access_code')]
    if not printers:
        return None

    streams = "streams:\n"
    for p in printers:
        pid   = p['id']
        name  = p.get('name', f'Printer {pid}')
        ip    = p['ip']
        code  = p['access_code']
        model = p.get('model', 'p1s')

        streams += f"  # Printer {pid}: {name}\n"

        if uses_rtspx(model):
            streams += f'  printer{pid}: "rtspx://bblp:{code}@{ip}:322/streaming/live/1"\n\n'
            print(f"Printer {pid} ({name}): {ip} configured as {model} (rtspx:// on port 322)")
        else:
            streams += f'  printer{pid}: "exec:/app/stream{pid}.sh#video=h264#hardware"\n\n'
            print(f"Printer {pid} ({name}): {ip} configured as {model} (BambuP1SCam on port 6000)")

        write_stream_script(pid, ip, code)

    return streams

def build_from_env():
    printers = []
    for i in range(1, 17):
        ip     = os.environ.get(f'PRINTER{i}_IP', '')
        code   = os.environ.get(f'PRINTER{i}_CODE', '')
        name   = os.environ.get(f'PRINTER{i}_NAME', f'Printer {i}')
        serial = os.environ.get(f'PRINTER{i}_SERIAL', '')
        model  = os.environ.get(f'PRINTER{i}_MODEL', 'p1s')
        if ip:
            printers.append({'id': i, 'name': name, 'ip': ip, 'access_code': code, 'serial': serial, 'model': model})

    if not printers:
        return None, None

    streams = "streams:\n"
    for p in printers:
        pid   = p['id']
        name  = p['name']
        ip    = p['ip']
        code  = p['access_code']
        model = p['model']

        if uses_rtspx(model):
            streams += f'  printer{pid}: "rtspx://bblp:{code}@{ip}:322/streaming/live/1"\n'
            print(f"Printer {pid} ({name}): {ip} configured as {model} (rtspx:// on port 322)")
        else:
            streams += f'  printer{pid}: "exec:/app/stream{pid}.sh#video=h264#hardware"\n'
            print(f"Printer {pid} ({name}): {ip} configured as {model} (BambuP1SCam on port 6000)")

        write_stream_script(pid, ip, code)

    return streams, printers

# Try printers.json first
streams = None
if os.path.exists(CONFIG_FILE):
    print(f"Found {CONFIG_FILE} - building stream config from file...")
    with open(CONFIG_FILE) as f:
        config = json.load(f)
    streams = build_from_json(config)
    if streams:
        print(f"Using existing configuration at {CONFIG_FILE}")
    else:
        print("printers.json has no configured printers - falling back to env vars...")

# Fall back to env vars
if not streams:
    print("Building stream config from environment variables...")
    streams, env_printers = build_from_env()

    if env_printers and not os.path.exists(CONFIG_FILE):
        print("Creating initial printer configuration from env vars...")
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump({"printers": env_printers}, f, indent=2)
        print(f"Initial configuration created at {CONFIG_FILE}")

if not streams:
    print("No printers configured - go2rtc will start with empty streams")
    streams = "streams:\n"

# Write go2rtc.yaml
print("Generating go2rtc configuration...")
full_config = streams + """
# API settings
api:
  listen: ":1984"
  origin: "*"
# WebRTC settings
webrtc:
  listen: ":8555"
# Log settings
log:
  level: info
  format: text
"""

with open(GO2RTC_YAML, 'w') as f:
    f.write(full_config)

print("=== go2rtc.yaml ===")
with open(GO2RTC_YAML) as f:
    print(f.read())
print("===================")
print("Configuration generated successfully!")
PYEOF

exec "$@"
