# Reddit Clone - Demo Script for Video Presentation

## Overview
This demo script will guide you through a 5-minute **ONLINE** demonstration showing:
1. How to run the code
2. REST API communication between clients and server
3. All major features working (user registration, subreddits, posts, comments, feed, direct messages)

**Team Members**: Ruchita and Shiva

**Online Recording Setup**:
- **Platform**: Zoom/Teams/Google Meet (recommended)
- **Shiva**: Shares screen, runs commands, shows outputs
- **Ruchita**: Co-host on camera/audio, explains concepts and architecture
- **Both**: Visible on camera for introduction and conclusion

---

## Setup (Before Recording)

### Pre-Demo Checklist

#### For Shiva (Screen Sharer):
1. **Close any processes using port 3000**
2. **Set up screen layout**:
   - Open 3 terminal windows arranged clearly:
     - **Terminal 1** (Left): Server logs - larger window
     - **Terminal 2** (Top-right): Client operations
     - **Terminal 3** (Bottom-right): Direct API calls (curl)
   - Or use a single terminal with tabs if easier to navigate
3. **Increase terminal font size**: 16-18pt minimum for visibility
4. **Clear terminal histories** for clean recording
5. **Ensure `gleam` is in your PATH**
6. **Test screen share** before recording to ensure all text is readable
7. **Close unnecessary apps**: Close Slack, email, notifications
8. **Set Do Not Disturb mode**: Prevent notification popups

#### For Ruchita (Co-host):
1. **Prepare talking points**: Review explanation sections
2. **Test microphone and camera**: Ensure good audio/video quality
3. **Have script open**: Keep demo script visible (on separate monitor or device)

#### For Both:
1. **Test meeting platform**: Join 5 minutes early
2. **Check internet connection**: Stable connection required
3. **Mute notifications**: Both team members
4. **Good lighting and quiet environment**

---

## Demo Script (5 Minutes)

### Part 1: Introduction & Setup (30 seconds)

**BOTH ON CAMERA**:

**RUCHITA**: "Hi everyone! I'm Ruchita..."

**SHIVA**: "...and I'm Shiva. We're presenting our Reddit Clone project for DOSP."

**RUCHITA**: "For Part 1, we built a Reddit simulator using Gleam's actor model. For Part 2, which we're demonstrating today, we transformed it into a REST API server where all client-server communication happens via HTTP."

**SHIVA**: "I'll be sharing my screen to show you the implementation. Ruchita will explain the concepts as we go."

**SHIVA SHARES SCREEN** (shows project structure in Terminal 2):
```powershell
# In Terminal 2
ls src/
```

**RUCHITA**: "You can see our project structure:
- `reddit_server.gleam` - REST API server
- `reddit_client.gleam` - HTTP client  
- `reddit/api/` - API handlers with 18 endpoints

We built this using Gleam, a type-safe functional language on the BEAM VM, with Mist for the HTTP server and Wisp for routing."

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

**SHIVA STOPS SCREEN SHARE - BOTH RETURN TO CAMERA**

**RUCHITA**: "To summarize, our demonstration showed:
1. Starting the REST API server with 6 OTP actors
2. All major features: registration, subreddits, posts, comments, voting, feeds, and direct messages
3. Clients communicating exclusively via REST API - HTTP requests and responses
4. Server logs proving all communication is HTTP-based
5. Concurrent client support with proper actor-based concurrency"

**SHIVA**: "We successfully transformed the actor-based simulator into a production-ready REST API server using Gleam, Mist, and Wisp. All 18 REST endpoints are fully functional."

**RUCHITA**: "Thanks for watching our demo!"

**SHIVA**: "Any questions?"

**BOTH**: "Thank you!" *[Wave to camera]*

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

## Tips for Online Recording

### Before You Start
1. **Test meeting platform**: Join 5-10 minutes early, test screen share quality
2. **Clean your terminals**: Clear command history and close unused tabs
3. **Increase font size**: 16-18pt minimum - verify it's readable when screen sharing
4. **Close unnecessary applications**: Close Slack, email, browsers with personal tabs
5. **Mute notifications**: Set "Do Not Disturb" mode on both computers
6. **Test run once**: Do a practice recording to catch any issues
7. **Check backgrounds**: Both camera backgrounds should be professional/neutral
8. **Stable internet**: Use wired connection if possible, close bandwidth-heavy apps

### During Online Recording
1. **Start with both on camera**: Introduce yourselves with video on
2. **Announce screen share**: "Shiva is now sharing his screen..."
3. **Speak clearly**: Account for potential audio lag or compression
4. **Pause between sections**: Online viewers need slightly more processing time
5. **Use mouse/cursor to point**: Since you can't physically point, use cursor to highlight
6. **Zoom in if needed**: Ctrl/Cmd + Plus to increase terminal text if unclear
7. **Confirm visibility**: Occasionally ask "Can everyone see the server logs here?"
8. **Coordinate verbally**: Use names for transitions - "Ruchita, what's happening here?"
9. **Watch pacing**: Online demos feel faster, slow down slightly
10. **End with both on camera**: Return to camera view for conclusion

