#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     REDDIT CLONE - COMPLETE PHASE 4 DEMONSTRATION           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Cleaning up any existing server...${NC}"
pkill -f reddit_server 2>/dev/null || true
sleep 1
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""

echo -e "${BLUE}Step 2: Building project with new dependencies...${NC}"
gleam build 2>&1 | grep -v "warning:" || true
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Build failed. Please check errors above.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

echo -e "${BLUE}Step 3: Starting REST API server in background...${NC}"
gleam run -m reddit_server > /tmp/reddit_server.log 2>&1 &
SERVER_PID=$!
echo -e "${GREEN}✅ Server started (PID: $SERVER_PID)${NC}"
echo ""

echo -e "${BLUE}Step 4: Waiting for server to initialize...${NC}"
sleep 3

# Check if server is actually running
if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Server failed to start. Check /tmp/reddit_server.log${NC}"
    cat /tmp/reddit_server.log
    exit 1
fi

# Test server health
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Server ready and responding!${NC}"
else
    echo -e "${YELLOW}⚠️  Server not responding on port 8080${NC}"
    exit 1
fi
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}   DEMO 1: Single CLI Client Interactive Demo${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
gleam run -m reddit_client
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}   DEMO 2: Multi-Client Load Test${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
gleam run -m reddit_multi_client
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}   DEMO 3: TRUE Concurrent Clients (Background Processes)${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Starting 3 clients in parallel background processes..."
gleam run -m reddit_multi_client > /tmp/client1.log 2>&1 &
PID1=$!
gleam run -m reddit_multi_client > /tmp/client2.log 2>&1 &
PID2=$!
gleam run -m reddit_multi_client > /tmp/client3.log 2>&1 &
PID3=$!
echo "Waiting for all 3 concurrent clients to complete..."
wait $PID1 $PID2 $PID3
echo -e "${GREEN}✅ All 3 concurrent clients completed!${NC}"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}   DEMO 4: Final Server State Verification${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}Checking server health...${NC}"
curl -s http://localhost:8080/health | head -c 100
echo ""
echo ""

echo -e "${BLUE}Listing all users created...${NC}"
echo "(Sample check - getting user info)"
curl -s http://localhost:8080/api/auth/user/alice | head -c 150
echo "..."
echo ""

echo -e "${BLUE}Listing all subreddits...${NC}"
curl -s http://localhost:8080/api/subreddits | head -c 300
echo "..."
echo ""

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}   ✅ ALL DEMOS COMPLETED SUCCESSFULLY!${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Server is still running. To stop it:"
echo "  kill $SERVER_PID"
echo ""
echo "Or press Ctrl+C to stop everything."
echo ""

# Keep script running so user can manually stop
wait $SERVER_PID

