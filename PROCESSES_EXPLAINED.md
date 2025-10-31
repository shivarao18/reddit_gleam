# 🔍 OS Processes vs Erlang Processes - Complete Explanation

## 🎯 The Confusion

**Your Friend Says:**
> "Simply creating a simulator as an actor is enough, and BEAM creates a process"

**The Truth:**
- ✅ **Technically correct** - BEAM does create a "process" for each actor
- ❌ **BUT** - These are **Erlang processes** (lightweight actors), NOT **OS processes**
- ❌ **The requirement asks for separate OS processes**, not just Erlang processes

---

## 📚 Understanding the Two Types of "Processes"

### Type 1: OS Process (Operating System Process)

**What is it?**
- A **heavyweight** process managed by your operating system (Linux/Windows/Mac)
- Has its own memory space (completely isolated)
- Has its own PID (Process ID) visible in `ps`, `top`, Task Manager
- Scheduled by the OS kernel
- Communication requires IPC (Inter-Process Communication): sockets, pipes, distributed Erlang, etc.

**How to see them:**
```bash
$ ps aux | grep gleam
shiva    12345  ... gleam run -m reddit_engine_standalone    ← OS Process 1
shiva    12346  ... gleam run -m reddit_client_process       ← OS Process 2
shiva    12347  ... gleam run -m reddit_client_process       ← OS Process 3
```

