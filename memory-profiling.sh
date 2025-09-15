#!/bin/bash

# Advanced Memory Profiling for Parking IoT Implementations
# Detailed memory usage analysis, leak detection, and optimization insights

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

RESULTS_DIR="memory-profiling-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DURATION=${2:-300}  # 5 minutes default

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

highlight() {
    echo -e "${PURPLE}$1${NC}"
}

# Get detailed process memory information
get_detailed_memory() {
    local pid=$1
    local implementation=$2
    
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Process not running"
        return 1
    fi
    
    # Get memory information from /proc/$pid/status
    local status_file="/proc/$pid/status"
    local smaps_file="/proc/$pid/smaps"
    
    if [ -f "$status_file" ]; then
        local vmrss=$(grep "VmRSS:" "$status_file" | awk '{print $2}')
        local vmsize=$(grep "VmSize:" "$status_file" | awk '{print $2}')
        local vmhwm=$(grep "VmHWM:" "$status_file" | awk '{print $2}')
        local vmpeak=$(grep "VmPeak:" "$status_file" | awk '{print $2}')
        local vmdata=$(grep "VmData:" "$status_file" | awk '{print $2}')
        local vmstk=$(grep "VmStk:" "$status_file" | awk '{print $2}')
        local vmexe=$(grep "VmExe:" "$status_file" | awk '{print $2}')
        local vmlib=$(grep "VmLib:" "$status_file" | awk '{print $2}')
        
        # Convert KB to MB
        vmrss=$((vmrss / 1024))
        vmsize=$((vmsize / 1024))
        vmhwm=$((vmhwm / 1024))
        vmpeak=$((vmpeak / 1024))
        vmdata=$((vmdata / 1024))
        vmstk=$((vmstk / 1024))
        vmexe=$((vmexe / 1024))
        vmlib=$((vmlib / 1024))
        
        echo "$implementation,$vmrss,$vmsize,$vmhwm,$vmpeak,$vmdata,$vmstk,$vmexe,$vmlib"
    else
        echo "$implementation,0,0,0,0,0,0,0,0"
    fi
}

# Memory leak detection
detect_memory_leaks() {
    local impl=$1
    local pid=$2
    local samples=$3
    local interval=$4
    
    log "Running memory leak detection for $impl (PID: $pid)"
    
    local leak_file="$RESULTS_DIR/${impl}_leak_detection.csv"
    echo "sample,timestamp,rss_mb,growth_mb,growth_rate" > "$leak_file"
    
    local initial_memory=$(ps -o rss --pid "$pid" --no-headers | awk '{print $1/1024}')
    local previous_memory=$initial_memory
    
    for i in $(seq 1 "$samples"); do
        if ! kill -0 "$pid" 2>/dev/null; then
            warn "Process $pid died during leak detection"
            break
        fi
        
        local current_memory=$(ps -o rss --pid "$pid" --no-headers | awk '{print $1/1024}')
        local growth=$((current_memory - initial_memory))
        local growth_rate=$((current_memory - previous_memory))
        local timestamp=$(date +%s)
        
        echo "$i,$timestamp,$current_memory,$growth,$growth_rate" >> "$leak_file"
        
        previous_memory=$current_memory
        sleep "$interval"
    done
    
    # Analyze leak pattern
    local avg_growth=$(tail -n +2 "$leak_file" | cut -d',' -f5 | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    local max_growth=$(tail -n +2 "$leak_file" | cut -d',' -f4 | sort -nr | head -1)
    
    info "Memory Leak Analysis for $impl:"
    info "  Average growth per interval: ${avg_growth}MB"
    info "  Maximum total growth: ${max_growth}MB"
    
    if (( $(echo "$avg_growth > 1" | bc -l) )); then
        warn "Potential memory leak detected! Average growth: ${avg_growth}MB per ${interval}s"
    else
        info "No significant memory leak detected"
    fi
}

# Heap analysis for different implementations
analyze_heap() {
    local impl=$1
    local pid=$2
    
    log "Analyzing heap usage for $impl implementation"
    
    case $impl in
        "nodejs")
            analyze_nodejs_heap "$pid"
            ;;
        "go")
            analyze_go_heap "$pid"
            ;;
        "rust")
            analyze_rust_heap "$pid"
            ;;
    esac
}

