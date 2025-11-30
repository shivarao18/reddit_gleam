# Reddit Clone - Demo Script for Video Presentation

## Overview
This demo script will guide you through a 5-minute demonstration showing:
1. How to run the code
2. REST API communication between clients and server
3. All major features working (user registration, subreddits, posts, comments, feed, direct messages)

**Team Members**: Ruchita and Shiva

**Demo Roles**:
- **Person 1 (e.g., Ruchita)**: Narrator - explains concepts and architecture
- **Person 2 (e.g., Shiva)**: Operator - runs commands and shows outputs

---

## Setup (Before Recording)

### Pre-Demo Checklist
1. Close any processes using port 3000
2. Open 3 terminal windows side-by-side:
   - **Terminal 1**: Server logs
   - **Terminal 2**: Client operations
   - **Terminal 3**: Direct API calls (curl)
3. Clear terminal histories for clean recording
4. Ensure `gleam` is in your PATH

---

## Demo Script (5 Minutes)

### Part 1: Introduction & Setup (30 seconds)

**RUCHITA**: "Hi, I'm Ruchita, and this is Shiva. We'll demonstrate our Reddit Clone REST API implementation. This project transforms a message-passing actor system into a full REST API server where clients communicate via HTTP."

**SHIVA** (shows): Project structure
```powershell
# In Terminal 2
ls src/
```

**RUCHITA** (points out key files):
- `reddit_server.gleam` - REST API server
- `reddit_client.gleam` - HTTP client
- `reddit/api/` - API handlers

**RUCHITA**: "We built this using Gleam, a type-safe functional language on the BEAM VM, with Mist for HTTP and Wisp for routing."

---

### Part 2: Starting the Server (30 seconds)

**SHIVA**: "Let me start the REST API server on port 3000."

**SHIVA** (runs in Terminal 1):
```powershell
gleam run -m reddit_server
```

**WAIT** for startup messages showing:
- ✓ User Registry initialized
- ✓ Post Manager initialized
- ✓ Comment Manager initialized
- ✓ DM Manager initialized
- ✓ Feed Generator initialized
- ✓ Subreddit Manager initialized
- ✓ HTTP Server running on http://localhost:3000

**RUCHITA**: "The server initializes 6 engine actors using OTP supervision and starts the HTTP server. Each actor manages a specific domain - users, posts, comments, etc. Notice all actors are ready and the server is listening on port 3000."

---

### Part 3: Health Check (15 seconds)

**RUCHITA**: "Let's verify the server is responding."

**SHIVA** (runs in Terminal 3):
```powershell
curl http://localhost:3000/health
```

**SHIVA** (shows output):
```json
{"status":"ok"}
```

**RUCHITA**: "Perfect! Server is healthy and accepting HTTP requests."

---

### Part 4: User Registration via REST API (45 seconds)

**RUCHITA**: "Now let's create user accounts using the REST API. Shiva, please register three users, and everyone watch the server logs in Terminal 1 as the HTTP POST requests come in."

**SHIVA** (runs in Terminal 3):
```powershell
# Register Alice
curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"alice\"}"

# Register Bob
curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"bob\"}"

# Register Charlie
curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"charlie\"}"
```

**RUCHITA** (points to Terminal 1):
"Notice the server logs showing:
- Incoming POST requests to /api/auth/register
- User registration being processed by the User Registry actor
- JSON responses being generated

This proves all communication happens via HTTP REST API, not direct Erlang messages. Users alice, bob, and charlie are now registered with IDs user_1, user_2, and user_3."

---

### Part 5: Creating Subreddits (30 seconds)

**SHIVA**: "Now I'll create some subreddits using the REST API."

**SHIVA** (runs in Terminal 3):
```powershell
# Create r/gleam
curl -X POST http://localhost:3000/api/subreddits/create -H "Content-Type: application/json" -d "{\"name\":\"gleam\",\"creator_id\":\"user_1\"}"

# Create r/programming
curl -X POST http://localhost:3000/api/subreddits/create -H "Content-Type: application/json" -d "{\"name\":\"programming\",\"creator_id\":\"user_2\"}"
```

**SHIVA** (lists subreddits):
```powershell
curl http://localhost:3000/api/subreddits
```

**RUCHITA**: "Great! Both subreddits were created via REST API calls. The Subreddit Manager actor processed these requests and returned JSON responses."

---

### Part 6: Creating Posts (30 seconds)

**RUCHITA**: "Let's create some posts in these subreddits."

**SHIVA** (runs in Terminal 3):
```powershell
# Create a post in r/gleam
curl -X POST http://localhost:3000/api/posts/create -H "Content-Type: application/json" -d "{\"author_id\":\"user_1\",\"subreddit\":\"gleam\",\"title\":\"Why Gleam is awesome\",\"content\":\"Gleam brings type safety to the BEAM!\"}"

# Create another post
curl -X POST http://localhost:3000/api/posts/create -H "Content-Type: application/json" -d "{\"author_id\":\"user_2\",\"subreddit\":\"programming\",\"title\":\"REST APIs with Gleam\",\"content\":\"Building REST APIs is easy with Mist and Wisp\"}"
```

