#!/bin/bash
# Start a Reddit Client Process
# The engine MUST be running first!

echo "🔌 Starting Reddit Client Process"
echo ""

# Build first
gleam build

# Generate random client ID
CLIENT_ID=${1:-$RANDOM}

# Run the client with Erlang distributed mode
erl -name client${CLIENT_ID}@127.0.0.1 \
    -setcookie reddit_distributed_secret_2024 \
    -pa build/dev/erlang/*/ebin \
    -eval "reddit_client_process:main()." \
    -noshell

