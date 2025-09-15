#!/bin/bash

# Quick Memory Benchmark Script
# Compares memory usage between Node.js and Go implementations

echo "🚀 Parking IoT Memory Benchmark"
echo "================================"

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to get memory usage
get_memory() {
    local pid=$1
    if ps -p $pid > /dev/null 2>&1; then
        ps -o rss= -p $pid | tr -d ' '
    else
        echo "0"
    fi
}

# Build Go application if needed
if [ ! -f "parking-iot-go" ]; then
    echo -e "${BLUE}Building Go application...${NC}"
    go build -o parking-iot-go . || exit 1
fi

# Install Node.js dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}Installing Node.js dependencies...${NC}"
    npm install --silent || exit 1
fi

echo -e "${YELLOW}Starting memory comparison...${NC}"
echo

# Test Node.js
echo -e "${BLUE}📊 Testing Node.js Application${NC}"
node index.js > /dev/null 2>&1 &
NODE_PID=$!
sleep 2

if ps -p $NODE_PID > /dev/null 2>&1; then
    NODE_MEMORY=$(get_memory $NODE_PID)
    echo "✅ Node.js Memory Usage: ${NODE_MEMORY} KB ($(echo "scale=1; $NODE_MEMORY/1024" | bc) MB)"
else
    echo "❌ Failed to start Node.js application"
    NODE_MEMORY=0
fi

kill $NODE_PID 2>/dev/null
wait $NODE_PID 2>/dev/null
sleep 1

# Test Go
echo -e "${BLUE}📊 Testing Go Application${NC}"
./parking-iot-go > /dev/null 2>&1 &
GO_PID=$!
sleep 2

if ps -p $GO_PID > /dev/null 2>&1; then
    GO_MEMORY=$(get_memory $GO_PID)
    echo "✅ Go Memory Usage: ${GO_MEMORY} KB ($(echo "scale=1; $GO_MEMORY/1024" | bc) MB)"
else
    echo "❌ Failed to start Go application"
    GO_MEMORY=0
fi

kill $GO_PID 2>/dev/null
wait $GO_PID 2>/dev/null

echo
echo -e "${YELLOW}📈 Results Summary${NC}"
echo "=================="

if [ $NODE_MEMORY -gt 0 ] && [ $GO_MEMORY -gt 0 ]; then
    DIFF=$((NODE_MEMORY - GO_MEMORY))
    PERCENT=$(echo "scale=1; ($DIFF * 100) / $NODE_MEMORY" | bc -l)
    RATIO=$(echo "scale=1; $NODE_MEMORY / $GO_MEMORY" | bc -l)
    
    echo "Node.js: ${NODE_MEMORY} KB"
    echo "Go:      ${GO_MEMORY} KB"
    echo
    echo -e "${GREEN}💾 Memory Reduction: ${DIFF} KB (${PERCENT}%)${NC}"
    echo -e "${GREEN}⚡ Efficiency Ratio: ${RATIO}x better${NC}"
    
    if [ $DIFF -gt 50000 ]; then
        echo -e "${GREEN}🎉 Excellent memory savings!${NC}"
    elif [ $DIFF -gt 20000 ]; then
        echo -e "${GREEN}✨ Good memory savings!${NC}"
    else
        echo -e "${YELLOW}📝 Moderate memory savings.${NC}"
    fi
else
    echo -e "${RED}❌ Could not complete comparison${NC}"
fi

echo
echo -e "${BLUE}📋 Additional Metrics${NC}"
echo "===================="
echo "Go Binary Size: $(du -sh parking-iot-go | cut -f1)"
echo "Node Dependencies: $(du -sh node_modules | cut -f1)"
echo "Go Dependencies: 0 (compiled into binary)"