# Node.js specific heap analysis
analyze_nodejs_heap() {
    local pid=$1
    
    info "Node.js heap analysis..."
    
    # Try to get V8 heap statistics if possible
    if command -v node &> /dev/null; then
        # Create heap analysis script
        cat > "$RESULTS_DIR/nodejs_heap_analysis.js" << 'EOF'
const v8 = require('v8');
const process = require('process');

function analyzeHeap() {
    const heapStats = v8.getHeapStatistics();
    const heapSpaceStats = v8.getHeapSpaceStatistics();
    
    console.log('=== Node.js Heap Analysis ===');
    console.log(`Total Heap Size: ${(heapStats.total_heap_size / 1024 / 1024).toFixed(2)} MB`);
    console.log(`Used Heap Size: ${(heapStats.used_heap_size / 1024 / 1024).toFixed(2)} MB`);
    console.log(`Heap Size Limit: ${(heapStats.heap_size_limit / 1024 / 1024).toFixed(2)} MB`);
    console.log(`Total Available Size: ${(heapStats.total_available_size / 1024 / 1024).toFixed(2)} MB`);
    
    console.log('\n=== Heap Spaces ===');
    heapSpaceStats.forEach(space => {
        console.log(`${space.space_name}:`);
        console.log(`  Size: ${(space.space_size / 1024 / 1024).toFixed(2)} MB`);
        console.log(`  Used: ${(space.space_used_size / 1024 / 1024).toFixed(2)} MB`);
        console.log(`  Available: ${(space.space_available_size / 1024 / 1024).toFixed(2)} MB`);
    });
    
    console.log('\n=== Memory Usage ===');
    const memUsage = process.memoryUsage();
    console.log(`RSS: ${(memUsage.rss / 1024 / 1024).toFixed(2)} MB`);
    console.log(`Heap Total: ${(memUsage.heapTotal / 1024 / 1024).toFixed(2)} MB`);
    console.log(`Heap Used: ${(memUsage.heapUsed / 1024 / 1024).toFixed(2)} MB`);
    console.log(`External: ${(memUsage.external / 1024 / 1024).toFixed(2)} MB`);
}

// Run analysis every 10 seconds for 2 minutes
let count = 0;
const interval = setInterval(() => {
    console.log(`\n--- Sample ${++count} ---`);
    analyzeHeap();
    
    if (count >= 12) {  // 2 minutes of samples
        clearInterval(interval);
        process.exit(0);
    }
}, 10000);

// Initial analysis
analyzeHeap();
EOF
        
        # Note: This would need to be integrated into the actual Node.js app
        # For now, just document the analysis capability
        info "Node.js heap analysis script created: $RESULTS_DIR/nodejs_heap_analysis.js"
        info "To use: integrate this into your Node.js application for detailed heap analysis"
    fi
    
    # Alternative: use external tools
    if command -v pmap &> /dev/null; then
        info "Memory mapping analysis:"
        pmap -d "$pid" > "$RESULTS_DIR/nodejs_memory_map.txt" 2>/dev/null || warn "Could not generate memory map"
    fi
}

