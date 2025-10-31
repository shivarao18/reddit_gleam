# 🚀 Part 2 Roadmap: Distributed Architecture

## Current State Assessment

### ✅ What We Have (Part I Complete)

**Architecture Foundation:**
- ✅ Separate engine actors (`reddit_engine_standalone.gleam`)
- ✅ Separate client process (`reddit_client_process.gleam`)
- ✅ All Reddit features working (posts, comments, votes, DMs, feeds)
- ✅ Simulator with Zipf distribution, reposts, metrics
- ✅ Clean actor-based architecture
- ✅ Message protocols defined

**Problem:**
```gleam
// From reddit_client_process.gleam lines 64-68:
io.println("⚠ TODO: Connect to remote engine actors")
io.println("  For Part I, starting local engine actors as placeholder")

// Lines 71-75: Client starts its OWN engine (not connecting to remote!)
let assert Ok(user_registry_started) = user_registry.start()
let assert Ok(subreddit_manager_started) = subreddit_manager.start()
...
```

**Current Behavior:**
- Engine process runs independently ✅
- Client process ALSO starts its own engine actors ❌
- They don't communicate across OS processes ❌
- Each client has isolated data (no sharing) ❌

---

## 🎯 Part 2 Goal

**Requirements** (from `requirements.md` lines 47-50):
```
- The client part and engine must run in SEPARATE PROCESSES
- Use MULTIPLE INDEPENDENT CLIENT PROCESSES that simulate thousands of clients
- Have a SINGLE ENGINE PROCESS
```

**What This Means:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Part 2 Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐                                       │
│  │  Engine Process  │  ← SINGLE shared engine               │
│  │  (Node: engine@) │                                       │
│  │                  │                                       │
│  │  • UserRegistry  │                                       │
│  │  • PostManager   │                                       │
│  │  • SubManager    │                                       │
│  │  • CommentMgr    │                                       │
│  │  • DM Manager    │                                       │
│  └────────┬─────────┘                                       │
│           │                                                 │
│           │ Distributed Erlang Communication                │
│           │ (or HTTP/WebSocket)                             │
│           │                                                 │
│   ┌───────┼────────┬────────────┬────────────┐             │
│   │       │        │            │            │             │
│   ▼       ▼        ▼            ▼            ▼             │
│ ┌──────┐┌──────┐┌──────┐    ┌──────┐    ┌──────┐          │
│ │Client││Client││Client│... │Client│... │Client│          │
│ │ #1   ││ #2   ││ #3   │    │ #50  │    │ #100 │          │
│ └──────┘└──────┘└──────┘    └──────┘    └──────┘          │
│   50      50      50          50          50               │
│  users   users   users       users       users            │
│                                                             │
│  All clients share the SAME engine data!                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Options

### Option 1: Erlang Distributed Mode (Recommended for Part 2) ⭐

**What It Is:**
- Multiple BEAM VMs connected via Erlang's native clustering
- Actors can send messages across nodes transparently
- Built-in, battle-tested, no extra dependencies

**How It Works:**
```bash
# Terminal 1: Start engine
erl -sname engine -setcookie reddit_secret -pa _build/dev/erlang/*/ebin \
    -eval "gleam@@main:run(reddit_engine_standalone)" -noshell

# Terminal 2: Start client 1
erl -sname client1 -setcookie reddit_secret -pa _build/dev/erlang/*/ebin \
    -eval "gleam@@main:run(reddit_client_process)" -noshell

# Terminal 3: Start client 2
erl -sname client2 -setcookie reddit_secret -pa _build/dev/erlang/*/ebin \
    -eval "gleam@@main:run(reddit_client_process)" -noshell
```

**Pros:**
- ✅ Native OTP support (no code changes to message passing)
- ✅ Transparent actor references across nodes
- ✅ Extremely fast (local network latency)
- ✅ Perfect for Part I→Part II transition

**Cons:**
- ⚠️ Requires Erlang distributed mode setup
- ⚠️ All nodes must use same Erlang/Gleam version
- ⚠️ Cookie-based security (not for production internet)

---

### Option 2: HTTP/REST API (For Part II with Web Clients)

**What It Is:**
- Engine exposes REST endpoints
- Clients make HTTP requests
- Standard web architecture

**How It Works:**
```gleam
// Engine: Serve HTTP on port 8080
import wisp

pub fn main() {
  // Start engine actors
  let engine = start_engine()
  
  // Start HTTP server
  wisp.serve(handle_request, on_port: 8080)
}

// Client: Make HTTP requests
let response = 
  http.post("http://localhost:8080/api/posts", 
    json.encode(post_data))
```

