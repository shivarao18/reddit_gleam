#!/bin/bash
# Distributed Reddit Clone Test Script
# This script runs multiple client processes to simulate a distributed system

echo "=================================================="
echo "  Reddit Clone - Distributed Simulation Test"
echo "=================================================="
echo ""

# Check if gleam is installed
if ! command -v gleam &> /dev/null; then
    echo "❌ Error: Gleam is not installed or not in PATH"
    exit 1
fi

echo "✓ Gleam found"
echo ""

# Build the project first
echo "Building project..."
gleam build
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi
echo "✓ Build successful"
echo ""

# Configuration
NUM_CLIENT_PROCESSES=3
USERS_PER_PROCESS=50
TOTAL_USERS=$((NUM_CLIENT_PROCESSES * USERS_PER_PROCESS))

echo "Configuration:"
echo "  Client Processes: $NUM_CLIENT_PROCESSES"
echo "  Users per Process: $USERS_PER_PROCESS"
echo "  Total Simulated Users: $TOTAL_USERS"
echo ""

# Create a temp directory for logs
LOG_DIR="./simulation_logs"
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log

echo "Logs will be saved to: $LOG_DIR"
echo ""

# Start the engine in the background
echo "Starting engine process..."
gleam run -m reddit_engine_standalone > "$LOG_DIR/engine.log" 2>&1 &
ENGINE_PID=$!
echo "  Engine PID: $ENGINE_PID"
sleep 2

# Check if engine is still running
if ! kill -0 $ENGINE_PID 2>/dev/null; then
    echo "❌ Engine failed to start. Check $LOG_DIR/engine.log"
    exit 1
fi
echo "  ✓ Engine started successfully"
echo ""

# Start multiple client processes
echo "Starting $NUM_CLIENT_PROCESSES client processes..."
CLIENT_PIDS=()

for i in $(seq 1 $NUM_CLIENT_PROCESSES); do
    echo "  Starting client process #$i..."
    gleam run -m reddit_client_process > "$LOG_DIR/client_$i.log" 2>&1 &
    PID=$!
    CLIENT_PIDS+=($PID)
    echo "    PID: $PID"
    sleep 1
done

echo ""
echo "✓ All processes started"
echo ""

# Monitor the processes
echo "Simulation is running..."
echo "Monitoring logs (Ctrl+C to stop):"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo ""
    echo "Stopping all processes..."
    
    # Kill all client processes
    for pid in "${CLIENT_PIDS[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            echo "  Stopping client PID $pid"
            kill $pid 2>/dev/null
        fi
    done
    
    # Kill engine
    if kill -0 $ENGINE_PID 2>/dev/null; then
        echo "  Stopping engine PID $ENGINE_PID"
        kill $ENGINE_PID 2>/dev/null
    fi
    
    echo ""
    echo "All processes stopped"
    echo ""
    echo "=================================================="
    echo "  Simulation Summary"
    echo "=================================================="
    echo ""
    echo "Total Processes: $((NUM_CLIENT_PROCESSES + 1))"
    echo "Client Processes: $NUM_CLIENT_PROCESSES"
    echo "Simulated Users: $TOTAL_USERS"
    echo ""
    echo "Logs saved in: $LOG_DIR/"
    echo "  - engine.log"
    for i in $(seq 1 $NUM_CLIENT_PROCESSES); do
        echo "  - client_$i.log"
    done
    echo ""
    echo "To view logs:"
    echo "  tail -f $LOG_DIR/engine.log"
    echo "  tail -f $LOG_DIR/client_1.log"
    echo ""
    
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Wait for all client processes to finish
echo "Waiting for client processes to complete..."
echo "(Press Ctrl+C to stop manually)"
echo ""

for pid in "${CLIENT_PIDS[@]}"; do
    wait $pid 2>/dev/null
done

# Cleanup when done
cleanup


