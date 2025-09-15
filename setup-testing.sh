#!/bin/bash

# Installation and Setup Script for Stress Testing Suite
# Installs all required dependencies and validates the testing environment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "ubuntu"
        elif command -v yum &> /dev/null; then
            echo "centos"
        elif command -v pacman &> /dev/null; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Install dependencies based on OS
install_dependencies() {
    local os=$(detect_os)
    
    log "Installing dependencies for $os..."
    
    case $os in
        "ubuntu")
            sudo apt-get update
            sudo apt-get install -y \
                curl \
                jq \
                bc \
                wrk \
                python3 \
                python3-pip \
                docker.io \
                htop \
                lsof \
                netstat-nat \
                valgrind \
                build-essential
            
            # Install Python packages
            pip3 install --user paho-mqtt requests numpy pandas matplotlib
            ;;
            
        "centos")
            sudo yum update -y
            sudo yum install -y \
                curl \
                jq \
                bc \
                python3 \
                python3-pip \
                docker \
                htop \
                lsof \
                net-tools \
                valgrind \
                gcc \
                make
            
            # Install wrk from source
            install_wrk_from_source
            
            pip3 install --user paho-mqtt requests numpy pandas matplotlib
            ;;
            
        "macos")
            if ! command -v brew &> /dev/null; then
                error "Homebrew not found. Please install it first: https://brew.sh"
                exit 1
            fi
            
            brew install \
                curl \
                jq \
                bc \
                wrk \
                python3 \
                docker \
                htop \
                lsof \
                valgrind
            
            pip3 install paho-mqtt requests numpy pandas matplotlib
            ;;
            
        *)
            warn "Unknown OS. Please install dependencies manually:"
            info "Required: curl, jq, bc, wrk, python3, docker"
            info "Optional: htop, lsof, valgrind, pmap"
            ;;
    esac
}

# Install wrk from source (for systems without packages)
install_wrk_from_source() {
    log "Installing wrk from source..."
    
    local tmp_dir="/tmp/wrk-install"
    rm -rf "$tmp_dir"
    git clone https://github.com/wg/wrk.git "$tmp_dir"
    cd "$tmp_dir"
    make
    sudo cp wrk /usr/local/bin/
    cd -
    rm -rf "$tmp_dir"
    
    info "wrk installed to /usr/local/bin/wrk"
}

# Setup Docker
setup_docker() {
    log "Setting up Docker..."
    
    # Start Docker service
    if command -v systemctl &> /dev/null; then
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # Add user to docker group (requires logout/login)
    if ! groups "$USER" | grep -q docker; then
        sudo usermod -aG docker "$USER"
        warn "Added $USER to docker group. Please logout and login again."
    fi
    
    # Test Docker
    if docker run --rm hello-world >/dev/null 2>&1; then
        info "Docker is working correctly"
    else
        warn "Docker test failed. You may need to logout and login again."
    fi
}

# Validate environment
validate_environment() {
    log "Validating testing environment..."
    
    local errors=0
    
    # Check required tools
    for tool in curl jq bc python3 docker; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed"
            ((errors++))
        else
            info "✓ $tool is available"
        fi
    done
    
    # Check wrk specifically
    if ! command -v wrk &> /dev/null; then
        error "wrk is not installed"
        ((errors++))
    else
        info "✓ wrk is available"
    fi
    
    # Check system resources
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$memory_gb" -lt 4 ]; then
        warn "System has less than 4GB RAM. Testing may be limited."
    else
        info "✓ Sufficient memory: ${memory_gb}GB"
    fi
    
    local disk_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$disk_space" -lt 5 ]; then
        warn "Less than 5GB disk space available"
    else
        info "✓ Sufficient disk space: ${disk_space}GB"
    fi
    
    # Check Docker
    if docker ps >/dev/null 2>&1; then
        info "✓ Docker is accessible"
    else
        warn "Docker is not accessible. May need to add user to docker group."
    fi
    
    if [ $errors -gt 0 ]; then
        error "$errors critical dependencies missing"
        return 1
    fi
    
    info "✓ Environment validation passed"
    return 0
}

# Create test configuration
create_test_config() {
    log "Creating test configuration..."
    
    cat > "test-config.env" << EOF
# Test Environment Configuration
# Generated by setup-testing.sh on $(date)

# System Information
OS=$(detect_os)
CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
MEMORY_GB=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "unknown")

# Docker Configuration  
DOCKER_NETWORK=parking-iot-test
MQTT_CONTAINER_NAME=mosquitto-test
MQTT_IMAGE=eclipse-mosquitto:latest

# Test Parameters
DEFAULT_TEST_DURATION=60
DEFAULT_RPS_LEVELS="10 50 100 200 500"
MEMORY_PROFILING_DURATION=300

# Results Configuration
RESULTS_BASE_DIR=test-results
COMPRESS_RESULTS=false
KEEP_RAW_DATA=true

