# AudioStack

A Docker-based audio streaming solution that combines Icecast2 and Liquidsoap to create a robust radio streaming server with automatic failover capabilities.

## Features

- **Dual Input Support**: Primary and backup audio inputs with automatic failover
- **Multiple Stream Formats**: High-quality (192kbps) and low-quality (96kbps) MP3 streams
- **Silence Detection**: Automatic detection and handling of audio silence
- **Dynamic Configuration**: Environment variable-based configuration
- **Fallback Audio**: Automatic fallback to a backup audio file when no live input is available
- **Security**: Runs with non-root user privileges for enhanced security

## Architecture

AudioStack consists of:
- **Icecast2**: Streaming media server for distributing audio streams
- **Liquidsoap**: Audio stream generator and processor with advanced routing capabilities
- **FFmpeg**: Media processing and format conversion

## Quick Start

### Using Docker

1. Pull and run the container:
```bash
docker run -d \
  --name audiostack \
  -p 3000:3000 \
  -p 3001:3001 \
  -p 3002:3002 \
  -e STATION_NAME="My Radio Station" \
  -e STATION_DESCRIPTION="Your radio station description" \
  -e STATION_GENRE="Various" \
  -e STATION_URL="https://your-website.com" \
  ghcr.io/sonicverse-nl/audiostack:latest
```

2. Access your streams:
   - High Quality: `http://localhost:3000/radio.mp3` (192kbps)
   - Low Quality: `http://localhost:3000/radio-lq.mp3` (96kbps)
   - Admin Interface: `http://localhost:3000/admin/`

### Using Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'
services:
  audiostack:
    image: ghcr.io/sonicverse-nl/audiostack:latest
    ports:
      - "3000:3000"  # Icecast web interface and streams
      - "3001:3001"  # Primary studio input
      - "3002:3002"  # Backup studio input
    environment:
      # Station Information
      - STATION_NAME=My Radio Station
      - STATION_DESCRIPTION=Your radio station description
      - STATION_GENRE=Various
      - STATION_URL=https://your-website.com
      
      # Admin Configuration
      - ICECAST_ADMIN_USERNAME=admin
      - ICECAST_ADMIN_PASSWORD=your_admin_password
      - ICECAST_ADMIN_EMAIL=admin@your-domain.com
      
      # Input Passwords
      - INPUT_1_PASSWORD=studio_a_password
      - INPUT_2_PASSWORD=studio_b_password
      
      # Optional: Custom emergency file (Public access is needed)
      - EMERGENCY_URL=https://your-server.com/path/to/emergency.wav
    restart: unless-stopped
```

Then run:
```bash
docker-compose up -d
```

## Docker Images

AudioStack images are automatically built and published to GitHub Container Registry (ghcr.io) via GitHub Actions:

- **Latest release**: `ghcr.io/sonicverse-nl/audiostack:latest` 
- **Specific version**: `ghcr.io/sonicverse-nl/audiostack:v1.0.0`
- **Development**: `ghcr.io/sonicverse-nl/audiostack:main`

Images are built for multiple architectures:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM 64-bit)

### Available Tags
- `latest` - Latest stable release
- `main` - Latest development build from main branch  
- `v*` - Specific version tags (e.g., `v1.0.0`, `v1.2.3`)

## Configuration

### Environment Variables

#### Station Information
- `STATION_NAME`: Your radio station name
- `STATION_DESCRIPTION`: Description of your station
- `STATION_GENRE`: Music genre or station category
- `STATION_URL`: Your station's website URL

#### Icecast Configuration
- `ICECAST_ADMIN_USERNAME`: Admin username (default: admin)
- `ICECAST_ADMIN_PASSWORD`: Admin password for Icecast web interface
- `ICECAST_ADMIN_EMAIL`: Admin email address
- `ICECAST_SOURCE_PASSWORD`: Source password (auto-generated if not set)
- `ICECAST_LOCATION`: Server location
- `ICECAST_HOSTNAME`: Server hostname
- `ICECAST_MAX_CLIENTS`: Maximum number of concurrent clients
- `ICECAST_MAX_SOURCES`: Maximum number of concurrent sources

#### Audio Input Configuration
- `INPUT_1_PASSWORD`: Password for primary studio input (port 3001)
- `INPUT_2_PASSWORD`: Password for backup studio input (port 3002)
- `SOURCE_PASSWORD`: Stream source password (uses ICECAST_SOURCE_PASSWORD if not set)

#### Fallback Audio Configuration
- `EMERGENCY_URL`: FTP URL to download fallback audio file
- `EMERGENCY_USER`: FTP username for fallback audio download
- `EMERGENCY_PASS`: FTP password for fallback audio download

## Streaming to AudioStack

### From OBS Studio
1. Add an "Audio Output Capture" source
2. Go to Settings → Stream
3. Set Service to "Custom..."
4. Set Server to: `http://your-server:3001/studio_a` (primary) or `http://your-server:3002/studio_b` (backup)
5. Set Stream Key to your input password
6. **Important**: Use "Use authentication" and set password to your INPUT_PASSWORD (leave username empty)

### From FFmpeg
```bash
# Stream to primary input (Shoutcast format)
ffmpeg -i input.wav -acodec mp3 -ab 128k -f mp3 -content_type audio/mpeg \
  http://source:INPUT_1_PASSWORD@your-server:3001/studio_a

# Stream to backup input (Shoutcast format)
ffmpeg -i input.wav -acodec mp3 -ab 128k -f mp3 -content_type audio/mpeg \
  http://source:INPUT_2_PASSWORD@your-server:3002/studio_b
```

### From Liquidsoap
```liquidsoap
# Stream to primary input using Shoutcast protocol
output.harbor(
  %mp3,
  port=3001,
  password="INPUT_1_PASSWORD",
  icy=true,
  mount="/studio_a",
  your_source
)
```

## Ports

- **3000**: Icecast2 web interface and audio streams
- **3001**: Primary studio audio input
- **3002**: Backup studio audio input

## Audio Processing Features

### Automatic Failover
The system automatically switches between:
1. Primary studio input (port 3001)
2. Backup studio input (port 8002)  
3. Fallback audio file (emergency.wav)

### Silence Detection
- Detects silence after 15 seconds
- Automatically switches to next available source
- Logs all source transitions

### Stream Buffering
- Buffers audio to prevent connection issues
- Maintains stream continuity during source switches

## Building from Source

```bash
git clone https://github.com/Sonicverse-NL/AudioStack.git
cd AudioStack
docker build -t audiostack .
```

## Monitoring

### Icecast Admin Interface
Access `http://your-server:3000/admin/` to monitor:
- Active streams and listeners
- Source connections
- Server statistics

### Logs
View container logs for debugging:
```bash
docker logs audiostack
```

## Troubleshooting

### Common Issues

**No audio output**
- Check if studio inputs are connected and sending audio
- Verify input passwords match your streaming software
- Check container logs for silence detection messages

**Can't access admin interface**
- Ensure port 3000 is accessible
- Check ICECAST_ADMIN_PASSWORD is set
- Verify firewall settings

**Streams not working**
- Confirm Icecast is running (check logs)
- Verify SOURCE_PASSWORD is correctly set
- Check network connectivity

### Debug Mode
Run with verbose logging:
```bash
docker run -it --rm ghcr.io/sonicverse-nl/audiostack:latest /bin/bash
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

We welcome contributions to AudioStack! Please follow the [contributing guidelines](CONTRIBUTING.MD).



## Support

For support and questions, please open an issue on the GitHub repository.

---

**AudioStack** - Professional audio streaming made simple
