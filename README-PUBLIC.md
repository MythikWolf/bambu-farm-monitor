# Bambu Farm Monitor

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Docker Pulls](https://img.shields.io/docker/pulls/mythikwolf/bambu-farm-monitor)
![Version](https://img.shields.io/badge/version-3.4.0-green.svg)

A unified web-based monitoring solution for Bambu Lab 3D printers with real-time video streaming and MQTT status integration.

## Fork Notice

This is MythikWolf's maintained fork of Bambu Farm Monitor. It is based on the original work by [neospektra](https://github.com/neospektra/bambu-farm-monitor), with credit retained for the original foundation and community contributions.

## Features

- **Live Video Streaming**: Low-latency WebRTC streams from all printers via go2rtc
- **Real-time Status Monitoring**: MQTT integration for live print status, temperatures, progress, and layer information
- **Setup Wizard**: Easy first-time configuration with guided setup
- **Dynamic Configuration**: Web-based interface to manage printer settings without rebuilding
- **Printer Model Support**: P1P, P1S, X1C, P2S, H2S, A1 and more
- **Fullscreen Support**: Individual fullscreen capability for each camera feed
- **Persistent Configuration**: Settings persist across container restarts via volume mounts
- **Modern Responsive UI**: Clean interface with icons, gradients, and mobile support

## Quick Start

### Docker Hub (Recommended)

```bash
docker run -d \
  --name bambu-farm-monitor \
  -p 8080:8080 \
  -p 1984:1984 \
  -p 5000:5000 \
  -p 5001:5001 \
  -v /path/to/config:/app/config \
  mythikwolf/bambu-farm-monitor:latest
```

Then navigate to `http://localhost:8080` and follow the setup wizard!

### Docker Compose

```yaml
version: '3'
services:
  bambu-monitor:
    image: mythikwolf/bambu-farm-monitor:latest
    container_name: bambu-farm-monitor
    ports:
      - "8080:8080"  # Web UI
      - "1984:1984"  # go2rtc API
      - "5000:5000"  # Config API
      - "5001:5001"  # Status API
    volumes:
      - ./config:/app/config
    restart: unless-stopped
```

## Setup Wizard

On first run, you'll be greeted with a setup wizard that guides you through:

1. **Select Number of Printers** (1 or more)
2. **Configure Each Printer**:
   - Printer Name
   - IP Address
   - MQTT Access Code
   - Serial Number (optional, required for status monitoring)
   - Printer Model
3. **Complete** - Redirects to dashboard

### Finding Your Printer Information

- **IP Address**: Check your printer's screen or router's DHCP table
- **Access Code**: Printer Settings → Network → LAN Mode → MQTT (8-digit code)
- **Serial Number**: Printer Settings → Device → Device Info

## API Endpoints

### Config API (Port 5000)

- `GET /api/config/printers` - Get all printer configurations
- `PUT /api/config/printers/<id>` - Update specific printer
- `POST /api/config/printers` - Add new printer
- `POST /api/config/printers/bulk` - Bulk update (used by setup wizard)
- `GET /api/config/setup-required` - Check if setup wizard is needed

### Status API (Port 5001)

- `GET /api/status/printers` - Get status for all printers
- `GET /api/status/printers/<id>` - Get status for specific printer
- `POST /api/status/mqtt-test/<id>` - Test MQTT connection
- `GET /api/health` - Health check

## Building from Source

```bash
git clone https://github.com/yourusername/bambu-farm-monitor.git
cd bambu-farm-monitor

docker build -t bambu-farm-monitor:latest .

docker run -d \
  --name bambu-farm-monitor \
  -p 8080:8080 -p 1984:1984 -p 5000:5000 -p 5001:5001 \
  -v $(pwd)/config:/app/config \
  bambu-farm-monitor:latest
```

## Known Limitations

- P1P/P1S models only support a single MQTT connection. If connected to Bambu Cloud, local monitoring will be refused. You must choose one or the other for these models.

## Technology Stack

- **[go2rtc](https://github.com/AlexxIT/go2rtc)**: WebRTC streaming server
- **Flask**: Python web framework for REST APIs
- **paho-mqtt**: MQTT client for printer status
- **nginx**: Web server and reverse proxy
- **Supervisor**: Process manager

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- **[AlexxIT](https://github.com/AlexxIT)** for go2rtc
- **[@kitaro5053](https://github.com/kitaro5053)** for research and documentation of the `rtspx://` camera stream fix
- **Bambu Lab** for making great printers

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

---

**Note**: This is an unofficial community project and is not affiliated with Bambu Lab.
