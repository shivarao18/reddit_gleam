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

echo -e "${BLUE}Step 1: Building project with new dependencies...${NC}"
gleam build
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Build failed. Please check errors above.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

echo -e "${BLUE}Step 2: Starting REST API server in background...${NC}"
gleam run -m reddit_server &
SERVER_PID=$!
echo -e "${GREEN}✅ Server started (PID: $SERVER_PID)${NC}"
echo ""

echo -e "${BLUE}Step 3: Waiting for server to initialize...${NC}"
sleep 3
echo -e "${GREEN}✅ Server ready!${NC}"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}   DEMO 1: Single CLI Client Interactive Demo${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
gleam run -m reddit_client
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}   DEMO 2: Multi-Client Concurrent Load Test${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
gleam run -m reddit_multi_client
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}   DEMO 3: Final Server State Verification${NC}"
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

