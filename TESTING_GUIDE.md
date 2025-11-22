# Reddit Clone - Testing Guide for Multiple Clients

## Quick Start

### Option 1: Automated Demo (Recommended)
```bash
chmod +x run_demo.sh
./run_demo.sh
```
This will:
1. Build the project
2. Start the server
3. Run single client demo
4. Run multi-client demo (5 clients sequentially)
5. Run TRUE concurrent demo (3 client programs in parallel)
6. Verify final state

---

## Option 2: Manual Testing

### Step 1: Start the Server
```bash
# Terminal 1
gleam run -m reddit_server
```

### Step 2: Single Client Demo
```bash
# Terminal 2
gleam run -m reddit_client
```
This demonstrates one client performing a complete user journey.

### Step 3: Multi-Client Demo
```bash
# Terminal 2
gleam run -m reddit_multi_client
```
This runs 5 independent clients sequentially (each is a separate HTTP connection).

### Step 4: TRUE Concurrent Clients
Open 3 separate terminals and run simultaneously:
```bash
# Terminal 2
gleam run -m reddit_multi_client

# Terminal 3 (at the same time)
gleam run -m reddit_multi_client

# Terminal 4 (at the same time)
gleam run -m reddit_multi_client
```

Or use background processes:
```bash
gleam run -m reddit_multi_client &
gleam run -m reddit_multi_client &
gleam run -m reddit_multi_client &
wait
```

---

## What Gets Demonstrated

### Single Client (`reddit_client`)
✅ One user (Alice) performing all operations:
- Register
- Create subreddit
- Join subreddit
- Create post
- Add comment
- View feed
- List subreddits

### Multi-Client (`reddit_multi_client`)
✅ 5 independent users connecting to the API:
- Each registers with unique username (`loadtest_user_1`, `loadtest_user_2`, etc.)
- Each creates their own subreddit
- Each joins existing subreddits
- Each creates 3 posts
- Each retrieves their personalized feed

### Concurrent Execution
✅ Multiple instances running simultaneously prove:
- Server handles concurrent HTTP connections
- No race conditions in actor state
- Each client gets correct responses
- Database consistency maintained

---

## Verification Commands

After running demos, check the server state:

```bash
# Health check
curl http://localhost:8080/health

# List all subreddits (should see many from load tests)
curl http://localhost:8080/api/subreddits | jq

# Get specific user info
curl http://localhost:8080/api/auth/user/alice | jq

# Get user's feed
curl http://localhost:8080/api/feed/user_1 | jq
```

---

## Understanding the Architecture

### Why It Works with Multiple Clients

1. **Stateless HTTP**: Each request is independent
2. **Actor Model**: Each engine component (users, posts, etc.) is an actor that processes messages sequentially
3. **OTP Supervision**: Actors are supervised and can handle concurrent messages
4. **Mist Server**: Handles multiple HTTP connections concurrently using Erlang's lightweight processes

### Flow of a Request

```
Client (HTTP) 
  → Mist Server 
    → Router 
      → Handler 
        → Actor (via message) 
          → Engine State 
        ← Response
      ← HTTP Response
    ← HTTP Response
  ← HTTP Response
```

Each arrow is asynchronous and non-blocking!

---

## For the Video Demo

### Recommended Flow:
1. **Show server starting** (Terminal 1)
2. **Run single client** (Terminal 2) - narrate what Alice is doing
3. **Run multi-client** (Terminal 2) - show 5 users creating content
4. **Open multiple terminals** - run clients simultaneously
5. **Show server logs** - prove concurrent requests being processed
6. **Verify final state** - curl commands showing all the data

### Key Points to Highlight:
- ✅ "Originally built as in-process simulator (Part I)"
- ✅ "Converted to REST API server (Part II)"
- ✅ "Now any HTTP client can connect from anywhere"
- ✅ "Server handles concurrent connections with actor model"
- ✅ "Same engine, different interface - demonstrates good architecture"

---

## Troubleshooting

### Server not responding
- Check if already running: `lsof -i :8080`
- Kill existing: `pkill -f reddit_server`
- Restart: `gleam run -m reddit_server`

### Build errors
- Clean build: `gleam clean && gleam build`
- Check dependencies: `gleam deps download`

### Client connection refused
- Ensure server is running on port 8080
- Check firewall settings
- Verify with: `curl http://localhost:8080/health`

---

## Success Criteria

✅ Server starts without errors  
✅ Single client completes all operations  
✅ Multi-client runs 5 users successfully  
✅ Concurrent clients can run simultaneously  
✅ All API endpoints respond correctly  
✅ No crashes or race conditions  
✅ State is consistent after all operations  

If all above pass, Part II is complete! 🎉

