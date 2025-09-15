.PHONY: build run test clean docker-build docker-run docker-stop help rust-build rust-run rust-docker-build rust-docker-run

# Go binary name
BINARY_NAME=parking-iot
# Rust binary name  
RUST_BINARY_NAME=parking-iot-rust

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build the Go application (without creating binary file in repo)
build: ## Build the Go application
	@echo "Building Go application..."
	go mod tidy
	go build -o /tmp/$(BINARY_NAME) main.go
	@echo "Build complete: /tmp/$(BINARY_NAME)"

# Run the application locally
run: build ## Run the application locally (requires local MQTT broker)
	@echo "Starting parking IoT application..."
	/tmp/$(BINARY_NAME)

# Build the Rust application
rust-build: ## Build the Rust application
	@echo "Building Rust application..."
	cargo build --release
	@echo "Build complete: target/release/$(RUST_BINARY_NAME)"

# Run the Rust application locally
rust-run: rust-build ## Run the Rust application locally (requires local MQTT broker)
	@echo "Starting Rust parking IoT application..."
	./target/release/$(RUST_BINARY_NAME)

# Test the application
test: ## Run tests
	@echo "Running tests..."
	@if [ -f ./test-mqtt.sh ]; then ./test-mqtt.sh; else echo "No tests found"; fi

# Clean build artifacts
clean: ## Clean build artifacts
	@echo "Cleaning..."
	rm -f /tmp/$(BINARY_NAME)
	rm -rf target/
	docker-compose down --volumes --remove-orphans 2>/dev/null || true
	docker-compose -f docker-compose.rust.yml down --volumes --remove-orphans 2>/dev/null || true
	@echo "Clean complete"

# Build Docker image (Go)
docker-build: ## Build Docker image (Go)
	@echo "Building Go Docker image..."
	docker-compose build
	@echo "Go Docker image built"

# Build Docker image (Rust)
rust-docker-build: ## Build Docker image (Rust)
	@echo "Building Rust Docker image..."
	docker-compose -f docker-compose.rust.yml build
	@echo "Rust Docker image built"

# Run with Docker Compose (includes MQTT broker) - Go
docker-run: ## Run Go application with Docker Compose (includes MQTT broker)
	@echo "Starting Go application with Docker Compose..."
	docker-compose up -d
	@echo "Go application started. Access at http://localhost:3000"
	@echo "MQTT broker available at localhost:1883"

# Run with Docker Compose (includes MQTT broker) - Rust
rust-docker-run: ## Run Rust application with Docker Compose (includes MQTT broker)
	@echo "Starting Rust application with Docker Compose..."
	docker-compose -f docker-compose.rust.yml up -d
	@echo "Rust application started. Access at http://localhost:3000"
	@echo "MQTT broker available at localhost:1883"

# Stop Docker containers
docker-stop: ## Stop Docker containers
	@echo "Stopping Docker containers..."
	docker-compose down
	docker-compose -f docker-compose.rust.yml down
	@echo "Containers stopped"

# Show Docker logs
docker-logs: ## Show Docker logs
	docker-compose logs -f

# Show Rust Docker logs
rust-docker-logs: ## Show Rust Docker logs
	docker-compose -f docker-compose.rust.yml logs -f

# Development mode with auto-reload
dev: ## Development mode with auto-reload (requires air: go install github.com/cosmtrek/air@latest)
	@echo "Starting development mode..."
	air

# Install development dependencies
install-dev: ## Install development dependencies
	@echo "Installing development dependencies..."
	go install github.com/cosmtrek/air@latest
	@echo "Development dependencies installed"

# Production deployment (Go)
deploy: docker-build docker-run ## Build and deploy Go version with Docker

# Production deployment (Rust)
rust-deploy: rust-docker-build rust-docker-run ## Build and deploy Rust version with Docker

# Check Go environment
check: ## Check Go environment and dependencies
	@echo "Go version:"
	go version
	@echo ""
	@echo "Go environment:"
	go env

# Check Rust environment
rust-check: ## Check Rust environment and dependencies
	@echo "Rust version:"
	rustc --version
	cargo --version
	@echo ""
	@echo "Rust environment info:"
	rustup show

# Memory usage benchmark
benchmark: ## Compare memory usage between Node.js and Go implementations
	@echo "Running memory usage benchmark..."
	./benchmark-memory.sh

# Memory comparison analysis
memory-report: ## Generate detailed memory usage comparison report
	@echo "Memory Usage Comparison Report"
	@echo "=============================="
	@echo ""
	@echo "📋 Quick Stats:"
	@echo "  Go Binary Size: $$(du -sh /tmp/parking-iot-go 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  Rust Binary Size: $$(du -sh target/release/parking-iot-rust 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  Node Dependencies: $$(du -sh node_modules 2>/dev/null | cut -f1 || echo 'Not installed')"
	@echo ""
	@echo "🚀 Run benchmark: make benchmark"
	@echo "📖 Full analysis: cat MEMORY_COMPARISON.md"
	@echo ""
	@echo "Dependencies:"
	go mod tidy
	go list -m all

# === STRESS TESTING SUITE ===

# Comprehensive stress testing for all implementations
stress-test: ## Run comprehensive stress testing suite (all implementations)
	@echo "🚀 Starting comprehensive stress testing suite..."
	./stress-test.sh all quick

# Stress test specific implementation
stress-test-nodejs: ## Run stress test for Node.js implementation only
	@echo "🟨 Testing Node.js implementation..."
	./stress-test.sh nodejs quick

stress-test-go: ## Run stress test for Go implementation only  
	@echo "🟦 Testing Go implementation..."
	./stress-test.sh go quick

stress-test-rust: ## Run stress test for Rust implementation only
	@echo "🟧 Testing Rust implementation..."
	./stress-test.sh rust quick

