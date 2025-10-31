#!/bin/bash
# Start the Reddit Engine in distributed mode
# This must be running before clients can connect

echo "🚀 Starting Reddit Engine (Distributed Mode)"
echo ""

# Build first
gleam build

# Run the engine
gleam run -m reddit_engine_standalone