### Division of Labor for Online Demo

**Recommended: Narrator/Operator (Best for Online)**:
- **Shiva**: Shares screen, runs all commands, points with cursor to logs/outputs
- **Ruchita**: Stays on camera (picture-in-picture if platform allows), explains concepts
- **Why**: Keeps screen share stable, avoids switching hosts, clearer for viewers

**Alternative - Single Screen Share with Both**:
- Shiva shares screen throughout
- Both explain different sections (alternate by topic)
- Both visible in gallery view or side-by-side camera tiles

**Not Recommended for Online**:
- ❌ Switching screen share between members (causes disruption)
- ❌ Both trying to control same screen (confusing)

### Screen Sharing Best Practices

1. **Share entire screen** (not just terminal window) - prevents awkward switching
2. **Hide taskbar/dock** if possible for cleaner view
3. **Use presenter view** if platform offers it
4. **Highlight cursor**: Enable large cursor or use spotlight feature
5. **Terminal arrangement**: Keep all 3 terminals visible when possible
6. **Smooth transitions**: Move mouse slowly, give viewers time to read

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

### Sample Opening Script (Both on Camera)

**RUCHITA**: "Hi everyone! I'm Ruchita..."

**SHIVA**: "...and I'm Shiva. We're presenting our Reddit Clone project for DOSP."

**RUCHITA**: "For Part 1, we built a Reddit simulator using Gleam's actor model with direct message passing between actors."

**SHIVA**: "For Part 2, which we're demonstrating today, we transformed it into a production-ready REST API server where all client-server communication happens via HTTP."

**RUCHITA**: "I'll be explaining the architecture and features, while Shiva shares his screen and runs the demo."

**SHIVA**: "Let me share my screen now... Can everyone see my terminal windows?"

**RUCHITA**: "Great! Let's dive in and show you how it works!"

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

### Online Recording Specific Issues:

**Screen share text too small**:
- Increase terminal font size (Ctrl/Cmd + Plus)
- Zoom in on entire screen if needed
- Ask viewers "Can everyone read the text?"

**Audio issues**:
- Have backup: Both should have headphones with mic
- Test audio before starting
- Speak louder and clearer than normal

**Internet lag**:
- Close all other applications
- Use wired connection if possible
- Pause slightly longer between sections

**Screen share freezes**:
- Have backup plan: Stop share, restart, resume from checkpoint
- Save terminal command history to quickly re-run if needed

**Recording platform crashes**:
- Have backup recording software running (OBS Studio)
- Join from two devices as backup

**Something goes wrong during demo**:
- Stay calm, explain what happened
- Use the automated test script as backup: `powershell -ExecutionPolicy Bypass -File .\test_all.ps1`
- Have a pre-recorded backup video ready (optional)

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

## Platform-Specific Tips

### Zoom
- ✅ Enable "Share computer sound" if you want system sounds
- ✅ Use "Optimize for video clip" for smoother screen share
- ✅ Enable "Side-by-side mode" so both faces + screen are visible
- ✅ Record to cloud for backup

### Microsoft Teams
- ✅ Use "Share desktop" rather than specific window
- ✅ Turn on "Include computer sound"
- ✅ Enable recording at start
- ✅ Use "Together mode" or gallery view for both faces

### Google Meet
- ✅ Choose "Your entire screen" when sharing
- ✅ Pin the shared screen for viewers
- ✅ Record to Google Drive
- ✅ Both should join from computers (not phones) for best quality

### General for All Platforms
- 📹 **Start recording immediately** - you can edit later
- 🎤 **Test audio**: Do a 30-second test recording first
- 📺 **1080p minimum**: Ensure platform is set to HD quality
- ⏱️ **Time check**: Keep demo to 5 minutes, leave buffer for intro/outro
- 💾 **Download immediately**: Save recording right after finishing

---

## Quick Checklist Before Going Live

**5 Minutes Before**:
- [ ] Both joined the meeting
- [ ] Audio/video tested
- [ ] Screen share tested
- [ ] Terminal font size increased
- [ ] Port 3000 available
- [ ] All terminals cleared and ready
- [ ] Notifications muted
- [ ] Recording started

**During Demo**:
- [ ] Introduce both team members
- [ ] Announce screen share start
- [ ] Speak clearly and pace appropriately
- [ ] Point with cursor to important elements
- [ ] Return to camera for conclusion

**After Demo**:
- [ ] Stop recording
- [ ] Download/save recording immediately
- [ ] Review recording quality
- [ ] Re-record if needed

---

Good luck with your online demo! 🎬
