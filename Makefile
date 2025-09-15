.PHONY: build run test clean docker-build docker-run docker-stop help

# Go binary name
BINARY_NAME=parking-iot

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build the Go application
build: ## Build the Go application
	@echo "Building Go application..."
	go mod tidy
	go build -o $(BINARY_NAME) main.go
	@echo "Build complete: $(BINARY_NAME)"

# Run the application locally
run: build ## Run the application locally (requires local MQTT broker)
	@echo "Starting parking IoT application..."
	./$(BINARY_NAME)

# Test the application
test: ## Run tests
	@echo "Running tests..."
	@if [ -f ./test-mqtt.sh ]; then ./test-mqtt.sh; else echo "No tests found"; fi

# Clean build artifacts
clean: ## Clean build artifacts
	@echo "Cleaning..."
	rm -f $(BINARY_NAME)
	docker-compose down --volumes --remove-orphans 2>/dev/null || true
	@echo "Clean complete"

# Build Docker image
docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker-compose build
	@echo "Docker image built"

# Run with Docker Compose (includes MQTT broker)
docker-run: ## Run application with Docker Compose (includes MQTT broker)
	@echo "Starting application with Docker Compose..."
	docker-compose up -d
	@echo "Application started. Access at http://localhost:3000"
	@echo "MQTT broker available at localhost:1883"

# Stop Docker containers
docker-stop: ## Stop Docker containers
	@echo "Stopping Docker containers..."
	docker-compose down
	@echo "Containers stopped"

# Show Docker logs
docker-logs: ## Show Docker logs
	docker-compose logs -f

# Development mode with auto-reload
dev: ## Development mode with auto-reload (requires air: go install github.com/cosmtrek/air@latest)
	@echo "Starting development mode..."
	air

# Install development dependencies
install-dev: ## Install development dependencies
	@echo "Installing development dependencies..."
	go install github.com/cosmtrek/air@latest
	@echo "Development dependencies installed"

# Production deployment
deploy: docker-build docker-run ## Build and deploy with Docker

# Check Go environment
check: ## Check Go environment and dependencies
	@echo "Go version:"
	go version
	@echo ""
	@echo "Go environment:"
	go env

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
	@echo "  Go Binary Size: $$(du -sh parking-iot-go 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  Node Dependencies: $$(du -sh node_modules 2>/dev/null | cut -f1 || echo 'Not installed')"
	@echo ""
	@echo "🚀 Run benchmark: make benchmark"
	@echo "📖 Full analysis: cat MEMORY_COMPARISON.md"
	@echo ""
	@echo "Dependencies:"
	go mod tidy
	go list -m all