# CI/CD Integration
UPLOAD_RESULTS=false
NOTIFY_ON_COMPLETION=false
EOF

    info "Test configuration created: test-config.env"
}

# Setup results directories
setup_directories() {
    log "Setting up results directories..."
    
    local dirs=(
        "stress-test-results"
        "load-test-scenarios" 
        "memory-profiling-results"
        "performance-comparison"
        "test-logs"
        "test-artifacts"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        info "Created directory: $dir"
    done
    
    # Create .gitignore for results
    cat > "test-results.gitignore" << EOF
# Test Results - Add to main .gitignore if needed
stress-test-results/
load-test-scenarios/
memory-profiling-results/
performance-comparison/
test-logs/
test-artifacts/
*.log
*.csv
*.json
*.txt
*.gz
*.zip
EOF

    info "Results directories created"
}

# Validate implementations
validate_implementations() {
    log "Validating implementations..."
    
    # Check Node.js
    if [ -f "package.json" ] && [ -f "index.js" ]; then
        info "✓ Node.js implementation found"
        if [ ! -d "node_modules" ]; then
            info "Installing Node.js dependencies..."
            npm install
        fi
    else
        warn "Node.js implementation not found"
    fi
    
    # Check Go
    if [ -f "go.mod" ] && [ -f "main.go" ]; then
        info "✓ Go implementation found"
        if command -v go &> /dev/null; then
            go mod tidy
            info "Go dependencies updated"
        else
            warn "Go compiler not found"
        fi
    else
        warn "Go implementation not found"
    fi
    
    # Check Rust
    if [ -f "Cargo.toml" ] && [ -d "src" ]; then
        info "✓ Rust implementation found"
        if command -v cargo &> /dev/null; then
            cargo check
            info "Rust dependencies validated"
        else
            warn "Rust compiler not found"
        fi
    else
        warn "Rust implementation not found"
    fi
}

# Run quick test
run_quick_test() {
    log "Running quick validation test..."
    
    if [ ! -x "./stress-test.sh" ]; then
        error "stress-test.sh not found or not executable"
        return 1
    fi
    
    # Start MQTT broker for test
    docker run -d --name mosquitto-setup-test -p 1883:1883 eclipse-mosquitto:latest >/dev/null 2>&1
    sleep 3
    
    # Test if we can run a basic validation
    if ./stress-test.sh --help >/dev/null 2>&1; then
        info "✓ Stress testing script is functional"
    else
        error "Stress testing script validation failed"
    fi
    
    # Cleanup
    docker stop mosquitto-setup-test >/dev/null 2>&1
    docker rm mosquitto-setup-test >/dev/null 2>&1
    
    info "Quick test completed"
}

# Main setup function
main() {
    echo "🚀 Parking IoT Stress Testing Setup"
    echo "==================================="
    echo
    
    info "This script will install and configure the comprehensive stress testing suite"
    echo
    
    # Prompt for confirmation
    read -p "Continue with setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Setup cancelled"
        exit 0
    fi
    
    # Run setup steps
    install_dependencies
    setup_docker
    validate_environment || {
        error "Environment validation failed"
        exit 1
    }
    
    create_test_config
    setup_directories
    validate_implementations
    run_quick_test
    
    echo
    echo "✅ Setup completed successfully!"
    echo
    info "Next steps:"
    echo "  1. Run quick benchmark: make quick-benchmark"
    echo "  2. Full comparison: make performance-comparison"
    echo "  3. Check testing guide: cat TESTING.md"
    echo "  4. View available commands: make help"
    echo
    info "If you added user to docker group, please logout and login again"
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
Stress Testing Suite Setup Script

USAGE:
    $0              # Run interactive setup
    $0 --quiet      # Run non-interactive setup
    $0 --check      # Check current environment only

DESCRIPTION:
    This script installs and configures the comprehensive stress testing
    suite for the Parking IoT project. It will install dependencies,
    setup Docker, validate the environment, and prepare for testing.

DEPENDENCIES INSTALLED:
    - wrk (HTTP load testing)
    - curl, jq, bc (utilities)
    - python3, pip3 (MQTT testing)
    - docker (containerization)
    - htop, lsof (monitoring)
    - valgrind (memory analysis)

REQUIREMENTS:
    - sudo access (for package installation)
    - Internet connection (for downloads)
    - At least 4GB RAM recommended
    - At least 5GB free disk space

SUPPORTED SYSTEMS:
    - Ubuntu/Debian (apt-get)
    - CentOS/RHEL (yum)
    - macOS (homebrew)
    - Other Linux (manual installation guidance)
EOF
    exit 0
fi

# Handle command line arguments
case "${1:-}" in
    "--quiet")
        # Non-interactive mode
        install_dependencies
        setup_docker
        validate_environment
        create_test_config
        setup_directories
        validate_implementations
        ;;
    "--check")
        # Check only mode
        validate_environment
        validate_implementations
        ;;
    *)
        # Interactive mode
        main
        ;;
esac