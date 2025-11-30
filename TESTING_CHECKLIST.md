# Final Testing Checklist - Reddit Clone Part 2

## Quick Start
```powershell
# Run the automated test script (recommended)
.\test_all.ps1
```

## Manual Testing Guide

### Step 1: Build Check ✅
```powershell
gleam build
# Expected: No errors, successful compilation
```

### Step 2: Start Server ✅
```powershell
# Terminal 1
gleam run -m reddit_server

# Wait for: "SERVER STARTED SUCCESSFULLY! ✓"
```

### Step 3: Test Health Endpoint ✅
```powershell
# Terminal 2
curl http://localhost:3000/health

# Expected: {"success":true,"data":{"status":"healthy",...}}
```

### Step 4: Test User Registration ✅
```powershell
curl -X POST http://localhost:3000/api/auth/register `
  -H "Content-Type: application/json" `
  -d '{\"username\":\"testuser\"}'

# Expected: {"success":true,"data":{"user_id":"user_X",...}}
```

### Step 5: Test Subreddit Creation ✅
```powershell
curl -X POST http://localhost:3000/api/subreddits/create `
  -H "Content-Type: application/json" `
  -d '{\"name\":\"test\",\"description\":\"Test subreddit\",\"creator_id\":\"user_1\"}'

# Expected: {"success":true,...}
```

### Step 6: Test List Subreddits ✅
```powershell
curl http://localhost:3000/api/subreddits

# Expected: JSON array of subreddits
```

### Step 7: Run Single Client Demo ✅
```powershell
gleam run -m reddit_client

# Expected: Alice's journey demo completes successfully
```

### Step 8: Run Multi-Client Demo ✅
```powershell
gleam run -m reddit_multi_client

# Expected: 5 clients complete successfully
```

### Step 9: Run DM Demo ✅
```powershell
gleam run -m reddit_dm_demo

# Expected: Direct messaging demo completes
```

### Step 10: Test All Endpoints ✅

#### Posts
```powershell
# Create post
curl -X POST http://localhost:3000/api/posts/create `
  -H "Content-Type: application/json" `
  -d '{\"subreddit_id\":\"sub_1\",\"author_id\":\"user_1\",\"title\":\"Test\",\"content\":\"Test content\"}'

# Vote on post
curl -X POST http://localhost:3000/api/posts/post_1/vote `
  -H "Content-Type: application/json" `
  -d '{\"user_id\":\"user_1\",\"vote_type\":\"upvote\"}'

# Repost
curl -X POST http://localhost:3000/api/posts/post_1/repost `
  -H "Content-Type: application/json" `
  -d '{\"user_id\":\"user_1\",\"target_subreddit_id\":\"sub_2\"}'
```

#### Comments
```powershell
# Create comment
curl -X POST http://localhost:3000/api/comments/create `
  -H "Content-Type: application/json" `
  -d '{\"post_id\":\"post_1\",\"author_id\":\"user_1\",\"content\":\"Test comment\",\"parent_id\":\"\"}'

# Vote on comment
curl -X POST http://localhost:3000/api/comments/comment_1/vote `
  -H "Content-Type: application/json" `
  -d '{\"user_id\":\"user_1\",\"vote_type\":\"upvote\"}'
```

#### Feed
```powershell
# Get user feed
curl http://localhost:3000/api/feed/user_1
```

#### Direct Messages
```powershell
# Send DM
curl -X POST http://localhost:3000/api/dm/send `
  -H "Content-Type: application/json" `
  -d '{\"from_user_id\":\"user_1\",\"to_user_id\":\"user_2\",\"content\":\"Hello!\"}'

# Get user DMs
curl http://localhost:3000/api/dm/user/user_1

# Get conversation
curl http://localhost:3000/api/dm/conversation/user_1/user_2
```

## Verification Checklist

### Core Functionality
- [ ] Server starts without errors
- [ ] Health endpoint responds
- [ ] User registration works
- [ ] Subreddit creation/join/leave works
- [ ] Post creation works
- [ ] Comment creation works (hierarchical)
- [ ] Voting works (posts & comments)
- [ ] Karma updates correctly
- [ ] Feed generation works
- [ ] Direct messaging works
- [ ] Repost functionality works

### Client Applications
- [ ] `reddit_client.gleam` runs successfully
- [ ] `reddit_multi_client.gleam` runs successfully (5 clients)
- [ ] `reddit_dm_demo.gleam` runs successfully
- [ ] All demos show REST API calls in server logs

### Documentation
- [ ] README.md is up to date
- [ ] PHASE4_SUMMARY.md documents client work
- [ ] PHASE5_SUMMARY.md documents DM feature
- [ ] PART2_STATUS.md shows completion status

### Code Quality
- [ ] No compilation errors
- [ ] No runtime crashes
- [ ] Server handles concurrent requests
- [ ] All features work as expected

## Performance Check
- [ ] Server handles 5+ concurrent clients
- [ ] No memory leaks during extended operation
- [ ] Response times are reasonable (< 100ms per request)

## Pre-Submission Final Check
- [ ] All tests pass
- [ ] Code is committed to git
- [ ] Documentation is complete
- [ ] Ready to record demo video

---

## Common Issues & Solutions

### Port 3000 Already in Use
```powershell
# Find and kill the process
netstat -ano | findstr :3000
taskkill /F /PID <PID>
```

### Server Won't Start
```powershell
# Check for compilation errors
gleam build

# Check port availability
netstat -ano | findstr :3000
```

### Client Can't Connect
```powershell
# Verify server is running
curl http://localhost:3000/health

# Check server logs for errors
```

---

## Success Criteria ✅

All tests should:
- ✅ Complete without errors
- ✅ Show "SUCCESS" or "✅" messages
- ✅ Display correct data in responses
- ✅ Server logs show HTTP requests
- ✅ No crashes or exceptions

If all checks pass, you're ready to record your demo video and submit!
