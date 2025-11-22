#!/bin/bash
cd /home/shiva/reddit
echo "Building project with gleam_httpc dependency..."
gleam build 2>&1
echo ""
echo "Build complete. Exit code: $?"