# Go specific heap analysis
analyze_go_heap() {
    local pid=$1
    
    info "Go heap analysis..."
    
    # Check if the Go binary has profiling enabled
    # Note: This requires the Go app to have pprof enabled
    if curl -s "http://localhost:6060/debug/pprof/heap" >/dev/null 2>&1; then
        info "Collecting Go heap profile..."
        curl -s "http://localhost:6060/debug/pprof/heap" > "$RESULTS_DIR/go_heap_profile.pb.gz"
        
        if command -v go &> /dev/null; then
            # Analyze the heap profile
            go tool pprof -text "$RESULTS_DIR/go_heap_profile.pb.gz" > "$RESULTS_DIR/go_heap_analysis.txt" 2>/dev/null || {
                warn "Could not analyze Go heap profile"
            }
        fi
    else
        warn "Go pprof endpoint not available. Consider adding pprof to your Go application:"
        info "  import _ \"net/http/pprof\""
        info "  go func() { log.Println(http.ListenAndServe(\"localhost:6060\", nil)) }()"
    fi
    
    # Use external tools for basic analysis
    if command -v pmap &> /dev/null; then
        pmap -d "$pid" > "$RESULTS_DIR/go_memory_map.txt" 2>/dev/null || warn "Could not generate memory map"
    fi
}

# Rust specific heap analysis
analyze_rust_heap() {
    local pid=$1
    
    info "Rust heap analysis..."
    
    # Rust doesn't have built-in profiling like Go, but we can use external tools
    if command -v valgrind &> /dev/null; then
        warn "Valgrind analysis would require restarting the application with valgrind"
        info "To profile Rust memory usage, restart with:"
        info "  valgrind --tool=massif ./target/release/parking-iot-rust"
    fi
    
    # Use pmap for memory layout analysis
    if command -v pmap &> /dev/null; then
        pmap -d "$pid" > "$RESULTS_DIR/rust_memory_map.txt" 2>/dev/null || warn "Could not generate memory map"
    fi
    
    # Check if jemalloc profiling is available (if using jemalloc)
    if [ -f "/proc/$pid/environ" ]; then
        local jemalloc_conf=$(grep -z MALLOC_CONF "/proc/$pid/environ" 2>/dev/null || echo "")
        if [[ "$jemalloc_conf" == *"prof:true"* ]]; then
            info "jemalloc profiling detected"
        else
            info "For detailed Rust memory profiling, consider using jemalloc with profiling enabled"
        fi
    fi
}