**RUCHITA** (points to Terminal 1): "Again, notice the server logs showing POST requests being processed by the Post Manager actor. All communication is HTTP-based."

---

### Part 7: Comments & Voting (30 seconds)

**SHIVA**: "Let me add comments and votes via the REST API."

**SHIVA** (runs in Terminal 3):
```powershell
# Add a comment
curl -X POST http://localhost:3000/api/comments/create -H "Content-Type: application/json" -d "{\"author_id\":\"user_3\",\"post_id\":\"post_1\",\"content\":\"Great post!\"}"

# Upvote the post
curl -X POST http://localhost:3000/api/posts/post_1/vote -H "Content-Type: application/json" -d "{\"user_id\":\"user_2\",\"vote_type\":\"upvote\"}"

# Upvote the comment
curl -X POST http://localhost:3000/api/comments/comment_1/vote -H "Content-Type: application/json" -d "{\"user_id\":\"user_1\",\"vote_type\":\"upvote\"}"
```

**RUCHITA**: "All interactions happen through HTTP REST API calls. The Comment Manager handles comments, and karma updates are propagated to the Feed Generator."

---

### Part 8: Personalized Feed (30 seconds)

**RUCHITA**: "Let's check Alice's personalized feed using a GET request."

**SHIVA** (runs in Terminal 3):
```powershell
curl http://localhost:3000/api/feed/user_1
```

**SHIVA** (shows output): JSON with posts ranked by score

**RUCHITA**: "The Feed Generator actor dynamically creates personalized feeds based on karma scores, user subscriptions, and social connections. Notice the posts are ranked by their karma."

---

### Part 9: Direct Messaging (30 seconds)

**SHIVA**: "The system also supports direct messaging between users."

**SHIVA** (runs in Terminal 3):
```powershell
# Send DM from Alice to Bob
curl -X POST http://localhost:3000/api/dm/send -H "Content-Type: application/json" -d "{\"from_user_id\":\"user_1\",\"to_user_id\":\"user_2\",\"content\":\"Hey Bob, check out my post!\"}"

# Send reply from Bob to Alice
curl -X POST http://localhost:3000/api/dm/send -H "Content-Type: application/json" -d "{\"from_user_id\":\"user_2\",\"to_user_id\":\"user_1\",\"content\":\"Thanks Alice, will do!\"}"

# Get Alice's DMs
curl http://localhost:3000/api/dm/user/user_1

# Get conversation between Alice and Bob
curl http://localhost:3000/api/dm/conversation/user_1/user_2
```

**RUCHITA**: "Direct messages are exchanged via REST API with proper conversation threading. The DM Manager maintains all conversations and supports retrieving messages by user or by conversation."

---

### Part 10: Running the Automated Client Demo (45 seconds)

**RUCHITA**: "Now let's run an automated client that demonstrates a complete user workflow via REST API."

**SHIVA** (runs in Terminal 2):
```powershell
gleam run -m reddit_client
```

**RUCHITA** (while it runs, points to both terminals):
"Watch both terminals:
- Terminal 2: Shows the client operations being performed
- Terminal 1: Shows the server logs with incoming HTTP requests

Notice the perfect synchronization - each client operation generates an HTTP request that the server processes. This proves clients communicate via REST API, not direct actor messages. The client uses gleam_httpc library to make HTTP calls."

---

### Part 11: Multi-Client Concurrent Demo (30 seconds)

**SHIVA**: "Finally, let's demonstrate 5 concurrent clients making REST API calls simultaneously."

**SHIVA** (runs in Terminal 2):
```powershell
gleam run -m reddit_multi_client
```

**RUCHITA** (points out):
"This is important - we have:
- 5 independent clients running concurrently
- Each making HTTP requests to the server
- Server handling all concurrent requests using OTP actors
- No race conditions thanks to the actor model

The server successfully handles multiple concurrent clients, all communicating via HTTP REST API. This demonstrates production-ready concurrency."

---

### Part 12: Conclusion (15 seconds)

**RUCHITA**: "To summarize, our demonstration showed:
1. Starting the REST API server with 6 OTP actors
2. All major features: registration, subreddits, posts, comments, voting, feeds, and direct messages
3. Clients communicating exclusively via REST API - HTTP requests and responses
4. Server logs proving all communication is HTTP-based
5. Concurrent client support with proper actor-based concurrency"

**SHIVA**: "We successfully transformed the actor-based simulator into a production-ready REST API server using Gleam, Mist, and Wisp."

**BOTH**: "Thank you!"

---

## Alternative: Quick Demo Using Test Script (1 minute version)

If you need a faster demo or want to show all features quickly:

**RUCHITA**: "Let me show you our automated test suite that validates all REST API functionality."

**SHIVA** (runs):
```powershell
powershell -ExecutionPolicy Bypass -File .\test_all.ps1
```

