# Example Performance Test Results

This file demonstrates the output format and analysis from the comprehensive stress testing suite.

## Quick Benchmark Example

```bash
$ make quick-benchmark
🚀 Starting Comprehensive Parking IoT Stress Test
Implementation: all | Mode: quick

[12:34:56] Starting MQTT broker...
[12:34:58] MQTT broker started

=== Testing nodejs Implementation ===
[12:35:02] Starting nodejs implementation...
✅ nodejs started successfully (PID: 12345)
[12:35:05] Testing load level: 1 RPS
[12:35:35] Testing load level: 5 RPS
[12:36:05] Testing load level: 10 RPS
[12:36:35] Testing load level: 25 RPS
[12:37:05] Testing load level: 50 RPS
[12:37:35] nodejs testing completed

=== Testing go Implementation ===
[12:37:40] Starting go implementation...
✅ go started successfully (PID: 12346)
[12:37:43] Testing load level: 1 RPS
[12:38:13] Testing load level: 5 RPS
[12:38:43] Testing load level: 10 RPS
[12:39:13] Testing load level: 25 RPS
[12:39:43] Testing load level: 50 RPS
[12:40:13] go testing completed

=== Testing rust Implementation ===
[12:40:18] Starting rust implementation...
✅ rust started successfully (PID: 12347)
[12:40:21] Testing load level: 1 RPS
[12:40:51] Testing load level: 5 RPS
[12:41:21] Testing load level: 10 RPS
[12:41:51] Testing load level: 25 RPS
[12:42:21] Testing load level: 50 RPS
[12:42:51] rust testing completed

[12:42:55] Generating comprehensive performance report...
✅ Stress testing completed successfully!
📊 Report available at: stress-test-results/stress_test_report_20240115_123456.md
📁 Detailed results in: stress-test-results/
```

## Sample Performance Results

### HTTP Performance Comparison

| Implementation | Target RPS | Actual RPS | Avg Latency | P99 Latency | Memory (MB) | CPU % |
|----------------|------------|------------|-------------|-------------|-------------|-------|
| **Rust**       | 50         | 49.8       | 8ms         | 15ms        | 12          | 15    |
| **Go**         | 50         | 49.2       | 12ms        | 22ms        | 18          | 22    |
| **Node.js**    | 50         | 47.1       | 28ms        | 45ms        | 68          | 35    |

### Performance Scores

| Implementation | Throughput | Latency | Memory | Stability | Overall |
|----------------|------------|---------|--------|-----------|---------|
| **Rust**       | 95/100     | 92/100  | 98/100 | 99/100    | **96/100** |
| **Go**         | 88/100     | 85/100  | 89/100 | 98/100    | **90/100** |
| **Node.js**    | 78/100     | 65/100  | 45/100 | 95/100    | **71/100** |

### Memory Usage Over Time

```
Rust Implementation:
├── Startup: 8MB
├── Under Load: 12MB (+50%)
├── Peak: 14MB
└── After Load: 9MB (minimal leak)

Go Implementation:
├── Startup: 13MB
├── Under Load: 18MB (+38%)
├── Peak: 22MB
└── After Load: 15MB (GC cleanup)

Node.js Implementation:
├── Startup: 45MB
├── Under Load: 68MB (+51%)
├── Peak: 82MB
└── After Load: 52MB (V8 GC)
```

## MQTT Performance Results

| Implementation | Messages/sec | Success Rate | Latency |
|----------------|--------------|--------------|---------|
| **Rust**       | 1000         | 99.9%        | 2ms     |
| **Go**         | 950          | 99.8%        | 3ms     |
| **Node.js**    | 850          | 99.5%        | 8ms     |

## Key Findings

### 🏆 Performance Winner: Rust
- **Memory**: 85% less memory usage than Node.js
- **Latency**: 71% faster response times
- **Throughput**: 6% higher sustained RPS
- **Stability**: Consistent performance under load

### 🥈 Balanced Choice: Go
- **Memory**: 73% less memory usage than Node.js
- **Development**: Good balance of performance and velocity
- **Concurrency**: Excellent goroutine-based handling
- **Deployment**: Single binary with good performance

### 🥉 Rapid Development: Node.js
- **Development Speed**: Fastest to implement and iterate
- **Ecosystem**: Rich npm package ecosystem
- **Performance**: Adequate for most IoT applications
- **Memory**: Higher overhead but manageable

## Detailed Test Files

The complete test generates these files:

```
stress-test-results/
├── stress_test_report_20240115_123456.md
├── nodejs_http_results.csv
├── nodejs_mqtt_results.csv
├── nodejs_metrics.csv
├── go_http_results.csv
├── go_mqtt_results.csv
├── go_metrics.csv
├── rust_http_results.csv
├── rust_mqtt_results.csv
└── rust_metrics.csv
```

## Running Your Own Tests

### Quick Start
```bash
# Install dependencies
./setup-testing.sh

# Quick comparison
make quick-benchmark

# Full analysis
make performance-comparison
```

### Custom Testing
```bash
# Test specific implementation
./stress-test.sh rust full

# Memory profiling
./memory-profiling.sh rust 600

# Realistic scenarios
./load-test-scenarios.sh go iot
```

### Interpreting Results

1. **Memory Usage**: Lower is better (Rust wins)
2. **Latency**: Lower is better (Rust wins)
3. **Throughput**: Higher is better (Rust wins)
4. **Stability**: Lower error rate is better (All perform well)

Choose based on your priorities:
- **Maximum Performance**: Rust
- **Balanced Development**: Go
- **Rapid Prototyping**: Node.js

All three implementations successfully handle typical IoT workloads, with the choice depending on specific requirements for performance, development velocity, and team expertise.