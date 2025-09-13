# Parking IoT Management System

A real-time parking lot management system built with Go, featuring MQTT communication and WebSocket-based real-time updates. This project provides a web interface to monitor and manage parking slots with IoT device integration.

## Features

- 🚗 **Real-time Parking Management**: Monitor parking slots in real-time
- 🌐 **Web Interface**: Interactive parking lot visualization
- 📡 **MQTT Integration**: Communicate with IoT devices via MQTT protocol
- 🔄 **WebSocket Communication**: Real-time updates using Socket.IO
- 🐳 **Docker Support**: Containerized deployment with Docker Compose
- 🏗️ **Production Ready**: Optimized for production deployment

## Architecture

```
IoT Devices → MQTT Broker → Go Backend → WebSocket → Frontend
                ↓
            (Parkir/1, Parkir/2 topics)
```

### Communication Flow

1. **IoT Devices** send parking sensor data to MQTT topics (`Parkir/1`, `Parkir/2`)
2. **MQTT Broker** (Mosquitto) receives and distributes messages
3. **Go Backend** subscribes to MQTT topics and forwards messages via WebSocket
4. **Frontend** receives real-time updates and updates parking slot visualization

## Quick Start

### Using Docker (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd project_iot

# Build and run with Docker Compose (includes MQTT broker)
make docker-run

# Access the application
open http://localhost:3000
```

### Local Development

```bash
# Install dependencies
go mod tidy

# Build the application
make build

# Run locally (requires local MQTT broker)
make run
```

## API Reference

### HTTP Endpoints

- `GET /` - Serves the main parking management interface
- `GET /socket.io/` - Socket.IO WebSocket endpoint
- `GET /public/*` - Static files (CSS, JS, images)

### WebSocket Events

The application listens for the following Socket.IO events:

- `Parkir/1` - Controls parking slot 0
  - Message `1`: Car enters slot
  - Message `0`: Car exits slot
- `Parkir/2` - Controls parking slot 1
  - Message `1`: Car enters slot
  - Message `0`: Car exits slot

### MQTT Topics

- `Parkir/1` - Parking slot 0 sensor data
- `Parkir/2` - Parking slot 1 sensor data

**Message Format**: Integer values (0 = exit, 1 = enter)

## Configuration

### Environment Variables

- `GIN_MODE` - Gin framework mode (`debug` or `release`)
- `PORT` - Server port (default: 3000)

### MQTT Configuration

The application connects to MQTT broker at `127.0.0.1:1883` by default. For Docker deployment, it connects to the `mosquitto` service.

## Development

### Prerequisites

- Go 1.21 or higher
- Docker and Docker Compose (for containerized deployment)
- MQTT broker (Mosquitto recommended)

### Development Commands

```bash
# Install development dependencies
make install-dev

# Run in development mode with auto-reload
make dev

# Run tests
make test

# Check Go environment
make check

# Clean build artifacts
make clean
```

### Project Structure

```
.
├── main.go              # Main Go application
├── go.mod               # Go module dependencies
├── index.html           # Main web interface
├── public/              # Static assets
│   ├── parking.js       # Frontend JavaScript
│   ├── parking.css      # Styles
│   └── *.png           # Car images
├── Dockerfile           # Docker build configuration
├── docker-compose.yml   # Docker Compose configuration
├── mosquitto.conf       # MQTT broker configuration
├── Makefile            # Build automation
└── README.md           # This file
```

## Deployment

### Production Deployment with Docker

```bash
# Build and deploy
make deploy

# Check logs
make docker-logs

# Stop deployment
make docker-stop
```

### Manual Deployment

1. **Build the application**:
   ```bash
   make build
   ```

2. **Set up MQTT broker** (Mosquitto):
   ```bash
   # Install Mosquitto
   sudo apt-get install mosquitto mosquitto-clients
   
   # Start Mosquitto
   sudo systemctl start mosquitto
   sudo systemctl enable mosquitto
   ```

3. **Run the application**:
   ```bash
   ./parking-iot
   ```

### Kubernetes Deployment

```yaml
# Example Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: parking-iot
spec:
  replicas: 3
  selector:
    matchLabels:
      app: parking-iot
  template:
    metadata:
      labels:
        app: parking-iot
    spec:
      containers:
      - name: parking-iot
        image: parking-iot:latest
        ports:
        - containerPort: 3000
        env:
        - name: GIN_MODE
          value: "release"
```

## Testing

### Manual Testing

1. **Start the application**:
   ```bash
   make docker-run
   ```

2. **Test MQTT communication**:
   ```bash
   # Install mosquitto clients
   sudo apt-get install mosquitto-clients
   
   # Send test messages
   mosquitto_pub -h localhost -t "Parkir/1" -m "1"  # Car enters slot 0
   mosquitto_pub -h localhost -t "Parkir/1" -m "0"  # Car exits slot 0
   mosquitto_pub -h localhost -t "Parkir/2" -m "1"  # Car enters slot 1
   mosquitto_pub -h localhost -t "Parkir/2" -m "0"  # Car exits slot 1
   ```

3. **Verify web interface**:
   - Open http://localhost:3000
   - Check that parking slots update in real-time
   - Verify car animations work correctly

### Expected Behavior

- When MQTT message with value `1` is received: Car animation shows vehicle entering the parking slot
- When MQTT message with value `0` is received: Car animation shows vehicle exiting the parking slot
- Frontend should match the exact behavior of the original Node.js version

## Troubleshooting

### Common Issues

1. **MQTT Connection Failed**:
   ```
   Error: MQTT connection failed
   Solution: Ensure MQTT broker is running and accessible
   ```

2. **Port Already in Use**:
   ```
   Error: bind: address already in use
   Solution: Stop other services on port 3000 or change the port
   ```

3. **Static Files Not Found**:
   ```
   Error: 404 on static files
   Solution: Ensure public/ directory and index.html are in the working directory
   ```

### Debug Mode

Run with debug logging:
```bash
GIN_MODE=debug ./parking-iot
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the ISC License.

## Support

For issues and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the logs: `make docker-logs`

---

**Migration from Node.js**: This Go version maintains 100% compatibility with the original Node.js implementation, ensuring the same API responses and communication behavior.