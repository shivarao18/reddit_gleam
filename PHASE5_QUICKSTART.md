# Phase 5: Quick Start Guide

## Running Phase 5 (Direct Messaging)

### Step 1: Start the Server
```powershell
# Option A: In a dedicated terminal
gleam run -m reddit_server

# Option B: In a new PowerShell window (Windows)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$(Get-Location)'; gleam run -m reddit_server"
```

Wait for the message: "SERVER STARTED SUCCESSFULLY! ✓"

### Step 2: Run the DM Demo
```powershell
# In another terminal
gleam run -m reddit_dm_demo
```

### Expected Output
```
✅ Alice registered: user_1
✅ Bob registered: user_2
✅ Charlie registered: user_3
✅ Message sent: dm_1
✅ Message sent: dm_2
📨 Alice has 15 messages
💬 Alice-Bob conversation has 3 messages
✅ All concurrent messages sent!
```

## Manual API Testing

### Send a DM
```powershell
curl -X POST http://localhost:3000/api/dm/send `
  -H "Content-Type: application/json" `
  -d '{\"from_user_id\":\"user_1\",\"to_user_id\":\"user_2\",\"content\":\"Hello!\"}'
```

### Get All DMs for a User
```powershell
curl http://localhost:3000/api/dm/user/user_1
```

### Get Conversation Between Two Users
```powershell
curl http://localhost:3000/api/dm/conversation/user_1/user_2
```

## All Phase Commands

```powershell
# Phase 4 - Single Client
gleam run -m reddit_client

# Phase 4 - Multi-Client Load Test
gleam run -m reddit_multi_client

# Phase 5 - Direct Messaging Demo
gleam run -m reddit_dm_demo
```

## Troubleshooting

### Port Already in Use
If you see "Eaddrinuse" error:
```powershell
# Find process using port 3000
netstat -ano | findstr :3000

# Kill the process (replace PID with actual process ID)
taskkill /F /PID <PID>
```

### Server Not Responding
```powershell
# Check if server is running
curl http://localhost:3000/health

# Should return: {"success":true,"data":{"status":"healthy",...}}
```

## Success Criteria ✅

- ✅ Server starts without errors
- ✅ DM demo completes successfully
- ✅ All messages are sent and received
- ✅ Conversation tracking works
- ✅ Concurrent messaging tested