**Pros:**
- ✅ Standard web protocol
- ✅ Works across any network
- ✅ Easy to add web/mobile clients later
- ✅ Can use curl/Postman for testing

**Cons:**
- ❌ Major code refactor (change all actor calls to HTTP)
- ❌ Slower than native Erlang messaging
- ❌ Need to handle HTTP serialization/parsing
- ❌ More complex for Part II grading

---

### Option 3: WebSockets (Real-time Web)

**What It Is:**
- Persistent connection for real-time updates
- Similar to Erlang messages but over WebSocket
- Good for chat-like features (DMs, feeds)

**Pros:**
- ✅ Real-time bidirectional communication
- ✅ Works with web browsers
- ✅ Good for Part II + web UI

**Cons:**
- ❌ Similar refactor effort as HTTP
- ❌ Need WebSocket library
- ❌ More complex than Option 1

---

## 🛠️ Recommended Implementation: Option 1 (Erlang Distributed)

### Step-by-Step Plan

#### Step 1: Set Up Distributed Erlang Infrastructure

**Files to Create/Modify:**

1. **`src/reddit/distributed/node_config.gleam`** (NEW)
   - Node name configuration
   - Cookie management
   - Connection utilities

2. **`src/reddit/distributed/registry.gleam`** (NEW)
   - Global actor registration
   - Remote actor lookup
   - Connection management

#### Step 2: Modify Engine to Register Actors Globally

**`src/reddit_engine_standalone.gleam`**

```gleam
pub fn main() {
  // Start engine with distributed mode
  distributed.init_node("engine", "reddit_secret")
  
  // Start actors
  let assert Ok(user_registry) = user_registry.start()
  let assert Ok(subreddit_manager) = subreddit_manager.start()
  let assert Ok(post_manager) = post_manager.start()
  let assert Ok(comment_manager) = comment_manager.start()
  let assert Ok(dm_manager) = dm_manager.start()
  
  // Register actors globally so clients can find them
  distributed.register_global("user_registry", user_registry.data)
  distributed.register_global("subreddit_manager", subreddit_manager.data)
  distributed.register_global("post_manager", post_manager.data)
  distributed.register_global("comment_manager", comment_manager.data)
  distributed.register_global("dm_manager", dm_manager.data)
  
  io.println("✅ Engine actors registered globally")
  io.println("   Clients can now connect from other nodes")
  
  process.sleep_forever()
}
```

#### Step 3: Modify Client to Connect to Remote Engine

**`src/reddit_client_process.gleam`**

```gleam
pub fn run_client_process(config: ClientProcessConfig) {
  // Initialize as distributed node
  let node_name = "client" <> int.to_string(config.process_id)
  distributed.init_node(node_name, "reddit_secret")
  
  // Connect to engine node
  distributed.connect_to_node("engine@localhost")
  
  // Get references to REMOTE engine actors
  io.println("Connecting to remote engine actors...")
  
  let assert Ok(user_registry_subject) = 
    distributed.lookup_global("user_registry")
  let assert Ok(subreddit_manager_subject) = 
    distributed.lookup_global("subreddit_manager")
  let assert Ok(post_manager_subject) = 
    distributed.lookup_global("post_manager")
  let assert Ok(comment_manager_subject) = 
    distributed.lookup_global("comment_manager")
  let assert Ok(dm_manager_subject) = 
    distributed.lookup_global("dm_manager")
  
  io.println("✅ Connected to remote engine!")
  
  // Rest of client code unchanged (uses remote subjects)
  // Start user simulators...
  // Run activities...
}
```

#### Step 4: Create Distributed Utilities

**`src/reddit/distributed/erlang_dist.gleam`** (NEW)

```gleam
import gleam/dynamic
import gleam/result

// Initialize this node with a name and cookie
@external(erlang, "net_kernel", "start")
pub fn start_distributed(
  name: String,
  cookie: String,
) -> Result(Nil, String)

// Connect to another node
@external(erlang, "net_adm", "ping")
pub fn connect_to_node(node_name: String) -> Result(Nil, String)

// Register a process globally
@external(erlang, "global", "register_name")
pub fn register_global(
  name: String,
  pid: Subject(a),
) -> Result(Nil, String)

// Look up a globally registered process
@external(erlang, "global", "whereis_name")
pub fn lookup_global(name: String) -> Result(Subject(a), String)

// Get list of connected nodes
@external(erlang, "erlang", "nodes")
pub fn list_nodes() -> List(String)
```

