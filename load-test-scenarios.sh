#!/bin/bash

# Advanced Load Testing Scenarios for Parking IoT
# Tests realistic IoT usage patterns and edge cases

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

RESULTS_DIR="load-test-scenarios"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$RESULTS_DIR"

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

# Scenario 1: IoT Device Simulation - Realistic parking lot usage
run_iot_simulation() {
    local impl=$1
    local port=${2:-3000}
    local duration=${3:-300}  # 5 minutes
    
    log "Running IoT Device Simulation for $impl (${duration}s)"
    
    # Create realistic IoT simulation script
    cat > "$RESULTS_DIR/iot_simulation.py" << 'EOF'
#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import time
import random
import threading
import json
import sys
from datetime import datetime

class ParkingLotSimulator:
    def __init__(self, host, port, num_slots=10, duration=300):
        self.host = host
        self.port = port
        self.num_slots = num_slots
        self.duration = duration
        self.parking_state = [0] * num_slots  # 0 = empty, 1 = occupied
        self.client = mqtt.Client()
        self.running = True
        self.events_sent = 0
        
        # Realistic timing patterns
        self.peak_hours = [(8, 10), (12, 14), (17, 19)]  # Rush hours
        self.avg_parking_duration = 120  # 2 hours average
        
    def is_peak_hour(self):
        hour = datetime.now().hour
        return any(start <= hour <= end for start, end in self.peak_hours)
    
    def get_event_probability(self):
        """Higher probability during peak hours"""
        if self.is_peak_hour():
            return 0.3  # 30% chance of event per minute during peak
        return 0.1  # 10% chance during off-peak
    
    def simulate_car_entry(self):
        """Simulate car entering parking lot"""
        empty_slots = [i for i, state in enumerate(self.parking_state) if state == 0]
        if empty_slots:
            slot = random.choice(empty_slots)
            self.parking_state[slot] = 1
            
            # Send MQTT message for slot occupation
            topic = f"Parkir/{1 if slot < 5 else 2}"  # Sensor 1 for slots 0-4, sensor 2 for 5-9
            self.client.publish(topic, "1")
            self.events_sent += 1
            
            # Schedule car exit
            exit_delay = random.expovariate(1.0 / self.avg_parking_duration)
            threading.Timer(exit_delay, self.simulate_car_exit, args=[slot]).start()
            
            return slot
        return None
    
    def simulate_car_exit(self, slot):
        """Simulate car exiting parking lot"""
        if slot < len(self.parking_state) and self.parking_state[slot] == 1:
            self.parking_state[slot] = 0
            
            # Send MQTT message for slot vacation
            topic = f"Parkir/{1 if slot < 5 else 2}"
            self.client.publish(topic, "0")
            self.events_sent += 1
    
    def generate_sensor_noise(self):
        """Simulate occasional sensor noise/false readings"""
        if random.random() < 0.05:  # 5% chance of noise
            topic = random.choice(["Parkir/1", "Parkir/2"])
            # Send same state twice (sensor glitch)
            current_state = random.choice(["0", "1"])
            self.client.publish(topic, current_state)
            time.sleep(0.1)
            self.client.publish(topic, current_state)
            self.events_sent += 2
    
    def run_simulation(self):
        """Main simulation loop"""
        self.client.connect(self.host, self.port, 60)
        start_time = time.time()
        
        while self.running and (time.time() - start_time) < self.duration:
            # Check if we should generate an event
            if random.random() < self.get_event_probability():
                if random.random() < 0.7:  # 70% chance of car entry vs exit
                    self.simulate_car_entry()
                
            # Occasional sensor noise
            self.generate_sensor_noise()
            
            time.sleep(random.uniform(1, 5))  # Variable delay between events
        
        self.running = False
        self.client.disconnect()
        
        return {
            'events_sent': self.events_sent,
            'final_occupancy': sum(self.parking_state),
            'occupancy_rate': sum(self.parking_state) / self.num_slots
        }

if __name__ == "__main__":
    duration = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    simulator = ParkingLotSimulator("localhost", 1883, duration=duration)
    results = simulator.run_simulation()
    print(json.dumps(results))
EOF
    
    chmod +x "$RESULTS_DIR/iot_simulation.py"
    
    # Run simulation
    if command -v python3 &> /dev/null; then
        local results_file="$RESULTS_DIR/${impl}_iot_simulation_${TIMESTAMP}.json"
        python3 "$RESULTS_DIR/iot_simulation.py" "$duration" > "$results_file"
        
        local events_sent=$(jq '.events_sent' "$results_file")
        local occupancy_rate=$(jq '.occupancy_rate' "$results_file")
        
        info "IoT Simulation Results:"
        info "  Events sent: $events_sent"
        info "  Final occupancy rate: $(echo "$occupancy_rate * 100" | bc)%"
    else
        warn "Python3 not available for IoT simulation"
    fi
}

