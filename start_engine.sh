#!/bin/bash
# Start the Reddit Engine in distributed mode
# This must be running before clients can connect

echo "🚀 Starting Reddit Engine (Distributed Mode)"
echo ""

# Build first
gleam build

# Run the engine with Erlang distributed mode
erl -name engine@127.0.0.1 \
    -setcookie reddit_distributed_secret_2024 \
    -pa build/dev/erlang/*/ebin \
    -eval "reddit_engine_standalone:main()." \
    -noshell