**RUCHITA** (explains while it runs):
1. "The script builds the project"
2. "Starts the REST API server automatically"
3. "Tests health endpoint via HTTP GET"
4. "Creates users via HTTP POST to /api/auth/register"
5. "Tests all 18 API endpoints"
6. "Runs single client demo"
7. "Runs multi-client demo with 5 concurrent users"
8. "Tests direct messaging functionality"
9. "All communication happens via REST API"

**SHIVA** (shows the final summary with all tests passing):
"All 10 tests passed! This proves the entire system works correctly via REST API."

---

## Tips for Recording

### Before You Start
1. **Clean your terminals**: Clear command history
2. **Increase font size**: Make text readable in video (16-18pt recommended)
3. **Close unnecessary applications**: Reduce distractions
4. **Test run once**: Ensure everything works smoothly
5. **Decide roles**: Ruchita (narrator) and Shiva (operator), or alternate

### During Recording
1. **Speak clearly**: Both team members should speak at a comfortable pace
2. **Pause between sections**: Give viewers time to process
3. **Point to logs**: Show the correlation between client calls and server logs
4. **Highlight REST API**: Emphasize HTTP requests/responses in logs
5. **Show JSON responses**: Demonstrate proper API responses
6. **Coordinate transitions**: Smooth handoffs between Ruchita and Shiva

### Division of Labor Suggestions

**Option A - Narrator/Operator**:
- Ruchita: Explains concepts, architecture, and what's happening
- Shiva: Runs commands, shows outputs, points to terminals

**Option B - Alternating**:
- Alternate who speaks and operates every 2-3 sections
- Keeps both members equally engaged

**Option C - Feature Split**:
- Ruchita: Handles user/auth/subreddit features (Parts 1-5)
- Shiva: Handles posts/comments/feed/DM features (Parts 6-12)

### What to Emphasize
✅ **REST API Communication**: All client-server communication is HTTP-based
✅ **Server Logs**: Show incoming requests being processed
✅ **No Direct Actor Messages**: Clients don't send Erlang messages directly
✅ **HTTP Methods**: GET, POST used appropriately
✅ **JSON Format**: Requests and responses use JSON
✅ **Concurrent Clients**: Server handles multiple clients simultaneously

### Common Pitfalls to Avoid
❌ Don't skip showing server logs - they prove REST API communication
❌ Don't rush through demos - let viewers see the correlation
❌ Don't forget to show both successful and interesting scenarios
❌ Don't skip the multi-client demo - it shows concurrency

---

## Video Structure Suggestion

```
00:00 - 00:30   Introduction & Project Overview (Ruchita + Shiva intro)
00:30 - 01:00   Starting Server & Health Check (Ruchita explains, Shiva operates)
01:00 - 02:00   User Registration, Subreddits, Posts (Both participate)
02:00 - 02:30   Comments, Voting, Feed
02:30 - 03:00   Direct Messaging Demo
03:00 - 04:00   Single Client Automated Demo
04:00 - 04:45   Multi-Client Concurrent Demo
04:45 - 05:00   Conclusion (Both thank viewers)
```

### Sample Opening Script

**RUCHITA**: "Hi everyone! I'm Ruchita..."

**SHIVA**: "...and I'm Shiva. We're presenting our Reddit Clone project."

**RUCHITA**: "For Part 1, we built a Reddit simulator using Gleam's actor model with direct message passing."

**SHIVA**: "For Part 2, which we're demonstrating today, we transformed it into a REST API server where all client-server communication happens via HTTP."

**RUCHITA**: "Let's dive in and show you how it works!"

---

## Key Points to Mention

### Architecture
- "The system uses Gleam's actor model internally"
- "But exposes everything via REST API"
- "Clients use HTTP, not Erlang messages"
- "Mist provides the HTTP server, Wisp handles routing"

### REST API Design
- "18 endpoints covering all functionality"
- "RESTful design with proper HTTP methods"
- "JSON for request/response bodies"
- "Stateless - server doesn't maintain client connections"

### Concurrency
- "Server handles concurrent requests using OTP actors"
- "Multiple clients can operate simultaneously"
- "No race conditions due to actor model"

---

## Troubleshooting

### If port 3000 is in use:
```powershell
netstat -ano | findstr :3000
Stop-Process -Id <PID> -Force
```

### If server doesn't start:
```powershell
gleam clean
gleam build
gleam run -m reddit_server
```

### If tests fail:
- Ensure no other server is running
- Check port 3000 availability
- Rebuild with `gleam clean && gleam build`

---

## Quick Reference - All REST API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/api/auth/register` | POST | Create user account |
| `/api/subreddits` | GET | List all subreddits |
| `/api/subreddits/create` | POST | Create subreddit |
| `/api/posts/create` | POST | Create post |
| `/api/posts/:id/vote` | POST | Vote on post |
| `/api/posts/:id/repost` | POST | Repost content |
| `/api/comments/create` | POST | Add comment |
| `/api/comments/:id/vote` | POST | Vote on comment |
| `/api/feed/:user_id` | GET | Get personalized feed |
| `/api/dm/send` | POST | Send direct message |
| `/api/dm/user/:id` | GET | Get user's DMs |
| `/api/dm/conversation/:id1/:id2` | GET | Get conversation |

---

Good luck with your demo! 🎬