# Scenario 2: Spike Testing - Sudden load increases
run_spike_test() {
    local impl=$1
    local port=${2:-3000}
    
    log "Running Spike Test for $impl"
    
    # Baseline load
    info "Phase 1: Baseline load (10 RPS for 30s)"
    wrk -t2 -c10 -d30s -R10 --latency "http://localhost:$port" > "$RESULTS_DIR/${impl}_spike_baseline.txt"
    
    sleep 5
    
    # Sudden spike
    info "Phase 2: Traffic spike (500 RPS for 30s)"
    wrk -t10 -c100 -d30s -R500 --latency "http://localhost:$port" > "$RESULTS_DIR/${impl}_spike_high.txt"
    
    sleep 5
    
    # Return to baseline
    info "Phase 3: Return to baseline (10 RPS for 30s)"
    wrk -t2 -c10 -d30s -R10 --latency "http://localhost:$port" > "$RESULTS_DIR/${impl}_spike_recovery.txt"
    
    # Analyze spike test results
    info "Spike Test Analysis:"
    echo "Baseline:"
    grep "Requests/sec:" "$RESULTS_DIR/${impl}_spike_baseline.txt"
    echo "Spike:"
    grep "Requests/sec:" "$RESULTS_DIR/${impl}_spike_high.txt"
    echo "Recovery:"
    grep "Requests/sec:" "$RESULTS_DIR/${impl}_spike_recovery.txt"
}

