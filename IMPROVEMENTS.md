# Reddit Clone - Improvements to Meet Requirements

This document outlines specific improvements to bring your project closer to the requirements in `requirements.md`.

## ✅ What's Already Great

Your project already implements:
- ✅ All core Reddit functionality (register, subreddits, posts, comments, voting, karma, feed, DMs)
- ✅ Hierarchical comments
- ✅ Zipf distribution for subreddit popularity
- ✅ Performance metrics collection
- ✅ Actor-based concurrent architecture
- ✅ Simulation of connection/disconnection

## 🚀 Key Improvements Needed

### 1. Multiple Independent Client Processes ⭐ HIGH PRIORITY

**Requirement**: "Use **multiple independent client processes** that simulate thousands of clients."

**Current State**: You have multiple user simulator *actors* within a single process.

**Solution**: ✅ Created
- `reddit_engine_standalone.gleam` - Runs ONLY the engine
- `reddit_client_process.gleam` - Runs ONLY clients

**How to Use**:
```bash
# Terminal 1: Start the engine
gleam run -m reddit_engine_standalone

# Terminal 2: Start client process 1
gleam run -m reddit_client_process

# Terminal 3: Start client process 2 (with different config)
gleam run -m reddit_client_process

# Terminal 4: Start client process 3
gleam run -m reddit_client_process
```

**Next Steps**:
- [ ] Implement Erlang distributed nodes to connect processes across machines
- [ ] Add node naming and registration
- [ ] Implement remote actor discovery

### 2. Increase Simulation Scale ⭐ MEDIUM PRIORITY

**Requirement**: "Simulate as many users as possible"

**Current State**: Default is 50 users, which is good but can be much higher.

**Recommendations**:
```gleam
// In reddit_simulator.gleam or reddit_client_process.gleam
SimulatorConfig(
  num_users: 500,          // Increase to 500+
  num_subreddits: 50,      // More subreddits
  activity_cycles: 1000,   // More cycles
  cycle_delay_ms: 50,      // Faster cycles
)
```

**Test at Scale**:
- [ ] Run with 500 users
- [ ] Run with 1000 users
- [ ] Run with multiple client processes (5 processes × 200 users = 1000 total)
- [ ] Measure performance at scale

### 3. Implement Re-posts ⭐ MEDIUM PRIORITY

**Requirement**: "Include some **re-posts** among the messages"

**Current State**: No re-post functionality detected.

**Solution**: Add re-post capability to the simulator:

```gleam
// In user_simulator.gleam
pub type UserSimulatorMessage {
  // ... existing messages
  RepostContent(original_post_id: PostId)
}

// In activity_coordinator.gleam
pub type ActivityConfig {
  ActivityConfig(
    // ... existing fields
    repost_probability: Float,  // Add this: 0.1 = 10% chance
  )
}
```

**Implementation Steps**:
- [ ] Add repost type to Post data structure
- [ ] Track original post ID in reposts
- [ ] Add repost action to user simulator
- [ ] Update Zipf distribution to prefer reposting popular content

### 4. Add OTP Supervisors ⭐ MEDIUM PRIORITY

**Current State**: Actors are started manually without supervision trees.

**Requirement**: OTP best practices recommend supervisors for fault tolerance.

**Solution**: Create proper supervisor modules:

```gleam
// src/reddit/engine/supervisor.gleam
import gleam/otp/supervisor

pub fn start() -> Result(supervisor.Supervisor, supervisor.StartError) {
  supervisor.start(fn(children) {
    children
    |> supervisor.add(supervisor.worker(user_registry.start))
    |> supervisor.add(supervisor.worker(subreddit_manager.start))
    |> supervisor.add(supervisor.worker(post_manager.start))
    |> supervisor.add(supervisor.worker(comment_manager.start))
    |> supervisor.add(supervisor.worker(dm_manager.start))
  })
}
```

**Benefits**:
- Automatic restart on actor crash
- Proper OTP architecture
- Better fault tolerance

### 5. Enhanced Connection/Disconnection Simulation ⭐ LOW PRIORITY

**Requirement**: "Simulate **periods of live connection and disconnection** for users"

**Current State**: Basic implementation exists.

**Enhancement**: Make it more realistic:

```gleam
pub type ConnectionState {
  Online
  Offline
  Reconnecting
}

pub type DisconnectionPattern {
  // Randomly disconnect/reconnect
  Random(disconnect_probability: Float)
  // Periodic pattern (e.g., users offline at night)
  Periodic(online_duration_ms: Int, offline_duration_ms: Int)
  // Bursty pattern (long online, long offline)
  Bursty(average_session_length_ms: Int)
}
```

### 6. Improve Zipf Distribution for Posts ⭐ MEDIUM PRIORITY

**Requirement**: "For accounts with many subscribers, increase the number of posts"

**Current State**: Zipf distribution affects which subreddits users interact with.

**Enhancement**: Also apply Zipf to:
- **User activity levels**: Some users post more than others (power users)
- **Post activity in popular subreddits**: More posts in r/programming vs r/niche_topic

```gleam
// In activity_coordinator.gleam
pub fn get_user_activity_multiplier(user_rank: Int) -> Float {
  // User 1 is most active, user N is least active
  // Returns multiplier: 1.0 = normal, 5.0 = 5x more active
  1.0 /. int.to_float(user_rank) *. 10.0
}
```