#### Step 5: Create Launch Scripts

**`run_distributed.sh`** (UPDATED)

```bash
#!/bin/bash

echo "🚀 Starting Distributed Reddit Clone"
echo ""

# Build first
gleam build

# Start engine in background
echo "Starting engine node..."
erl -sname engine -setcookie reddit_secret \
    -pa _build/dev/erlang/*/ebin \
    -eval "gleam@@main:run(reddit_engine_standalone)" \
    -noshell > logs/engine.log 2>&1 &
ENGINE_PID=$!
echo "  Engine PID: $ENGINE_PID"
sleep 2

# Start multiple clients
for i in {1..3}; do
  echo "Starting client $i..."
  erl -sname client$i -setcookie reddit_secret \
      -pa _build/dev/erlang/*/ebin \
      -eval "gleam@@main:run(reddit_client_process)" \
      -noshell > logs/client_$i.log 2>&1 &
  echo "  Client $i PID: $!"
  sleep 1
done

echo ""
echo "✅ All processes started!"
echo "   View logs in ./logs/"
echo ""
echo "Press Enter to stop all processes..."
read

# Cleanup
kill $ENGINE_PID 2>/dev/null
pkill -P $$ 2>/dev/null
echo "✅ All processes stopped"
```

---

## 📊 Complexity Assessment

### Files to Create (New)
| File | Purpose | LOC | Difficulty |
|------|---------|-----|------------|
| `src/reddit/distributed/erlang_dist.gleam` | FFI bindings | ~50 | Medium |
| `src/reddit/distributed/node_config.gleam` | Config helpers | ~30 | Easy |
| `src/reddit/distributed/registry.gleam` | Actor registry | ~80 | Medium |

**Total New Code:** ~160 lines

### Files to Modify
| File | Changes | LOC | Difficulty |
|------|---------|-----|------------|
| `src/reddit_engine_standalone.gleam` | Add global registration | +20 | Easy |
| `src/reddit_client_process.gleam` | Replace local→remote actors | +30/-20 | Medium |
| `run_distributed_test.sh` | Update launch commands | +10 | Easy |

**Total Modified Code:** ~40 lines

### Estimated Effort
- **Coding Time:** 3-4 hours
- **Testing Time:** 1-2 hours
- **Documentation:** 30 minutes
- **Total:** ~5-6 hours

---

## 🧪 Testing Strategy

### Test 1: Single Client → Single Engine
```bash
# Terminal 1
erl -sname engine -setcookie reddit_secret -pa _build/dev/erlang/*/ebin \
    -eval "gleam@@main:run(reddit_engine_standalone)" -noshell

# Terminal 2
erl -sname client1 -setcookie reddit_secret -pa _build/dev/erlang/*/ebin \
    -eval "gleam@@main:run(reddit_client_process)" -noshell

# Expected: Client successfully creates posts, engine stores them
```

### Test 2: Multiple Clients → Single Engine
```bash
# Start engine (Terminal 1)
# Start client1 (Terminal 2)
# Start client2 (Terminal 3)

# Expected: Both clients see each other's posts in feeds
```

### Test 3: Data Sharing Verification
```bash
# Client 1: Create user "alice", post in r/gleam
# Client 2: Join r/gleam, see alice's post
# Client 2: Upvote alice's post
# Client 1: Check karma increased

# Expected: All actions visible across clients
```

### Test 4: Performance at Scale
```bash
# Start 1 engine + 10 clients (100 users each = 1000 total users)
# Run 1000 activity cycles
# Measure throughput (should be similar to Part I)

# Expected: ~5000-10000 ops/sec across all clients
```

---

## 🚧 Potential Issues & Solutions

### Issue 1: Erlang Nodes Can't Connect

**Symptom:**
```
❌ Failed to connect to engine@localhost
```

**Solutions:**
1. Check both nodes use same cookie (`-setcookie reddit_secret`)
2. Verify node names are unique (`engine`, `client1`, `client2`)
3. Check `epmd` is running: `epmd -names`
4. Use full node names if on different hosts: `engine@192.168.1.10`

### Issue 2: Global Registry Name Conflicts

**Symptom:**
```
❌ Name 'user_registry' already registered
```

**Solution:**
- Only engine registers actors (not clients)
- Clear global names on restart:
  ```gleam
  @external(erlang, "global", "unregister_name")
  pub fn unregister_global(name: String) -> Nil
  ```

### Issue 3: Message Serialization Failures

