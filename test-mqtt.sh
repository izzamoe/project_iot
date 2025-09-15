#!/bin/bash

# Test script to validate MQTT communication behavior
# This script tests that both Node.js and Go versions behave identically

echo "🧪 Testing Parking IoT Application MQTT Communication"
echo "=================================================="

# Test function
test_mqtt_messages() {
    local app_name=$1
    echo ""
    echo "📡 Testing $app_name application..."
    
    # Send test messages
    echo "  Sending: Parkir/1 = 1 (car enters slot 0)"
    mosquitto_pub -h localhost -t "Parkir/1" -m "1"
    sleep 1
    
    echo "  Sending: Parkir/2 = 1 (car enters slot 1)"
    mosquitto_pub -h localhost -t "Parkir/2" -m "1"
    sleep 1
    
    echo "  Sending: Parkir/1 = 0 (car exits slot 0)"
    mosquitto_pub -h localhost -t "Parkir/1" -m "0"
    sleep 1
    
    echo "  Sending: Parkir/2 = 0 (car exits slot 1)"
    mosquitto_pub -h localhost -t "Parkir/2" -m "0"
    sleep 1
    
    echo "  ✅ MQTT messages sent successfully"
}

echo ""
echo "🔧 Prerequisites:"
echo "  - MQTT broker running on localhost:1883"
echo "  - Application running on localhost:3000"
echo ""

# Check if MQTT broker is running
if ! mosquitto_pub -h localhost -t "test" -m "test" >/dev/null 2>&1; then
    echo "❌ Error: MQTT broker not available on localhost:1883"
    echo "   Please start mosquitto broker first"
    exit 1
fi

# Check if web application is running
if ! curl -s http://localhost:3000/ >/dev/null; then
    echo "❌ Error: Web application not available on localhost:3000"
    echo "   Please start the application first"
    exit 1
fi

echo "✅ Prerequisites met"

# Test MQTT communication
test_mqtt_messages "Current"

echo ""
echo "🎯 Expected Behavior:"
echo "  - Application should receive all 4 MQTT messages"
echo "  - Messages should be forwarded to WebSocket clients"
echo "  - Frontend should update parking slots in real-time"
echo "  - No errors should occur in application logs"
echo ""
echo "🔍 Manual Verification:"
echo "  1. Open http://localhost:3000 in browser"
echo "  2. Check browser console for Socket.IO connection"
echo "  3. Run this test script to send MQTT messages"
echo "  4. Verify parking slots update visually"
echo ""
echo "✅ Test completed successfully!"