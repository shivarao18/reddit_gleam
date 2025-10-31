#!/bin/bash
# Start a Reddit Client Process
# The engine MUST be running first!

echo "🔌 Starting Reddit Client Process"
echo ""

# Build first
gleam build

# Run the client
gleam run -m reddit_client_process