**Characteristics:**
- ✅ Truly isolated (one crash doesn't affect others)
- ✅ Can run on different machines
- ✅ Visible to OS tools
- ❌ Heavyweight (MB of memory each)
- ❌ Slow to create (~milliseconds)

---

### Type 2: Erlang Process (BEAM Lightweight Process / Actor)

**What is it?**
- A **lightweight** "process" managed by the BEAM VM
- Shares memory space with other Erlang processes (same OS process)
- Has its own Erlang PID (invisible to OS, only visible inside BEAM)
- Scheduled by the BEAM VM scheduler
- Communication via message passing (instant, in-memory)

**How to see them:**
```erlang
% Inside Erlang shell
> processes().  % Shows thousands of Erlang processes
[<0.0.0>, <0.1.0>, <0.2.0>, ..., <0.12345.0>]  ← All in SAME OS process!
```

**Characteristics:**
- ✅ Super lightweight (KB of memory each)
- ✅ Fast to create (~microseconds)
- ✅ Millions can run in one OS process
- ❌ Share same OS process (same memory space)
- ❌ Cannot run on different machines without distributed Erlang
- ❌ All die if OS process crashes

---

## 🔬 Visual Comparison

### Your Friend's Approach (Actors Only) ❌

```
┌─────────────────────────────────────────────────────────┐
│  SINGLE OS PROCESS (gleam run)                          │
│  PID: 12345                                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Engine Actor │  │ Client Actor │  │ Client Actor │  │
│  │ (Erlang PID) │  │ (Erlang PID) │  │ (Erlang PID) │  │
│  │  <0.100.0>   │  │  <0.200.0>   │  │  <0.300.0>   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         ▲                 ▲                 ▲           │
│         └─────────────────┴─────────────────┘           │
│           In-memory message passing (same RAM)          │
│                                                         │
└─────────────────────────────────────────────────────────┘

Result: Only ONE OS process visible to Linux! ❌
        All "processes" are just Erlang actors in same memory.
```

**How to verify:**
```bash
$ ps aux | grep gleam
shiva    12345  ... gleam run                              ← Only ONE OS process!

$ kill 12345                                               ← Kills EVERYTHING!
```

---

### Our Distributed Approach (Multiple OS Processes) ✅

```
┌───────────────────────────┐
│  OS PROCESS 1             │  ← Separate OS process
│  PID: 12345               │
│  (Terminal 1)             │
├───────────────────────────┤
│  Engine Actors:           │
│  • user_registry          │
│  • post_manager           │
│  • subreddit_manager      │
│                           │
│  BEAM VM (engine@host)    │
└──────────┬────────────────┘
           │
           │ Distributed Erlang
           │ (TCP sockets, port 4369+)
           │
    ┌──────┴───────┬─────────────────┐
    │              │                 │
┌───▼────────┐  ┌──▼──────────┐  ┌──▼──────────┐
│ OS PROC 2  │  │ OS PROC 3   │  │ OS PROC 4   │  ← Separate OS processes
│ PID: 12346 │  │ PID: 12347  │  │ PID: 12348  │
│ (Terminal 2)│  │ (Terminal 3)│  │ (Terminal 4)│
├────────────┤  ├─────────────┤  ├─────────────┤
│ Client     │  │ Client      │  │ Client      │
│ Actors     │  │ Actors      │  │ Actors      │
│            │  │             │  │             │
│ BEAM VM    │  │ BEAM VM     │  │ BEAM VM     │
│ (client1@) │  │ (client2@)  │  │ (client3@)  │
└────────────┘  └─────────────┘  └─────────────┘

Result: FOUR OS processes visible to Linux! ✅
        Each can be killed independently.
```

**How to verify:**
```bash
$ ps aux | grep gleam
shiva    12345  ... gleam run -m reddit_engine_standalone    ← OS Process 1
shiva    12346  ... gleam run -m reddit_client_process       ← OS Process 2
shiva    12347  ... gleam run -m reddit_client_process       ← OS Process 3

$ kill 12346                                                  ← Kills ONLY client 1!
                                                              ← Engine + client 2 still running!
```

---

## 🧪 Proof: How We Ensure Separate OS Processes

### 1. **Separate Entry Points**

**Engine Entry Point:**
```bash
# Terminal 1
$ gleam run -m reddit_engine_standalone    ← Starts NEW OS process
```

**Client Entry Point:**
```bash
# Terminal 2
$ gleam run -m reddit_client_process       ← Starts ANOTHER OS process
```

Each `gleam run` command starts a **NEW OS process**. This is guaranteed by the OS.

---

### 2. **Distributed Node Initialization**

**In Engine (`reddit_engine_standalone.gleam`):**
```gleam
pub fn main() {
  // Initialize THIS OS process as a distributed Erlang node named "engine"
  let assert Ok(node_name) = node_manager.init_node(node_manager.EngineNode)
  // Result: This OS process becomes "engine@hostname"
  
  // Start actors WITHIN this OS process
  let assert Ok(user_registry) = user_registry.start()
  
  // Register actors globally (so OTHER OS processes can find them)
  node_manager.register_global("user_registry", user_registry.data)
  
  process.sleep_forever()  // Keep THIS OS process alive
}
```

**In Client (`reddit_client_process.gleam`):**
```gleam
pub fn main() {
  // Initialize THIS OS process as a distributed Erlang node named "client1"
  let assert Ok(node_name) = node_manager.init_node(node_manager.ClientNode(1))
  // Result: This OS process becomes "client1@hostname"
  
  // Connect to the ENGINE'S OS process
  node_manager.connect_to_engine()  // Establishes TCP connection to engine@hostname
  
  // Look up actors in REMOTE OS process
  let assert Ok(user_registry) = node_manager.lookup_global("user_registry")
  // This returns a reference to an actor in DIFFERENT OS process!
  
  // Use remote actors (messages sent via TCP, not in-memory!)
  actor.call(user_registry, protocol.GetUser(id, _))
}
```

**Key Difference:**
- **Actors only:** All actors in same BEAM VM → Same OS process
- **Our approach:** Each BEAM VM in different OS process → Different OS processes

---

### 3. **Network Communication (Distributed Erlang)**

**What happens when client calls engine actor:**

```
┌────────────────────────────────────────────────────────┐
│ Client OS Process (client1@hostname, PID 12346)        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  actor.call(user_registry, GetUser(id, _))            │
│         │                                              │
│         ▼                                              │
│  BEAM detects: user_registry is REMOTE!               │
│         │                                              │
│         ▼                                              │
│  Serialize message to binary                           │
│         │                                              │
│         ▼                                              │
│  Send via TCP socket to engine@hostname:4369           │
│                                                        │
└──────────────────┬─────────────────────────────────────┘
                   │
                   │ TCP/IP Network Stack
                   │ (even on same machine, uses loopback)
                   │
┌──────────────────▼─────────────────────────────────────┐
│ Engine OS Process (engine@hostname, PID 12345)         │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Receive TCP packet from client1@hostname              │
│         │                                              │
│         ▼                                              │
│  Deserialize message                                   │
│         │                                              │
│         ▼                                              │
│  Deliver to user_registry actor (local to engine)     │
│         │                                              │
│         ▼                                              │
│  user_registry processes message                       │
│         │                                              │
│         ▼                                              │
│  Send reply back via TCP to client1@hostname           │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Key Point:** Messages travel via **TCP sockets**, not in-memory! This proves separate OS processes.

---

## 🔍 How to Verify (Practical Tests)

### Test 1: Check OS Process IDs

```bash
# Start engine
$ gleam run -m reddit_engine_standalone &
[1] 12345

# Start client 1
$ gleam run -m reddit_client_process &
[2] 12346

# Start client 2
$ gleam run -m reddit_client_process &
[3] 12347

# List OS processes
$ ps aux | grep gleam
shiva    12345  1.2  2.3  ... gleam run -m reddit_engine_standalone
shiva    12346  1.1  2.1  ... gleam run -m reddit_client_process
shiva    12347  1.1  2.1  ... gleam run -m reddit_client_process

# THREE DIFFERENT OS PROCESSES! ✅
```

---

### Test 2: Kill One Process, Others Survive

```bash
# Kill client 1 only
$ kill 12346

# Check what's still running
$ ps aux | grep gleam
shiva    12345  1.2  2.3  ... reddit_engine_standalone    ← Still running ✅
shiva    12347  1.1  2.1  ... reddit_client_process       ← Still running ✅

# If they were just actors in same process, killing one would kill all! ❌
```

---

### Test 3: Check Network Connections

```bash
# While engine and clients are running
$ netstat -an | grep 4369
tcp    0    0 127.0.0.1:4369    0.0.0.0:*    LISTEN     ← EPMD (Erlang Port Mapper)
tcp    0    0 127.0.0.1:xxxxx   127.0.0.1:yyyy ESTABLISHED ← Client 1 ↔ Engine
tcp    0    0 127.0.0.1:xxxxx   127.0.0.1:yyyy ESTABLISHED ← Client 2 ↔ Engine

# Network sockets prove SEPARATE OS processes communicating via TCP! ✅
```

---

### Test 4: Memory Isolation

```bash
# Check memory usage of each process
$ ps aux | grep gleam
shiva    12345  ... 234MB  ... reddit_engine_standalone    ← Separate memory
shiva    12346  ... 123MB  ... reddit_client_process       ← Separate memory
shiva    12347  ... 123MB  ... reddit_client_process       ← Separate memory

# Total: ~480MB across 3 processes
# If same process: Would be ~480MB for ONE process

# Each process has its own memory space! ✅
```

---

### Test 5: Run on Different Terminals

```bash
# Terminal 1
$ cd /home/shiva/reddit
$ gleam run -m reddit_engine_standalone
# [Engine runs here, blocks terminal]

# Terminal 2 (DIFFERENT shell session)
$ cd /home/shiva/reddit
$ gleam run -m reddit_client_process
# [Client 1 runs here, blocks terminal]

# Terminal 3 (ANOTHER shell session)
$ gleam run -m reddit_client_process
# [Client 2 runs here, blocks terminal]

# THREE DIFFERENT TERMINALS = THREE DIFFERENT OS PROCESSES! ✅
```

---

## 📖 Code Analysis: What Makes It Work

### Engine: `reddit_engine_standalone.gleam`

```gleam
import reddit/distributed/node_manager  // ← Key: Distributed support

pub fn main() {
  // 1. Initialize THIS OS process as distributed node "engine"
  let assert Ok(node_name) = node_manager.init_node(node_manager.EngineNode)
  //    Behind the scenes: Calls `net_kernel:start(['engine', 'shortnames'])`
  //    Result: THIS OS process becomes "engine@hostname"
  
  // 2. Start actors (still local to THIS OS process)
  let assert Ok(user_registry) = user_registry.start()
  
  // 3. Register actors GLOBALLY (visible across OS processes)
  let assert Ok(_) = node_manager.register_global("user_registry", user_registry.data)
  //    Behind the scenes: Calls `global:register_name('user_registry', Pid)`
  //    Result: Other OS processes can find this actor by name
  
  process.sleep_forever()  // Keep THIS OS process alive
}
```

**What's different from actor-only approach?**
- ❌ **Actor-only:** Just `user_registry.start()` → Actor in same OS process
- ✅ **Our approach:** `init_node()` + `register_global()` → Actor accessible from other OS processes

---

### Client: `reddit_client_process.gleam`

```gleam
import reddit/distributed/node_manager  // ← Key: Distributed support

pub fn main() {
  // 1. Initialize THIS OS process as distributed node "client1"
  let assert Ok(node_name) = node_manager.init_node(node_manager.ClientNode(1))
  //    Behind the scenes: Calls `net_kernel:start(['client1', 'shortnames'])`
  //    Result: THIS OS process becomes "client1@hostname"
  
  // 2. Check if engine OS process is reachable
  case node_manager.is_engine_alive() {
    False -> panic as "Engine not available"  // ← Proves separate processes!
    True -> { /* continue */ }
  }
  //    Behind the scenes: Calls `net_adm:ping('engine@hostname')`
  //    Result: TCP connection attempt to DIFFERENT OS process
  
  // 3. Connect to engine OS process
  let assert Ok(_) = node_manager.connect_to_engine()
  //    Behind the scenes: Establishes TCP connection to engine
  
  // 4. Look up actors in REMOTE OS process
  let assert Ok(user_registry) = node_manager.lookup_global("user_registry")
  //    Behind the scenes: Calls `global:whereis_name('user_registry')`
  //    Result: Returns reference to actor in DIFFERENT OS process
  
  // 5. Use remote actor (messages via TCP!)
  actor.call(user_registry, protocol.GetUser(id, _))
  //    Behind the scenes: Message serialized and sent via TCP to engine
}
```

**What's different from actor-only approach?**
- ❌ **Actor-only:** `user_registry.start()` → Creates actor in SAME OS process
- ✅ **Our approach:** `lookup_global()` → Gets reference to actor in DIFFERENT OS process

---

## 🛠️ The Distributed Infrastructure

### File: `src/reddit/distributed/erlang_ffi.gleam`

```gleam
// Initialize distributed mode (makes THIS OS process a distributed node)
@external(erlang, "net_kernel", "start")
pub fn start_node_ffi(name_list: List(Atom)) -> Result(Pid, Atom)
//          ▲            ▲          ▲
//          │            │          └─ Erlang function
//          │            └─ Erlang module (built-in)
//          └─ FFI call (calls Erlang from Gleam)

// Connect to ANOTHER OS process
@external(erlang, "net_adm", "ping")
pub fn ping_node_ffi(node: Atom) -> Atom
// Attempts TCP connection to another distributed node

// Register actor for cross-process access
@external(erlang, "global", "register_name")
pub fn register_global_ffi(name: Atom, pid: Pid) -> Atom
// Makes actor visible to ALL connected nodes (across OS processes)

// Find actor in ANOTHER OS process
@external(erlang, "global", "whereis_name")
pub fn whereis_global_ffi(name: Atom) -> Dynamic
// Returns reference to actor in potentially DIFFERENT OS process
```

**These functions are what make cross-OS-process communication possible!**

---

## 🎯 Addressing The Requirement

### From `requirements.md`:

> **"The client part and engine must run in separate processes"**

**What does "separate processes" mean here?**

In distributed systems literature, "separate processes" **always** means:
1. ✅ Separate OS processes (different PIDs)
2. ✅ Can run on different machines
3. ✅ Communicate via network (even if localhost)
4. ✅ Can crash independently
5. ✅ Visible as separate processes to OS

It does **NOT** mean:
- ❌ Just separate Erlang processes (actors) in same BEAM VM
- ❌ Just separate actors in same OS process

**Why?**
- The requirement is preparing you for Part 2 (REST API)
- REST API will DEFINITELY run in separate OS processes
- Understanding distributed architecture is the learning goal

---

## 📊 Comparison Table

| Aspect | Actor-Only (Same OS Process) | Our Distributed (Multiple OS Processes) |
|--------|------------------------------|------------------------------------------|
| **OS Processes** | 1 | 3+ |
| **OS PIDs** | 1 (e.g., 12345) | 3+ (12345, 12346, 12347) |
| **BEAM VMs** | 1 | 3+ |
| **Memory Space** | Shared | Isolated |
| **Communication** | In-memory | TCP/IP (distributed Erlang) |
| **Can run on different machines** | ❌ No | ✅ Yes |
| **Independent crashes** | ❌ No (all die together) | ✅ Yes |
| **Visible in `ps`/`top`** | ❌ 1 process | ✅ Multiple processes |
| **Network sockets** | ❌ None | ✅ Yes (TCP) |
| **Meets requirement** | ❌ No | ✅ Yes |

---

## 🔬 Deep Dive: What Happens at Runtime

### Scenario: Client Calls `GetUser(user_id)`

#### With Actor-Only Approach (Same OS Process):

```
1. Client actor sends message
   └─> Erlang in-memory message queue
       └─> Engine actor receives message (microseconds)
           └─> Engine actor processes
               └─> Reply sent back (in-memory)
                   └─> Client receives reply

Total time: ~10 microseconds
Memory copies: 0 (just pointers)
Network: None
```

**All happens inside ONE OS process (PID 12345)**

---

#### With Our Distributed Approach (Multiple OS Processes):

```
1. Client actor sends message (in client1@hostname, OS PID 12346)
   └─> BEAM detects: user_registry is in engine@hostname
       └─> Serialize message to binary format
           └─> Send via TCP socket to 127.0.0.1:XXXX
               └─> Linux kernel: packet from PID 12346 to PID 12345
                   └─> Engine BEAM receives TCP packet (OS PID 12345)
                       └─> Deserialize message
                           └─> Deliver to user_registry actor
                               └─> Actor processes
                                   └─> Serialize reply
                                       └─> Send via TCP back to client1@hostname
                                           └─> Client BEAM receives TCP packet
                                               └─> Deserialize reply
                                                   └─> Client actor receives reply

Total time: ~100-1000 microseconds (100x slower)
Memory copies: 2+ (serialization)
Network: TCP/IP stack (even localhost)
```

**Happens across TWO OS processes (PID 12345 ↔ PID 12346)**

---

## 💡 Why Your Friend's Approach Doesn't Meet Requirements

### Your Friend's Code (Hypothetical):

```gleam
pub fn main() {
  // Start engine actors
  let assert Ok(user_registry) = user_registry.start()
  let assert Ok(post_manager) = post_manager.start()
  
  // Start client actors (in SAME OS process!)
  let assert Ok(client1) = client_simulator.start(user_registry, post_manager)
  let assert Ok(client2) = client_simulator.start(user_registry, post_manager)
  
  // Run simulation
  process.sleep_forever()
}
```

**Result:**
```bash
$ ps aux | grep gleam
shiva    12345  ... gleam run    ← Only ONE OS process!

$ kill 12345                     ← Kills EVERYTHING (engine + all clients)
```

**Problems:**
- ❌ Only ONE OS process
- ❌ All actors share memory
- ❌ Cannot run on different machines
- ❌ All crash together
- ❌ Doesn't demonstrate distributed architecture
- ❌ Doesn't prepare for Part 2 (REST API)

---

## ✅ Why Our Approach Meets Requirements

### Our Code:

**Engine (Terminal 1):**
```bash
$ gleam run -m reddit_engine_standalone
# Starts OS process 12345
```

**Client 1 (Terminal 2):**
```bash
$ gleam run -m reddit_client_process
# Starts OS process 12346
```

**Client 2 (Terminal 3):**
```bash
$ gleam run -m reddit_client_process
# Starts OS process 12347
```

**Result:**
```bash
$ ps aux | grep gleam
shiva    12345  ... reddit_engine_standalone    ← Engine OS process
shiva    12346  ... reddit_client_process       ← Client 1 OS process
shiva    12347  ... reddit_client_process       ← Client 2 OS process

$ kill 12346                                    ← Kills ONLY client 1
$ ps aux | grep gleam
shiva    12345  ... reddit_engine_standalone    ← Still alive! ✅
shiva    12347  ... reddit_client_process       ← Still alive! ✅
```

**Benefits:**
- ✅ THREE OS processes
- ✅ Isolated memory spaces
- ✅ Can run on different machines
- ✅ Independent crashes
- ✅ Demonstrates distributed architecture
- ✅ Prepares for Part 2 (REST API)

---

## 🎓 Summary: Clearing the Confusion

### ❌ Your Friend's Understanding (Incorrect)

**"Creating actors is enough because BEAM creates processes"**

- Technically correct: BEAM creates **Erlang processes** (actors)
- **BUT** these are lightweight actors **within one OS process**
- Does **NOT** meet the requirement for "separate processes"

### ✅ Correct Understanding

**"Separate processes means separate OS processes with distributed communication"**

- Each `gleam run` creates a **new OS process**
- We use **distributed Erlang** to connect OS processes
- Actors in different OS processes communicate via **TCP/IP**
- This is what the requirement asks for

---

## 📚 Glossary

| Term | Definition | Example |
|------|------------|---------|
| **OS Process** | Heavyweight process managed by operating system | `gleam run` (visible in `ps`) |
| **Erlang Process** | Lightweight "process"/actor managed by BEAM VM | `actor.start()` (invisible to OS) |
| **BEAM VM** | Erlang virtual machine (one per OS process) | Each `gleam run` starts one BEAM VM |
| **Distributed Erlang** | Protocol for BEAM VMs to communicate across OS processes/machines | `net_kernel:start()`, `global:register_name()` |
| **Actor** | Same as Erlang process (lightweight) | `process.Subject`, `actor.start()` |
| **Node** | A BEAM VM with a name in distributed mode | `engine@hostname`, `client1@hostname` |

---

## 🎬 How to Prove to Your Friend

### Test Together:

```bash
# 1. Run your friend's actor-only approach
$ gleam run -m reddit_simulator    # (assuming this starts all actors)

# 2. In another terminal, check OS processes
$ ps aux | grep gleam
shiva    12345  ... gleam run       ← ONLY ONE OS process!

# 3. Kill it
$ kill 12345                         ← Everything dies!

# ================================

# 4. Run our distributed approach
# Terminal 1:
$ gleam run -m reddit_engine_standalone

# Terminal 2:
$ gleam run -m reddit_client_process

# 5. Check OS processes
$ ps aux | grep gleam
shiva    12345  ... reddit_engine_standalone    ← First OS process
shiva    12346  ... reddit_client_process       ← Second OS process

# 6. Kill only client
$ kill 12346

# 7. Check again
$ ps aux | grep gleam
shiva    12345  ... reddit_engine_standalone    ← STILL RUNNING! ✅

# This proves separate OS processes!
```

---

## 📖 Further Reading

- [Erlang Distributed Programming](https://www.erlang.org/doc/reference_manual/distributed.html)
- [Process vs OS Process in Erlang](https://learnyousomeerlang.com/the-hitchhikers-guide-to-concurrency)
- [BEAM Scheduler and Processes](https://www.erlang.org/doc/efficiency_guide/processes.html)

---

## 🎯 Final Answer

**Question:** "Is creating actors as separate processes enough?"

**Answer:**
- ✅ Actors ARE separate **Erlang processes** (lightweight)
- ❌ Actors are NOT separate **OS processes** (heavyweight)
- ✅ Requirement asks for separate **OS processes**
- ✅ We achieve this using **distributed Erlang** + **multiple `gleam run` commands**
- ✅ Proof: Multiple PIDs visible in `ps`, network sockets visible in `netstat`, independent crashes

**Your friend is technically correct about BEAM creating "processes", but confuses the type of process. The requirement clearly means OS processes, not Erlang processes.**

---

**Status:** 
- Actors-only approach: ❌ Does not meet requirements
- Our distributed approach: ✅ Meets requirements perfectly