# Memory stress testing
run_memory_stress() {
    local impl=$1
    local pid=$2
    local port=${3:-3000}
    
    log "Running memory stress test for $impl"
    
    # Create memory stress script that generates load to trigger allocations
    cat > "$RESULTS_DIR/memory_stress.py" << 'EOF'
#!/usr/bin/env python3
import requests
import threading
import time
import sys
import random

class MemoryStressTester:
    def __init__(self, base_url, duration=300, threads=10):
        self.base_url = base_url
        self.duration = duration
        self.threads = threads
        self.running = True
        self.requests_sent = 0
        
    def make_requests(self):
        """Make various HTTP requests to stress memory allocation"""
        while self.running:
            try:
                # Mix of different request types
                if random.random() < 0.8:
                    # Regular page requests
                    response = requests.get(f"{self.base_url}/", timeout=5)
                else:
                    # Request static files
                    response = requests.get(f"{self.base_url}/index.html", timeout=5)
                
                if response.status_code == 200:
                    self.requests_sent += 1
                
            except Exception as e:
                pass  # Ignore errors, focus on memory pressure
            
            time.sleep(random.uniform(0.1, 0.5))
    
    def run_test(self):
        """Run the memory stress test"""
        print(f"Starting memory stress test with {self.threads} threads for {self.duration}s")
        
        # Start worker threads
        threads = []
        for i in range(self.threads):
            t = threading.Thread(target=self.make_requests)
            t.start()
            threads.append(t)
        
        # Run for specified duration
        time.sleep(self.duration)
        self.running = False
        
        # Wait for threads to finish
        for t in threads:
            t.join(timeout=10)
        
        print(f"Memory stress test completed. Requests sent: {self.requests_sent}")
        return self.requests_sent

if __name__ == "__main__":
    port = sys.argv[1] if len(sys.argv) > 1 else "3000"
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    
    tester = MemoryStressTester(f"http://localhost:{port}", duration, 10)
    tester.run_test()
EOF
    
    chmod +x "$RESULTS_DIR/memory_stress.py"
    
    # Start memory monitoring before stress test
    local monitor_file="$RESULTS_DIR/${impl}_memory_stress.csv"
    echo "timestamp,rss_mb,vsz_mb,cpu_percent" > "$monitor_file"
    
    # Start monitoring in background
    (
        while kill -0 "$pid" 2>/dev/null && [ -f "$monitor_file" ]; do
            local timestamp=$(date +%s)
            local memory=$(ps -o rss,vsz,pcpu --pid "$pid" --no-headers | awk '{print $1/1024, $2/1024, $3}')
            echo "$timestamp,$memory" >> "$monitor_file"
            sleep 2
        done
    ) &
    local monitor_pid=$!
    
    # Run stress test
    if command -v python3 &> /dev/null; then
        python3 "$RESULTS_DIR/memory_stress.py" "$port" 120  # 2 minutes of stress
    else
        warn "Python3 not available, using curl for basic stress"
        for i in {1..100}; do
            curl -s "http://localhost:$port" >/dev/null &
            sleep 1
        done
        wait
    fi
    
    # Stop monitoring
    kill "$monitor_pid" 2>/dev/null || true
    rm -f "$monitor_file.tmp"
    
    # Analyze stress test results
    if [ -f "$monitor_file" ]; then
        local initial_memory=$(tail -n +2 "$monitor_file" | head -1 | cut -d',' -f2)
        local peak_memory=$(tail -n +2 "$monitor_file" | cut -d',' -f2 | sort -nr | head -1)
        local memory_increase=$(echo "$peak_memory - $initial_memory" | bc)
        
        info "Memory Stress Test Results for $impl:"
        info "  Initial memory: ${initial_memory}MB"
        info "  Peak memory: ${peak_memory}MB"
        info "  Memory increase: ${memory_increase}MB"
    fi
}

# Generate comprehensive memory report
generate_memory_report() {
    local impl=$1
    local report_file="$RESULTS_DIR/${impl}_memory_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# Comprehensive Memory Analysis Report - $impl Implementation

**Generated:** $(date)
**Implementation:** $impl
**Analysis Duration:** ${DURATION}s

## Memory Profiling Overview

This report provides detailed memory usage analysis for the $impl implementation of the Parking IoT system, including:

- Detailed memory usage breakdown
- Memory leak detection
- Heap analysis (implementation-specific)
- Memory stress testing results
- Performance recommendations

## Test Configuration

- **Monitoring Duration:** ${DURATION} seconds
- **Sampling Interval:** 2 seconds
- **Memory Stress Test:** 120 seconds
- **System:** $(uname -a)

EOF

    # Add implementation-specific analysis
    case $impl in
        "nodejs")
            cat >> "$report_file" << EOF
## Node.js Specific Analysis

### V8 Heap Statistics
Node.js uses the V8 JavaScript engine with garbage collection. Key memory areas:

- **Heap Total**: Total heap allocated by V8
- **Heap Used**: Currently used heap memory
- **RSS**: Resident Set Size (physical memory)
- **External**: Memory used by C++ objects bound to JavaScript

EOF
            ;;
        "go")
            cat >> "$report_file" << EOF
## Go Specific Analysis

### Go Runtime Memory Management
Go uses a concurrent garbage collector with:

- **Heap Memory**: Managed by Go GC
- **Stack Memory**: Goroutine stacks
- **Off-heap**: CGO allocations and runtime

