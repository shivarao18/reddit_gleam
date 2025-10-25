# Reddit Clone - Usage Guide

## Quick Start

### 1. Run the Full Simulation

The easiest way to see the system in action:

```bash
gleam run
```

This will:
1. Start all engine actors (User Registry, Subreddit Manager, etc.)
2. Create 10 initial subreddits
3. Spawn 50 user simulator actors
4. Run 100 activity cycles
5. Display performance metrics

### 2. Run Engine Only

To start just the engine without the simulator:

```bash
gleam run -m reddit_engine
```

The engine will start and wait for client connections. Press Ctrl+C to stop.

### 3. Run Custom Simulation

Edit the `reddit_simulator.gleam` file to customize the simulation:

```gleam
pub fn default_config() -> SimulatorConfig {
  SimulatorConfig(
    num_users: 100,        // Change number of users
    num_subreddits: 20,    // Change number of subreddits
    activity_cycles: 200,  // Change number of cycles
    cycle_delay_ms: 50,    // Change delay between cycles
  )
}
```

## Understanding the Output

### Startup Phase

```
=== Reddit Clone - Part I ===

By default, running the integrated simulator...
(The engine actors are started within the simulator)

=== Reddit Clone Simulator ===
Starting simulator...

Simulation Configuration:
  Users: 50
  Subreddits: 10
  Activity Cycles: 100

Starting engine actors...
✓ Engine actors started

Creating initial subreddits...
  ✓ Created r/programming
  ✓ Created r/gleam
  ...
```

### Activity Phase

```
=== Running Simulation ===
  Cycles remaining: 100
  Cycles remaining: 90
  Cycles remaining: 80
  ...
```

### Results Phase

```
=== Simulation Complete ===

=== Performance Metrics Report ===
Runtime: 12 seconds
Active Users: 50
Total Operations: 4523
Operations/Second: 376.92
Average Latency: 2.34 ms

Operation Breakdown:
  posts_created: 1134
  comments_created: 1142
  votes_cast: 1126
  subreddits_joined: 1121
  direct_messages_sent: 0
  users_registered: 50
==================================

Simulation finished successfully!
```

## Actor Communication Flow

### User Registration Flow

```
User Simulator → User Registry Actor
                 ↓
              Check username availability
                 ↓
              Create user record
                 ↓
              Return UserId
```

### Post Creation Flow

```
User Simulator → Post Manager Actor
                 ↓
              Validate subreddit
                 ↓
              Create post
                 ↓
              Update subreddit's post list
                 ↓
              Return PostId
```

### Feed Generation Flow

```
User Simulator → Feed Generator Actor
                 ↓
              Query User Registry (get joined subreddits)
                 ↓
              Query Post Manager (get posts from subreddits)
                 ↓
              Query Subreddit Manager (get subreddit names)
                 ↓
              Query User Registry (get author names)
                 ↓
              Sort by score and recency
                 ↓
              Return enriched feed
```

## Configuration Options

### Activity Coordinator Config

In `reddit/client/activity_coordinator.gleam`:

```gleam
pub fn default_config() -> ActivityConfig {
  ActivityConfig(
    num_subreddits: 20,           // Total subreddits to track
    zipf_exponent: 1.0,            // Zipf distribution parameter
    post_probability: 0.3,         // 30% chance to create post
    comment_probability: 0.3,      // 30% chance to comment
    vote_probability: 0.3,         // 30% chance to vote
    dm_probability: 0.1,           // 10% chance to send DM
  )
}
```

Adjust these to change user behavior patterns:
- Increase `post_probability` for more posts
- Increase `zipf_exponent` for more concentrated popularity
- Decrease `cycle_delay_ms` for faster simulation

## Metrics Explained

### Operations/Second (Throughput)

Total number of operations divided by runtime in seconds. Higher is better.

**Typical values:**
- 50 users: 300-500 ops/sec
- 100 users: 600-1000 ops/sec
- 200 users: 1200-2000 ops/sec

### Average Latency

Average time to complete an operation (from actor call to response).