### 7. Enhanced Performance Metrics ⭐ LOW PRIORITY

**Current State**: Good basic metrics.

**Enhancements**:
- [ ] Per-operation latency breakdown (register, post, comment, vote, feed)
- [ ] Memory usage tracking
- [ ] Actor mailbox size monitoring
- [ ] Throughput per subreddit
- [ ] Real-time metrics dashboard (Part II)

```gleam
pub type DetailedMetrics {
  DetailedMetrics(
    operation_latencies: Dict(OperationType, List(Int)),
    subreddit_activity: Dict(SubredditId, ActivityMetrics),
    actor_health: Dict(ActorName, HealthStatus),
    memory_usage_mb: Int,
  )
}
```

### 8. Add Direct Message Threading ⭐ LOW PRIORITY

**Current State**: DMs exist but may not have full conversation threading.

**Enhancement**:
- Conversation threads (multiple replies)
- DM notifications
- Unread message tracking

### 9. Karma Algorithm Refinement ⭐ LOW PRIORITY

**Current State**: Basic upvote/downvote karma.

**Enhancement**: Implement Reddit-like karma algorithm:
- Post karma vs Comment karma (separate)
- Time decay (older votes worth less)
- Anti-spam fuzzing
- Karma caps per post

### 10. Add Comprehensive Testing ⭐ MEDIUM PRIORITY

**Current State**: Basic tests exist (6 passing tests).

**Enhancements**:
```bash
# Add more tests
test/
├── reddit_test.gleam              # General tests
├── engine/
│   ├── user_registry_test.gleam   # User ops
│   ├── post_manager_test.gleam    # Post ops
│   └── feed_generator_test.gleam  # Feed tests
├── client/
│   ├── zipf_test.gleam            # Distribution tests
│   └── metrics_test.gleam         # Metrics tests
└── integration/
    └── end_to_end_test.gleam      # Full workflow tests
```

## 📊 Recommended Testing Strategy

### Scale Tests
```bash
# Test 1: Baseline (current)
num_users: 50, cycles: 100
Expected: 300-500 ops/sec

# Test 2: Medium scale
num_users: 200, cycles: 500
Expected: 1000-2000 ops/sec

# Test 3: High scale
num_users: 500, cycles: 1000
Expected: 2000-5000 ops/sec

# Test 4: Multiple processes
5 client processes × 200 users each = 1000 total users
Expected: 5000-10000 ops/sec
```

### Distribution Tests
```bash
# Verify Zipf distribution
1. Run simulation with logging
2. Count posts per subreddit
3. Plot rank vs activity
4. Verify power-law distribution
```

## 🎯 Priority Implementation Order

### Phase 1: Critical (Do First)
1. ✅ Create standalone engine and client processes
2. Add re-post functionality
3. Implement proper OTP supervisors

### Phase 2: Important (Do Next)
4. Scale testing (500+ users)
5. Multiple client processes testing
6. Enhanced Zipf for user activity

### Phase 3: Polish (Do Later)
7. Enhanced metrics
8. More comprehensive tests
9. Karma algorithm refinement
10. DM threading

## 📈 Expected Results After Improvements

### Current Performance
- Users: 50
- Operations: 4,500
- Throughput: 300-500 ops/sec
- Latency: 2-5ms

### After Improvements
- Users: 1000+ (across multiple processes)
- Operations: 100,000+
- Throughput: 5,000-10,000 ops/sec
- Latency: 2-10ms
- True distributed architecture

## 🚀 Quick Start for Testing Improvements

1. **Test Separate Processes**:
```bash
# Terminal 1
gleam run -m reddit_engine_standalone

# Terminal 2-4 (in parallel)
gleam run -m reddit_client_process
```

2. **Test at Scale**:
```gleam
// Edit reddit_simulator.gleam
SimulatorConfig(
  num_users: 500,
  num_subreddits: 50,
  activity_cycles: 1000,
  cycle_delay_ms: 50,
)
```

3. **Measure Results**:
- Compare metrics before/after
- Document throughput improvements
- Profile bottlenecks

## 📝 Documentation Updates Needed

- [ ] Update README.md with multiple process instructions
- [ ] Add DISTRIBUTED.md for Part II architecture
- [ ] Create TESTING.md with test scenarios
- [ ] Add PERFORMANCE.md with benchmark results
- [ ] Update USAGE.md with new entry points

## ✅ Completion Checklist

- [x] Created standalone engine entry point
- [x] Created independent client process entry point
- [ ] Implement OTP supervisors
- [ ] Add re-post functionality
- [ ] Test with 500+ users
- [ ] Test with multiple processes
- [ ] Enhanced Zipf distribution
- [ ] Comprehensive test suite
- [ ] Performance benchmarks
- [ ] Documentation updates

## 🎓 Learning Outcomes

After implementing these improvements, your project will demonstrate:

1. ✅ True distributed systems architecture
2. ✅ OTP supervision trees (proper Erlang/OTP)
3. ✅ Scalability to thousands of concurrent users
4. ✅ Realistic simulation with Zipf distribution
5. ✅ Production-grade fault tolerance
6. ✅ Performance optimization techniques
7. ✅ Comprehensive testing strategy

This will make your project **production-ready** and **industry-standard**.