For detailed profiling, enable pprof in your Go application:
\`\`\`go
import _ "net/http/pprof"
go func() { log.Println(http.ListenAndServe("localhost:6060", nil)) }()
\`\`\`

EOF
            ;;
        "rust")
            cat >> "$report_file" << EOF
## Rust Specific Analysis

### Rust Memory Management
Rust uses deterministic memory management without garbage collection:

- **Zero-cost abstractions**: No runtime overhead
- **Stack allocation**: Most data on stack when possible
- **Heap allocation**: Via Box, Vec, etc.
- **No garbage collector**: Memory freed deterministically

For detailed profiling, consider using:
- jemalloc with profiling enabled
- Valgrind massif tool
- heaptrack for heap analysis

EOF
            ;;
    esac
    
    # Add results sections
    if [ -f "$RESULTS_DIR/${impl}_detailed_memory.csv" ]; then
        cat >> "$report_file" << EOF
## Detailed Memory Usage

EOF
        # Add memory usage table
        echo "| Metric | Value |" >> "$report_file"
        echo "|--------|-------|" >> "$report_file"
        
        if [ -f "$RESULTS_DIR/${impl}_memory_stress.csv" ]; then
            local avg_rss=$(tail -n +2 "$RESULTS_DIR/${impl}_memory_stress.csv" | cut -d',' -f2 | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
            local peak_rss=$(tail -n +2 "$RESULTS_DIR/${impl}_memory_stress.csv" | cut -d',' -f2 | sort -nr | head -1)
            
            echo "| Average RSS | ${avg_rss}MB |" >> "$report_file"
            echo "| Peak RSS | ${peak_rss}MB |" >> "$report_file"
        fi
    fi
    
    # Add leak detection results
    if [ -f "$RESULTS_DIR/${impl}_leak_detection.csv" ]; then
        cat >> "$report_file" << EOF

## Memory Leak Analysis

Memory leak detection monitors memory growth over time to identify potential leaks.

EOF
        local total_growth=$(tail -1 "$RESULTS_DIR/${impl}_leak_detection.csv" | cut -d',' -f4)
        local avg_growth_rate=$(tail -n +2 "$RESULTS_DIR/${impl}_leak_detection.csv" | cut -d',' -f5 | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
        
        echo "- **Total Memory Growth:** ${total_growth}MB" >> "$report_file"
        echo "- **Average Growth Rate:** ${avg_growth_rate}MB per sample" >> "$report_file"
        
        if (( $(echo "$avg_growth_rate > 0.5" | bc -l) )); then
            echo "- **⚠️ WARNING:** Potential memory leak detected!" >> "$report_file"
        else
            echo "- **✅ GOOD:** No significant memory leak detected" >> "$report_file"
        fi
    fi
    
    # Add recommendations
    cat >> "$report_file" << EOF

## Recommendations

### Memory Optimization

1. **Monitor heap growth**: Use production monitoring to track memory usage over time
2. **Load testing**: Regular stress testing to identify memory issues before production
3. **Profiling tools**: Use implementation-specific profiling tools for detailed analysis

### Implementation-Specific Tips

EOF

    case $impl in
        "nodejs")
            cat >> "$report_file" << EOF
**Node.js:**
- Monitor V8 heap usage with \`process.memoryUsage()\`
- Use \`--max-old-space-size\` to limit heap size
- Consider clustering for better memory utilization
- Use streaming for large data processing

EOF
            ;;
        "go")
            cat >> "$report_file" << EOF
**Go:**
- Use \`runtime.ReadMemStats()\` for runtime memory info
- Enable pprof for detailed heap profiling
- Consider sync.Pool for object reuse
- Use \`GOGC\` environment variable to tune GC

EOF
            ;;
        "rust")
            cat >> "$report_file" << EOF
**Rust:**
- Use jemalloc for better memory allocation performance
- Profile with Valgrind massif or heaptrack
- Consider using \`Box::leak()\` carefully
- Use \`std::mem::size_of()\` to check struct sizes

EOF
            ;;
    esac
    
    cat >> "$report_file" << EOF
## Test Data Files

- Detailed memory data: \`${impl}_detailed_memory.csv\`
- Leak detection data: \`${impl}_leak_detection.csv\`
- Memory stress data: \`${impl}_memory_stress.csv\`
- Memory mapping: \`${impl}_memory_map.txt\`

All files are located in: \`$RESULTS_DIR/\`
EOF

    log "Memory analysis report generated: $report_file"
}

# Main memory profiling function
run_memory_profiling() {
    local impl=$1
    local duration=${2:-300}
    
    highlight "🧠 Starting Memory Profiling for $impl Implementation"
    
    # Check if implementation is running
    local pid_file="stress-test-results/${impl}_pid"
    if [ ! -f "$pid_file" ]; then
        error "Implementation $impl is not running. Please start it first."
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    if ! kill -0 "$pid" 2>/dev/null; then
        error "Process $pid is not running"
        return 1
    fi
    
    log "Profiling $impl implementation (PID: $pid) for ${duration}s"
    
    # 1. Collect detailed memory information
    local detailed_file="$RESULTS_DIR/${impl}_detailed_memory.csv"
    echo "timestamp,impl,rss,vsize,hwm,peak,data,stack,exe,lib" > "$detailed_file"
    
    local samples=$((duration / 5))  # Sample every 5 seconds
    for i in $(seq 1 "$samples"); do
        local timestamp=$(date +%s)
        local detailed_memory=$(get_detailed_memory "$pid" "$impl")
        echo "$timestamp,$detailed_memory" >> "$detailed_file"
        sleep 5
    done &
    local detailed_monitor_pid=$!
    
    # 2. Run memory leak detection
    detect_memory_leaks "$impl" "$pid" $((duration / 10)) 10 &
    local leak_detection_pid=$!
    
    # 3. Run heap analysis
    analyze_heap "$impl" "$pid" &
    local heap_analysis_pid=$!
    
    # 4. Run memory stress testing
    sleep 30  # Let initial monitoring settle
    run_memory_stress "$impl" "$pid" 3000 &
    local stress_test_pid=$!
    
    # Wait for all analysis to complete
    log "Waiting for memory profiling to complete..."
    wait "$detailed_monitor_pid" 2>/dev/null || true
    wait "$leak_detection_pid" 2>/dev/null || true
    wait "$heap_analysis_pid" 2>/dev/null || true
    wait "$stress_test_pid" 2>/dev/null || true
    
    # Generate comprehensive report
    generate_memory_report "$impl"
    
    log "Memory profiling completed for $impl"
}

# Show usage
show_usage() {
    cat << EOF
Advanced Memory Profiling for Parking IoT

USAGE:
    $0 <implementation> [duration]

IMPLEMENTATIONS:
    nodejs, go, rust

PARAMETERS:
    duration    Profiling duration in seconds (default: 300)

EXAMPLES:
    $0 rust 600         # Profile Rust for 10 minutes
    $0 go 300           # Profile Go for 5 minutes
    $0 nodejs 1800      # Profile Node.js for 30 minutes

FEATURES:
    - Detailed memory usage tracking
    - Memory leak detection
    - Implementation-specific heap analysis
    - Memory stress testing
    - Comprehensive reporting

REQUIREMENTS:
    - Implementation must be running
    - Python3 (for stress testing)
    - bc (for calculations)
    - Optional: valgrind, pmap for detailed analysis

OUTPUT:
    Results saved in: memory-profiling-results/
EOF
}

# Main execution
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]] || [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

IMPLEMENTATION=$1
DURATION=${2:-300}

if [[ ! "$IMPLEMENTATION" =~ ^(nodejs|go|rust)$ ]]; then
    error "Invalid implementation: $IMPLEMENTATION"
    show_usage
    exit 1
fi

if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || [ "$DURATION" -lt 60 ]; then
    error "Duration must be a number >= 60 seconds"
    exit 1
fi

run_memory_profiling "$IMPLEMENTATION" "$DURATION"