**Symptom:**
```
❌ Cannot send Subject(Message) across nodes
```

**Solution:**
- Gleam's OTP subjects should work transparently
- If issues, use Erlang PIDs directly:
  ```gleam
  @external(erlang, "erlang", "whereis")
  pub fn whereis(name: Atom) -> Pid
  ```

### Issue 4: Performance Degradation

**Symptom:**
- Throughput drops significantly vs Part I

**Causes & Solutions:**
1. **Network latency** → Run on same machine first (`localhost`)
2. **Too many clients** → Start with 3-5, scale gradually
3. **Message overhead** → Use batching for bulk operations

---

## 📈 Success Metrics

### Part 2 Completion Criteria

✅ **Functional Requirements:**
- [ ] Engine runs in separate OS process
- [ ] 3+ client processes run simultaneously
- [ ] All clients connect to SAME engine
- [ ] Data is shared across clients (posts, users, votes)
- [ ] All Reddit features work across processes
- [ ] Clients can start/stop independently

✅ **Performance Requirements:**
- [ ] Throughput ≥ 80% of Part I (acceptable overhead)
- [ ] Support 100+ simultaneous client processes
- [ ] Handle 1000+ simulated users
- [ ] Latency < 100ms for typical operations

✅ **Architecture Requirements:**
- [ ] Clean separation of concerns
- [ ] Minimal code changes from Part I
- [ ] Well-documented setup process
- [ ] Easy to run/test for graders

---

## 🎓 For Grading

### Demo Script

```bash
# 1. Build
./build.sh

# 2. Start distributed system
./run_distributed.sh

# 3. Observe output
# Terminal 1: Engine logs (all operations)
# Terminal 2-4: Client logs (their activities)
# Terminal 5: Combined metrics

# 4. Show data sharing
# Client 1 creates post → Client 2 sees it in feed
# Client 2 upvotes → Client 1's karma increases

# 5. Show scalability
# Add 10 more clients while running
# Performance remains stable
```

### Documentation to Include

1. **`DISTRIBUTED_SETUP.md`**
   - Installation instructions
   - How to run engine + clients
   - Troubleshooting guide

2. **`ARCHITECTURE_DISTRIBUTED.md`**
   - Update existing architecture doc
   - Add distributed communication diagrams
   - Explain node setup

3. **`PART_2_RESULTS.md`**
   - Performance comparison (Part I vs Part II)
   - Screenshots of multiple clients
   - Data sharing examples
   - Scalability tests

---

## 🏁 Next Steps

### Immediate Actions (For Part 2)

1. **Decision Point:** Choose Option 1 (Erlang Dist) or Option 2 (HTTP)?
   - **Recommendation:** Option 1 for Part II grading
   - **Reason:** Minimal code changes, better performance, true "distributed process" architecture

2. **If Choosing Option 1 (Erlang Distributed):**
   ```bash
   # I can implement this in ~2 hours:
   # 1. Create distributed utilities (30 min)
   # 2. Modify engine registration (15 min)
   # 3. Modify client connection (30 min)
   # 4. Test and debug (45 min)
   ```

3. **If Choosing Option 2 (HTTP REST):**
   ```bash
   # Bigger effort (~6-8 hours):
   # 1. Add HTTP server library (wisp/mist)
   # 2. Convert all actor calls to HTTP endpoints
   # 3. Handle JSON serialization
   # 4. Client HTTP client implementation
   # 5. Test and debug
   ```

---

## 💡 My Recommendation

**For Part II Submission:**

✅ **Go with Option 1 (Erlang Distributed Mode)**

**Why:**
1. ⚡ **Fastest to implement** - 2-3 hours vs 6-8 hours
2. 🎯 **Meets requirements** - "separate processes" ✓
3. 🚀 **Best performance** - native Erlang messaging
4. 📚 **Minimal code changes** - architecture stays clean
5. 🎓 **Easy to grade** - simple bash script to run

**Timeline:**
- Today: Implement distributed utilities (1-2 hours)
- Tomorrow: Test with 3-10 clients (1 hour)
- Tomorrow: Document + prepare demo (1 hour)
- **Total: 3-4 hours to fully working Part 2**

---

## 📞 Your Decision

**Question for you:**

1. Do you want to proceed with **Option 1 (Erlang Distributed)** for Part 2?
2. Or do you need **Option 2 (HTTP/REST)** because grading specifically requires HTTP?
3. What's your deadline for Part 2?

**If you want Option 1, I can start implementing RIGHT NOW and have it working within 2-3 hours!** 🚀

Let me know your preference!

