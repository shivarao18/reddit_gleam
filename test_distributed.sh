#!/bin/bash
# Test script: Start engine + 2 clients to demonstrate data sharing
# This proves that multiple clients share the same engine data

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   Reddit Clone - Distributed Architecture Test           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Clean up any previous runs
pkill -f "reddit_engine_standalone" 2>/dev/null
pkill -f "reddit_client_process" 2>/dev/null
sleep 1

# Create logs directory
mkdir -p logs
rm -f logs/*.log

# Build first
echo "📦 Building project..."
gleam build
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build successful"
echo ""

# Start engine in background
echo "🚀 Step 1: Starting Engine Process..."
gleam run -m reddit_engine_standalone > logs/engine.log 2>&1 &
ENGINE_PID=$!
echo "   Engine PID: $ENGINE_PID"

# Wait for engine to initialize
echo "   Waiting for engine to initialize..."
sleep 3

# Check if engine is still running
if ! kill -0 $ENGINE_PID 2>/dev/null; then
    echo "❌ Engine failed to start! Check logs/engine.log"
    cat logs/engine.log
    exit 1
fi
echo "✅ Engine running"
echo ""

# Start Client 1
echo "🔌 Step 2: Starting Client Process #1..."
sleep 1
gleam run -m reddit_client_process > logs/client1.log 2>&1 &
CLIENT1_PID=$!
echo "   Client 1 PID: $CLIENT1_PID"
echo "   (Running in background, check logs/client1.log)"
echo ""

# Start Client 2
echo "🔌 Step 3: Starting Client Process #2..."
sleep 1
gleam run -m reddit_client_process > logs/client2.log 2>&1 &
CLIENT2_PID=$!
echo "   Client 2 PID: $CLIENT2_PID"
echo "   (Running in background, check logs/client2.log)"
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   ✅ All Processes Started!                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Engine: PID $ENGINE_PID (logs/engine.log)"
echo "Client 1: PID $CLIENT1_PID (logs/client1.log)"
echo "Client 2: PID $CLIENT2_PID (logs/client2.log)"
echo ""
echo "📊 Monitoring simulation..."
echo "   Clients will run for ~10-15 seconds"
echo ""

# Wait for clients to finish (they exit automatically)
wait $CLIENT1_PID 2>/dev/null
wait $CLIENT2_PID 2>/dev/null

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   📋 Simulation Complete - Check Results                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Show engine log summary
echo "=== Engine Log (last 20 lines) ==="
tail -n 20 logs/engine.log
echo ""

# Show client 1 feed (to prove data sharing)
echo "=== Client 1 Feed (should show posts from both clients) ==="
grep -A 30 "SAMPLE USER FEED" logs/client1.log | head -35
echo ""

# Show client 2 feed
echo "=== Client 2 Feed (should show posts from both clients) ==="
grep -A 30 "SAMPLE USER FEED" logs/client2.log | head -35
echo ""

# Cleanup
echo "🧹 Cleaning up..."
kill $ENGINE_PID 2>/dev/null
echo "✅ Engine stopped"
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   ✅ Test Complete!                                       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Full logs available in ./logs/"
echo "   - logs/engine.log"
echo "   - logs/client1.log"
echo "   - logs/client2.log"
echo ""
echo "🔍 Look for usernames from BOTH clients in the feeds to confirm data sharing!"

