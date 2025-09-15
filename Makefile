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