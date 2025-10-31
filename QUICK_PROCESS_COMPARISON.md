# Quick Reference: OS Process vs Erlang Process

## Visual Comparison

### ❌ Erlang Processes Only (What Your Friend Thinks)

```
Terminal 1: gleam run
├─ OS Process (PID 12345)
│  ├─ BEAM VM
│  │  ├─ Erlang Process: Engine Actor #1
│  │  ├─ Erlang Process: Engine Actor #2
│  │  ├─ Erlang Process: Client Actor #1
│  │  ├─ Erlang Process: Client Actor #2
│  │  └─ Erlang Process: Client Actor #3
│  │     └─ All in SAME memory, in-process messages
│  └─ Total: 1 OS process, 5 Erlang processes
└─ Result: ONE entry in `ps aux`
```

**Problem:** All actors share same OS process = Not separate processes!

---

### ✅ Multiple OS Processes (Our Implementation)

```
Terminal 1: gleam run -m reddit_engine_standalone
├─ OS Process (PID 12345) "engine@hostname"
│  └─ BEAM VM
│     ├─ Erlang Process: user_registry
│     ├─ Erlang Process: post_manager
│     └─ Erlang Process: subreddit_manager
│
Terminal 2: gleam run -m reddit_client_process
├─ OS Process (PID 12346) "client1@hostname"
│  └─ BEAM VM                    ▲
│     └─ Erlang Process: Client  │ TCP/IP
│        └─────────────────────────┘
│
Terminal 3: gleam run -m reddit_client_process
├─ OS Process (PID 12347) "client2@hostname"
│  └─ BEAM VM                    ▲
│     └─ Erlang Process: Client  │ TCP/IP
│        └─────────────────────────┘
│
└─ Result: THREE entries in `ps aux`
```

**Success:** Each `gleam run` = New OS process = Separate processes!

---

## Key Differences Table

| Feature | Actors Only | Our Distributed |
|---------|-------------|-----------------|
| Command | `gleam run` | `gleam run` x3 (separate terminals) |
| OS Processes | 1 | 3 |
| Visible in `ps` | 1 PID | 3 PIDs |
| Kill one process | ❌ All die | ✅ Others survive |
| Memory | Shared | Isolated |
| Communication | In-memory | TCP/IP |
| Network sockets | ❌ No | ✅ Yes |
| Can run on different machines | ❌ No | ✅ Yes |
| Meets requirement | ❌ No | ✅ Yes |

---

## Proof Commands

### Check OS Processes
```bash
$ ps aux | grep gleam
# Actors only: Shows 1 process
# Our approach: Shows 3 processes ✅
```

### Check Network
```bash
$ netstat -an | grep 4369
# Actors only: Nothing
# Our approach: TCP connections ✅
```

### Kill One Process
```bash
$ kill <CLIENT_PID>
# Actors only: All die ❌
# Our approach: Engine + other clients survive ✅
```

---

## The Confusion Explained

**Your Friend:**
> "BEAM creates a process for each actor"

**Translation:**
- ✅ TRUE: BEAM creates **Erlang process** (lightweight actor)
- ❌ FALSE: This is NOT an **OS process** (heavyweight)

**The Requirement:**
> "Client and engine must run in separate processes"

**Means:**
- ✅ Separate **OS processes** (different PIDs, different terminals)
- ❌ NOT just separate **Erlang processes** (actors in same VM)

---

## How We Achieve It

1. **Separate `main()` entry points:**
   - `reddit_engine_standalone.gleam` → Engine OS process
   - `reddit_client_process.gleam` → Client OS process

2. **Distributed Erlang initialization:**
   - `node_manager.init_node(EngineNode)` → Makes engine a distributed node
   - `node_manager.init_node(ClientNode(1))` → Makes client a distributed node

3. **Global actor registration:**
   - Engine: `register_global("user_registry", subject)`
   - Client: `lookup_global("user_registry")` → Gets remote reference

4. **Multiple `gleam run` commands:**
   - Each command = New OS process
   - Distributed Erlang connects them via TCP

---

## Final Answer

**Question:** "Is creating actors enough?"

**Short Answer:** ❌ NO

**Long Answer:**
- Actors = Erlang processes (lightweight, in one OS process)
- Requirement = Separate OS processes (heavyweight, independent)
- Solution = Distributed Erlang + multiple `gleam run` commands

**Your friend confuses:**
- **Erlang process** (actor) ≠ **OS process** (what requirement asks for)

**We provide:**
- ✅ Multiple OS processes (correct interpretation)
- ✅ Distributed communication (TCP/IP)
- ✅ Data sharing across processes
- ✅ Can run on different machines

---

## Show Your Friend

Run this script:
```bash
./prove_separate_processes.sh
```

It will show:
1. ✅ Multiple PIDs in `ps`
2. ✅ Network sockets in `netstat`
3. ✅ Independent process control (kill one, others survive)
4. ✅ Distributed nodes in EPMD

Then read `PROCESSES_EXPLAINED.md` for full details.

---

**TL;DR:**
- Actors = Lightweight "processes" inside BEAM (not what requirement asks for)
- Our solution = True OS processes with distributed communication (what requirement asks for)
- Proof = Multiple PIDs + TCP sockets + independent control