# Scenario 3: Endurance Testing - Long-running stability
run_endurance_test() {
    local impl=$1
    local port=${2:-3000}
    local duration=${3:-1800}  # 30 minutes
    
    log "Running Endurance Test for $impl (${duration}s)"
    
    # Start resource monitoring
    local pid_file="stress-test-results/${impl}_pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        
        # Monitor resources throughout the test
        cat > "$RESULTS_DIR/endurance_monitor.sh" << EOF
#!/bin/bash
echo "timestamp,rss_mb,cpu_percent,connections" > "$RESULTS_DIR/${impl}_endurance_metrics.csv"
end_time=\$(($(date +%s) + $duration))

while [ \$(date +%s) -lt \$end_time ]; do
    if kill -0 $pid 2>/dev/null; then
        timestamp=\$(date +%s)
        memory=\$(ps -o rss --pid $pid --no-headers | awk '{print \$1/1024}')
        cpu=\$(ps -o pcpu --pid $pid --no-headers | awk '{print \$1}')
        connections=\$(netstat -an | grep :$port | grep ESTABLISHED | wc -l)
        echo "\$timestamp,\$memory,\$cpu,\$connections" >> "$RESULTS_DIR/${impl}_endurance_metrics.csv"
    fi
    sleep 30
done
EOF
        
        chmod +x "$RESULTS_DIR/endurance_monitor.sh"
        "$RESULTS_DIR/endurance_monitor.sh" &
        local monitor_pid=$!
    fi
    
    # Constant moderate load for endurance
    info "Applying constant 50 RPS load for ${duration} seconds..."
    wrk -t5 -c25 -d"${duration}s" -R50 --latency "http://localhost:$port" > "$RESULTS_DIR/${impl}_endurance_results.txt"
    
    # Stop monitoring
    kill "$monitor_pid" 2>/dev/null || true
    
    # Analyze endurance results
    info "Endurance Test Completed:"
    grep "Requests/sec:" "$RESULTS_DIR/${impl}_endurance_results.txt"
    grep "Latency" "$RESULTS_DIR/${impl}_endurance_results.txt"
    
    if [ -f "$RESULTS_DIR/${impl}_endurance_metrics.csv" ]; then
        local avg_memory=$(tail -n +2 "$RESULTS_DIR/${impl}_endurance_metrics.csv" | cut -d',' -f2 | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
        local max_memory=$(tail -n +2 "$RESULTS_DIR/${impl}_endurance_metrics.csv" | cut -d',' -f2 | sort -nr | head -1)
        info "Average memory usage: ${avg_memory}MB"
        info "Peak memory usage: ${max_memory}MB"
    fi
}

# Scenario 4: Connection Limit Testing
run_connection_test() {
    local impl=$1
    local port=${2:-3000}
    
    log "Running Connection Limit Test for $impl"
    
    # Test increasing connection counts
    for connections in 50 100 200 500 1000 2000; do
        info "Testing $connections concurrent connections"
        
        timeout 60s wrk -t10 -c"$connections" -d30s --latency "http://localhost:$port" \
            > "$RESULTS_DIR/${impl}_connections_${connections}.txt" 2>&1 || {
            warn "Connection test failed at $connections connections"
            break
        }
        
        local rps=$(grep "Requests/sec:" "$RESULTS_DIR/${impl}_connections_${connections}.txt" | awk '{print $2}')
        local errors=$(grep "Socket errors:" "$RESULTS_DIR/${impl}_connections_${connections}.txt" | wc -l)
        
        info "  $connections connections: $rps RPS, $errors socket errors"
        
        sleep 10  # Cool down between tests
    done
}

# Scenario 5: WebSocket Stress Testing
run_websocket_test() {
    local impl=$1
    local port=${2:-3000}
    
    log "Running WebSocket Stress Test for $impl"
    
    # Create WebSocket stress test script
    cat > "$RESULTS_DIR/websocket_test.js" << 'EOF'
const WebSocket = require('ws');
const process = require('process');

const port = process.argv[2] || 3000;
const numConnections = parseInt(process.argv[3]) || 100;
const duration = parseInt(process.argv[4]) || 60;

let connectedClients = 0;
let messagesReceived = 0;
let connectionErrors = 0;

const results = {
    targetConnections: numConnections,
    actualConnections: 0,
    messagesReceived: 0,
    connectionErrors: 0,
    avgLatency: 0
};

const clients = [];
const latencies = [];

for (let i = 0; i < numConnections; i++) {
    try {
        const ws = new WebSocket(`ws://localhost:${port}/socket.io/?EIO=4&transport=websocket`);
        
        ws.on('open', () => {
            connectedClients++;
            const connectTime = Date.now();
            
            // Send Socket.IO handshake
            ws.send('40');  // Socket.IO connect packet
        });
        
        ws.on('message', (data) => {
            messagesReceived++;
            const receiveTime = Date.now();
            // Calculate latency if this is a response to our message
        });
        
        ws.on('error', (error) => {
            connectionErrors++;
        });
        
        ws.on('close', () => {
            connectedClients--;
        });
        
        clients.push(ws);
        
    } catch (error) {
        connectionErrors++;
    }
}

// Wait for test duration
setTimeout(() => {
    results.actualConnections = connectedClients;
    results.messagesReceived = messagesReceived;
    results.connectionErrors = connectionErrors;
    results.avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length || 0;
    
    console.log(JSON.stringify(results));
    
    // Close all connections
    clients.forEach(ws => {
        try {
            ws.close();
        } catch (e) {}
    });
    
    process.exit(0);
}, duration * 1000);
EOF
    
    # Run WebSocket test if Node.js is available
    if command -v node &> /dev/null; then
        # Install ws package if not available
        if [ ! -d "node_modules/ws" ]; then
            npm install ws >/dev/null 2>&1 || warn "Could not install ws package"
        fi
        
        if [ -d "node_modules/ws" ]; then
            info "Testing WebSocket connections (100 clients for 60s)"
            node "$RESULTS_DIR/websocket_test.js" "$port" 100 60 > "$RESULTS_DIR/${impl}_websocket_results.json"
            
            if [ -f "$RESULTS_DIR/${impl}_websocket_results.json" ]; then
                local actual_connections=$(jq '.actualConnections' "$RESULTS_DIR/${impl}_websocket_results.json")
                local messages_received=$(jq '.messagesReceived' "$RESULTS_DIR/${impl}_websocket_results.json")
                local connection_errors=$(jq '.connectionErrors' "$RESULTS_DIR/${impl}_websocket_results.json")
                
                info "WebSocket Test Results:"
                info "  Successful connections: $actual_connections/100"
                info "  Messages received: $messages_received"
                info "  Connection errors: $connection_errors"
            fi
        else
            warn "WebSocket package not available, skipping WebSocket test"
        fi
    else
        warn "Node.js not available for WebSocket testing"
    fi
}

# Main scenario runner
run_scenarios() {
    local impl=$1
    local scenarios=${2:-"all"}
    
    info "Running load testing scenarios for $impl implementation"
    info "Scenarios: $scenarios"
    
    # Ensure the implementation is running
    local port=3000
    if ! curl -s "http://localhost:$port" >/dev/null; then
        error "$impl implementation is not running on port $port"
        return 1
    fi
    
    case $scenarios in
        "iot"|"all")
            run_iot_simulation "$impl" "$port"
            ;;
    esac
    
    case $scenarios in
        "spike"|"all")
            run_spike_test "$impl" "$port"
            ;;
    esac
    
    case $scenarios in
        "endurance"|"all")
            run_endurance_test "$impl" "$port" 600  # 10 minutes for demo
            ;;
    esac
    
    case $scenarios in
        "connection"|"all")
            run_connection_test "$impl" "$port"
            ;;
    esac
    
    case $scenarios in
        "websocket"|"all")
            run_websocket_test "$impl" "$port"
            ;;
    esac
}