# Full stress testing (longer duration, more load levels)
stress-test-full: ## Run full comprehensive stress testing (extended duration)
	@echo "🔥 Starting full stress testing suite (extended)..."
	./stress-test.sh all full

# Load testing scenarios
load-test-scenarios: ## Run realistic load testing scenarios
	@echo "📈 Running load testing scenarios..."
	@echo "Available scenarios: iot, spike, endurance, connection, websocket, all"
	@echo "Usage: make load-test-scenarios IMPL=<nodejs|go|rust> SCENARIO=<scenario>"
	@echo "Example: make load-test-scenarios IMPL=rust SCENARIO=iot"

load-test-iot: ## Run IoT device simulation scenario
	./load-test-scenarios.sh $(or $(IMPL),rust) iot

load-test-spike: ## Run traffic spike testing scenario
	./load-test-scenarios.sh $(or $(IMPL),rust) spike

load-test-endurance: ## Run long-running endurance testing
	./load-test-scenarios.sh $(or $(IMPL),rust) endurance

load-test-websocket: ## Run WebSocket stress testing
	./load-test-scenarios.sh $(or $(IMPL),rust) websocket

# Memory profiling
memory-profile: ## Run advanced memory profiling
	@echo "🧠 Running memory profiling..."
	@echo "Usage: make memory-profile IMPL=<nodejs|go|rust> DURATION=<seconds>"
	@echo "Example: make memory-profile IMPL=rust DURATION=600"

memory-profile-nodejs: ## Profile Node.js memory usage
	./memory-profiling.sh nodejs 300

memory-profile-go: ## Profile Go memory usage
	./memory-profiling.sh go 300

memory-profile-rust: ## Profile Rust memory usage
	./memory-profiling.sh rust 300

memory-profile-all: ## Profile all implementations memory usage
	@echo "🧠 Profiling all implementations..."
	./memory-profiling.sh nodejs 300
	./memory-profiling.sh go 300
	./memory-profiling.sh rust 300

# Performance comparison
performance-comparison: ## Run automated performance comparison of all implementations
	@echo "⚡ Running comprehensive performance comparison..."
	./performance-comparison.sh

# Quick performance test
quick-benchmark: ## Quick performance benchmark (subset of full comparison)
	@echo "⚡ Running quick performance benchmark..."
	@./stress-test.sh all quick
	@echo ""
	@echo "📊 For detailed comparison run: make performance-comparison"

# === TESTING UTILITIES ===

# Check testing prerequisites  
check-test-deps: ## Check if all testing dependencies are installed
	@echo "🔍 Checking testing dependencies..."
	@command -v wrk >/dev/null 2>&1 || (echo "❌ wrk not found. Install: apt-get install wrk" && exit 1)
	@command -v curl >/dev/null 2>&1 || (echo "❌ curl not found" && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "❌ jq not found. Install: apt-get install jq" && exit 1)
	@command -v docker >/dev/null 2>&1 || (echo "❌ docker not found" && exit 1)
	@command -v bc >/dev/null 2>&1 || (echo "❌ bc not found. Install: apt-get install bc" && exit 1)
	@command -v python3 >/dev/null 2>&1 || echo "⚠️  python3 not found (optional for MQTT testing)"
	@echo "✅ All required dependencies are available"

# Install testing dependencies (Ubuntu/Debian)
install-test-deps: ## Install testing dependencies (Ubuntu/Debian)
	@echo "📦 Installing testing dependencies..."
	sudo apt-get update
	sudo apt-get install -y wrk curl jq bc python3 python3-pip
	pip3 install paho-mqtt requests

# Start all implementations for testing
start-all: ## Start all implementations for manual testing
	@echo "🚀 Starting all implementations..."
	@echo "Starting MQTT broker..."
	@docker run -d --name mosquitto-test -p 1883:1883 eclipse-mosquitto:latest >/dev/null 2>&1 || echo "MQTT broker already running"
	@echo "Building applications..."
	@make build >/dev/null 2>&1
	@make rust-build >/dev/null 2>&1
	@echo "Starting implementations on different ports..."
	@echo "Node.js will be on port 3001, Go on 3002, Rust on 3003"
	@PORT=3001 node index.js > /tmp/nodejs_test.log 2>&1 & echo $$! > /tmp/nodejs_test.pid
	@PORT=3002 /tmp/parking-iot > /tmp/go_test.log 2>&1 & echo $$! > /tmp/go_test.pid  
	@./target/release/parking-iot-rust --port 3003 > /tmp/rust_test.log 2>&1 & echo $$! > /tmp/rust_test.pid
	@sleep 5
	@echo "✅ All implementations started"
	@echo "  Node.js: http://localhost:3001"
	@echo "  Go:      http://localhost:3002" 
	@echo "  Rust:    http://localhost:3003"

# Stop all test implementations
stop-all: ## Stop all running test implementations
	@echo "🛑 Stopping all test implementations..."
	@kill $$(cat /tmp/nodejs_test.pid 2>/dev/null) 2>/dev/null || true
	@kill $$(cat /tmp/go_test.pid 2>/dev/null) 2>/dev/null || true
	@kill $$(cat /tmp/rust_test.pid 2>/dev/null) 2>/dev/null || true
	@docker stop mosquitto-test >/dev/null 2>&1 || true
	@docker rm mosquitto-test >/dev/null 2>&1 || true
	@rm -f /tmp/*_test.pid /tmp/*_test.log
	@echo "✅ All implementations stopped"

# Generate testing documentation
test-docs: ## Generate comprehensive testing documentation
	@echo "📚 Testing documentation is available in TESTING.md"
	@echo "📖 View complete testing guide: cat TESTING.md"
	@echo "🚀 Quick start: make quick-benchmark"