**Typical values:**
- In-memory operations: 1-5ms
- Complex operations (feed generation): 5-20ms

### Operation Breakdown

Shows distribution of activities:
- `users_registered`: Number of users created
- `posts_created`: Total posts made
- `comments_created`: Total comments made
- `votes_cast`: Total votes (up/down)
- `subreddits_joined`: Total join operations
- `direct_messages_sent`: Total DMs sent

## Zipf Distribution Behavior

The Zipf distribution ensures realistic subreddit popularity:

- **Rank 1 (most popular)**: ~30% of all activity
- **Rank 2**: ~15% of activity
- **Rank 3**: ~10% of activity
- **Ranks 4-10**: Decreasing activity
- **Long tail**: Many subreddits with little activity

This mirrors real Reddit where a few subreddits (r/funny, r/AskReddit) dominate.

## Performance Tuning

### For Higher Throughput

1. Increase `num_users`
2. Decrease `cycle_delay_ms`
3. Increase `activity_cycles`

```gleam
SimulatorConfig(
  num_users: 200,
  num_subreddits: 20,
  activity_cycles: 500,
  cycle_delay_ms: 10,
)
```

### For Realistic Simulation

1. Match user count to real scenarios
2. Use longer cycle delays
3. Adjust activity probabilities

```gleam
SimulatorConfig(
  num_users: 100,
  num_subreddits: 50,
  activity_cycles: 1000,
  cycle_delay_ms: 500,  // 0.5 seconds between cycles
)
```

## Monitoring

The system prints progress every 10 cycles:

```
Cycles remaining: 100
Cycles remaining: 90
Cycles remaining: 80
...
```

To reduce output, modify the `run_activity_cycles` function to print less frequently:

```gleam
case cycles % 50 == 0 {  // Print every 50 cycles instead
  True -> io.println("  Cycles remaining: " <> int.to_string(cycles))
  False -> Nil
}
```

## Troubleshooting

### "Actor timeout" errors

Increase timeout in actor calls:

```gleam
// From:
actor.call(some_actor, SomeMessage, 5000)

// To:
actor.call(some_actor, SomeMessage, 10000)  // 10 second timeout
```

### Memory issues with large simulations

The metrics collector keeps the last 1000 latency measurements. For very long simulations, this can grow. The code already limits this:

```gleam
let trimmed_latencies = list.take(new_latencies, 1000)
```

### Slow feed generation

Feed generation queries multiple actors. For large numbers of joined subreddits, this can be slow. Consider:
- Limiting joined subreddits per user
- Implementing caching (Part II)
- Adding feed limits

## Integration with Part II

This Part I implementation is designed to easily extend to Part II:

1. **Add REST API**: Wrap actor calls in HTTP endpoints
2. **Add WebSockets**: Subscribe to actor state changes
3. **Add Persistence**: Save actor state to database
4. **Add Authentication**: Extend user registry with tokens
5. **Add Web Client**: Connect via HTTP/WebSocket

The actor architecture remains the same; just add interface layers.

## Testing

Run the test suite:

```bash
gleam test
```

Tests cover:
- Basic type creation
- Zipf distribution functionality
- Actor message protocols

## Architecture Benefits

### Why This Design Works

1. **Isolation**: Each actor manages its own state
2. **Concurrency**: Thousands of actors run simultaneously
3. **Fault Tolerance**: Supervisors restart failed actors
4. **Scalability**: BEAM VM handles millions of processes
5. **Message Passing**: No locks, no shared state

### Real-World Comparison

This architecture mirrors successful systems:
- **WhatsApp**: Uses Erlang/OTP for billions of messages
- **Discord**: Uses Elixir (BEAM) for real-time chat
- **RabbitMQ**: Uses Erlang for message queuing

The Reddit clone leverages the same principles at a smaller scale.

## Next Steps

1. **Experiment**: Adjust configuration values
2. **Extend**: Add new features (see README)
3. **Optimize**: Profile and improve bottlenecks
4. **Document**: Record findings and metrics
5. **Prepare**: Plan Part II REST API design

