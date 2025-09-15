# Rust Parking IoT Management System 🦀

High-performance parking IoT management system written in Rust with MQTT communication and real-time WebSocket updates.

## 🚀 Features

- **MQTT Integration**: Real-time communication with IoT devices via `rumqttc`
- **WebSocket Communication**: Live updates to web clients using `warp`
- **Static File Serving**: Built-in web server for the parking management interface
- **Production Ready**: Optimized binary with comprehensive Docker support
- **Memory Efficient**: Ultra-low memory footprint with zero-cost abstractions
- **Async/Await**: High-performance concurrent processing with Tokio
- **Type Safety**: Compile-time guarantees preventing runtime errors

## 📦 Architecture

```
IoT Devices → MQTT Topics → Rust Backend → WebSocket → Frontend
            (Parkir/1,2)    (rumqttc)     (warp)      (Real-time)
```

## 🔧 Development

### Prerequisites

- **Rust**: 1.75 or later (`rustup install stable`)
- **Cargo**: Comes with Rust installation
- **MQTT Broker**: Local Mosquitto or Docker

### Quick Start

```bash
# Build and run Rust version
make rust-build
make rust-run

# Or with Docker (includes MQTT broker)
make rust-docker-run

# Access application
open http://localhost:3000
```

### Development Commands

```bash
# Build release binary
cargo build --release

# Run with debug logging
cargo run -- --debug

# Run with custom MQTT host
cargo run -- --mqtt-host 192.168.1.100

# Check code
cargo check
cargo clippy
cargo test
```

## 🐳 Docker Deployment

### Complete Stack (Recommended)

```bash
# Deploy Rust app + MQTT broker
docker-compose -f docker-compose.rust.yml up -d

# Check logs
docker-compose -f docker-compose.rust.yml logs -f

# Stop services
docker-compose -f docker-compose.rust.yml down
```

### Custom Configuration

```bash
# Run with environment variables
docker run -e MQTT_HOST=broker.example.com \
           -e RUST_LOG=debug \
           -p 3000:3000 \
           parking-iot-rust
```

## ⚡ Performance

### Memory Usage (Typical)

| Implementation | Runtime Memory | Binary Size | Dependencies |
|---------------|----------------|-------------|--------------|
| **Rust**      | **8-12 MB**   | **6 MB**    | **None**     |
| Go            | 13 MB          | 13 MB       | None         |
| Node.js       | 72 MB          | -           | 22 MB        |

### Key Advantages

- **Zero Runtime Dependencies**: Single static binary
- **Memory Safety**: No segfaults or memory leaks  
- **Ultra-Low Latency**: Sub-millisecond response times
- **High Concurrency**: Handles thousands of connections efficiently
- **Predictable Performance**: No garbage collection pauses

## 🔌 MQTT Communication

### Supported Topics

- `Parkir/1`: Parking slot entry/exit events
- `Parkir/2`: Secondary parking management

### Message Format

```json
{
  "topic": "Parkir/1",
  "message": "1",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Testing MQTT

```bash
# Simulate car entry (slot 0)
mosquitto_pub -h localhost -t "Parkir/1" -m "1"

# Simulate car exit (slot 1)
mosquitto_pub -h localhost -t "Parkir/2" -m "0"
```

## 🌐 WebSocket API

### Connection

```javascript
const socket = new WebSocket('ws://localhost:3000/socket.io');

socket.onmessage = (event) => {
    const [eventType, data] = JSON.parse(event.data);
    console.log(`Event: ${eventType}`, data);
};
```

### Events

- `parkir1`: Events from Parkir/1 topic
- `parkir2`: Events from Parkir/2 topic

## 🔧 Configuration

### Command Line Options

```bash
./parking-iot-rust --help

High-performance parking IoT management system written in Rust

Usage: parking-iot-rust [OPTIONS]

Options:
  -p, --port <PORT>              Port to run the web server on [default: 3000]
      --mqtt-host <MQTT_HOST>    MQTT broker host [default: localhost]
      --mqtt-port <MQTT_PORT>    MQTT broker port [default: 1883]
  -d, --debug                    Enable debug logging
  -h, --help                     Print help
```

### Environment Variables

```bash
export RUST_LOG=info              # Logging level
export MQTT_HOST=localhost        # MQTT broker host
export MQTT_PORT=1883             # MQTT broker port
```

## 🏗️ Building

### Development Build

```bash
cargo build
```

### Production Build (Optimized)

```bash
cargo build --release
```

The production build includes:
- Link-time optimization (LTO)
- Dead code elimination
- Optimized for size and speed
- Stripped debugging symbols

## 🧪 Testing

```bash
# Run unit tests
cargo test

# Run with MQTT broker
./test-mqtt.sh
```

## 📊 Monitoring

### Health Check

```bash
curl http://localhost:3000/health
```

Response:
```json
{
  "status": "ok",
  "service": "parking-iot-rust"
}
```

### Metrics

The application provides structured logging for monitoring:

```bash
# Enable debug logging
RUST_LOG=debug ./target/release/parking-iot-rust
```

## 🔒 Security

- **Memory Safety**: Rust prevents buffer overflows and use-after-free
- **No Runtime Dependencies**: Reduces attack surface  
- **Type Safety**: Compile-time prevention of common bugs
- **Non-root Container**: Docker image runs as unprivileged user

## 🚀 Production Deployment

### Systemd Service

```ini
[Unit]
Description=Parking IoT Rust Service
After=network.target

[Service]
Type=simple
User=parking-iot
ExecStart=/opt/parking-iot/parking-iot-rust
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### Docker Swarm/Kubernetes

See `docker-compose.rust.yml` for production configuration examples.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🏆 Why Rust?

- **Performance**: Near C++ performance with high-level ergonomics
- **Safety**: Memory and thread safety without garbage collection
- **Concurrency**: Excellent async/await support with Tokio
- **Ecosystem**: Rich crate ecosystem for IoT and web development
- **Maintainability**: Strong type system prevents entire classes of bugs
- **Deployment**: Single binary with no runtime dependencies