# Generate scenario report
generate_scenario_report() {
    local impl=$1
    local report_file="$RESULTS_DIR/${impl}_scenarios_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# Load Testing Scenarios Report - $impl Implementation

**Generated:** $(date)
**Implementation:** $impl

## Test Scenarios Overview

### 1. IoT Device Simulation
Realistic parking lot usage patterns with:
- Peak hour traffic simulation
- Random car entry/exit events
- Sensor noise simulation
- Occupancy rate tracking

### 2. Spike Testing
Sudden load increase testing:
- Baseline: 10 RPS
- Spike: 500 RPS
- Recovery: Return to baseline

### 3. Endurance Testing
Long-running stability test:
- Constant 50 RPS load
- Resource monitoring over time
- Memory leak detection

### 4. Connection Limit Testing
Maximum concurrent connection testing:
- Progressive connection increase
- Error rate monitoring
- Performance degradation analysis

### 5. WebSocket Stress Testing
Real-time communication testing:
- Multiple WebSocket connections
- Message throughput testing
- Connection stability analysis

## Results Summary

EOF

    # Add results from each scenario if files exist
    if [ -f "$RESULTS_DIR/${impl}_iot_simulation_${TIMESTAMP}.json" ]; then
        echo "### IoT Simulation Results" >> "$report_file"
        echo "\`\`\`json" >> "$report_file"
        cat "$RESULTS_DIR/${impl}_iot_simulation_${TIMESTAMP}.json" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    # Add other scenario results...
    
    info "Scenario report generated: $report_file"
}

# Usage information
show_usage() {
    cat << EOF
Load Testing Scenarios for Parking IoT

USAGE:
    $0 <implementation> [scenario]

IMPLEMENTATIONS:
    nodejs, go, rust

SCENARIOS:
    iot         IoT device simulation with realistic patterns
    spike       Sudden traffic spike testing  
    endurance   Long-running stability test
    connection  Connection limit testing
    websocket   WebSocket stress testing
    all         Run all scenarios (default)

EXAMPLES:
    $0 rust iot              # Run IoT simulation on Rust implementation
    $0 go spike              # Run spike test on Go implementation  
    $0 nodejs all            # Run all scenarios on Node.js implementation

REQUIREMENTS:
    - Implementation must be running on port 3000
    - Python3 (for IoT simulation)
    - Node.js (for WebSocket testing)
    - wrk (for HTTP load testing)
EOF
}

# Main execution
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]] || [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

IMPLEMENTATION=$1
SCENARIOS=${2:-all}

if [[ ! "$IMPLEMENTATION" =~ ^(nodejs|go|rust)$ ]]; then
    error "Invalid implementation: $IMPLEMENTATION"
    show_usage
    exit 1
fi

log "Starting load testing scenarios for $IMPLEMENTATION"
run_scenarios "$IMPLEMENTATION" "$SCENARIOS"
generate_scenario_report "$IMPLEMENTATION"
log "Load testing scenarios completed successfully!"