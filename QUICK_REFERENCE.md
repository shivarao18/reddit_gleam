# Quick Reference Guide

## Common Commands

```bash
# Run the simulation
gleam run

# Run engine only
gleam run -m reddit_engine

# Run simulator only  
gleam run -m reddit_simulator

# Run tests
gleam test

# Build project
gleam build

# Format code
gleam format

# Check types
gleam check
```

## Architecture at a Glance

```
┌─────────────────────────────────────────┐
│         Engine (Single Process)         │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌─────────────────┐ │
│  │User Registry │  │Subreddit Manager│ │
│  └──────────────┘  └─────────────────┘ │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │Post Manager  │  │Comment Manager  │ │
│  └──────────────┘  └─────────────────┘ │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │  DM Manager  │  │Feed Generator   │ │
│  └──────────────┘  └─────────────────┘ │
│  ┌──────────────┐                       │
│  │Karma Calc.   │                       │
│  └──────────────┘                       │
└─────────────────────────────────────────┘
              ↕ (Message Passing)
┌─────────────────────────────────────────┐
│      Client Simulator (N Processes)     │
├─────────────────────────────────────────┤
│  ┌────────────────────────────────────┐ │
│  │   Activity Coordinator + Zipf      │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │      Metrics Collector             │ │
│  └────────────────────────────────────┘ │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │
│  │User  │ │User  │ │User  │ │ ...  │  │
│  │Sim 1 │ │Sim 2 │ │Sim 3 │ │Sim N │  │
│  └──────┘ └──────┘ └──────┘ └──────┘  │
└─────────────────────────────────────────┘
```

## Core Types Cheat Sheet

```gleam
// User
User(
  id: UserId,
  username: String,
  karma: Int,
  joined_subreddits: List(SubredditId),
  is_online: Bool,
  created_at: Int,
)

// Subreddit
Subreddit(
  id: SubredditId,
  name: String,
  description: String,
  creator_id: UserId,
  members: List(UserId),
  member_count: Int,
  created_at: Int,
)

// Post
Post(
  id: PostId,
  subreddit_id: SubredditId,
  author_id: UserId,
  title: String,
  content: String,
  upvotes: Int,
  downvotes: Int,
  created_at: Int,
)

// Comment
Comment(
  id: CommentId,
  post_id: PostId,
  parent_id: Option(CommentId),  // Hierarchical!
  author_id: UserId,
  content: String,
  upvotes: Int,
  downvotes: Int,
  created_at: Int,
)

// Direct Message
DirectMessage(
  id: DirectMessageId,
  from_user_id: UserId,
  to_user_id: UserId,
  content: String,
  is_reply: Bool,
  reply_to_id: Option(DirectMessageId),
  created_at: Int,
)
```

## Message Patterns

### Calling an Actor

```gleam
// Synchronous call with timeout
let result = actor.call(
  actor_subject,
  SomeMessage(param1, param2, _),  // _ is reply channel
  5000,  // 5 second timeout
)

// Asynchronous send (fire and forget)
actor.send(actor_subject, SomeMessage)
```

### Handling Messages

```gleam
fn handle_message(
  message: MyMessage,
  state: State,
) -> actor.Next(MyMessage, State) {
  case message {
    DoSomething(param, reply) -> {
      let result = process(state, param)
      actor.send(reply, result)
      actor.continue(state)
    }
    
    UpdateState(new_value, reply) -> {
      let new_state = State(..state, value: new_value)
      actor.send(reply, Ok(Nil))
      actor.continue(new_state)
    }
    
    Shutdown -> {
      actor.Stop(process.Normal)
    }
  }
}
```

## Common Patterns

### Creating an Actor

```gleam
pub fn start() -> Result(actor.StartResult(MyMessage), actor.StartError) {
  let initial_state = State(...)
  actor.start(initial_state, handle_message)
}
```

### Adding to Supervisor

```gleam
supervisor.start(fn(children) {
  children
  |> supervisor.add(supervisor.worker(my_actor.start))
  |> supervisor.add(supervisor.worker(another_actor.start))
})
```

## Configuration Quick Edit

### Change Number of Users

In `reddit_simulator.gleam`:
```gleam
SimulatorConfig(
  num_users: 100,  // ← Change this
  ...
)
```

### Change Activity Mix

In `reddit/client/activity_coordinator.gleam`:
```gleam
ActivityConfig(
  post_probability: 0.4,      // ← More posts
  comment_probability: 0.3,   // ← Fewer comments
  vote_probability: 0.2,      // ← Fewer votes
  dm_probability: 0.1,
)
```

### Change Zipf Distribution

In `reddit/client/activity_coordinator.gleam`:
```gleam
ActivityConfig(
  zipf_exponent: 1.5,  // ← Higher = more concentrated
  ...
)
```

## Debugging Tips

### Add Debug Logging

```gleam
import gleam/io

io.println("Current state: ")
io.debug(state)
```

### Increase Timeouts

```gleam
// Change from:
actor.call(subject, Message, 5000)

// To:
actor.call(subject, Message, 30000)  // 30 seconds
```

### Print Performance Stats

```gleam
let report = actor.call(metrics_subject, GetReport, 5000)
metrics_collector.print_report(report)
```

## File Locations

```
Core Types:        src/reddit/types.gleam
Message Protocols: src/reddit/protocol.gleam

Engine:
  Supervisor:      src/reddit/engine/supervisor.gleam
  Users:           src/reddit/engine/user_registry.gleam
  Subreddits:      src/reddit/engine/subreddit_manager.gleam
  Posts:           src/reddit/engine/post_manager.gleam
  Comments:        src/reddit/engine/comment_manager.gleam
  DMs:             src/reddit/engine/dm_manager.gleam
  Karma:           src/reddit/engine/karma_calculator.gleam
  Feed:            src/reddit/engine/feed_generator.gleam

Client:
  Simulator:       src/reddit/client/user_simulator.gleam
  Coordinator:     src/reddit/client/activity_coordinator.gleam
  Metrics:         src/reddit/client/metrics_collector.gleam
  Zipf:            src/reddit/client/zipf.gleam

Entry Points:
  Main:            src/reddit.gleam
  Engine Only:     src/reddit_engine.gleam
  Simulator:       src/reddit_simulator.gleam
```

## Typical Performance

| Users | Ops/Sec | Latency |
|-------|---------|---------|
| 10    | 80-120  | 1-2ms   |
| 50    | 300-500 | 2-4ms   |
| 100   | 600-1000| 3-6ms   |
| 200   | 1200-2000| 4-8ms  |

## Error Handling

```gleam
// Result types
case result {
  Ok(value) -> // Handle success
  Error(reason) -> // Handle error
}

// Type-specific results
case user_result {
  UserSuccess(user) -> // Use user
  UserNotFound -> // Handle not found
  UserError(reason) -> // Handle error
}
```

## Adding a New Feature

1. **Define type** in `types.gleam`
2. **Add messages** in `protocol.gleam`
3. **Create actor** in `reddit/engine/your_feature.gleam`
4. **Update supervisor** to start your actor
5. **Update simulator** to use new feature
6. **Add tests** in `test/`

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Actor timeout | Increase timeout value |
| Type error | Check message protocol matches |
| Slow performance | Reduce cycle_delay_ms |
| Memory issues | Check metrics collector limit |
| Build fails | Run `gleam clean` then `gleam build` |

## Useful Links

- [Gleam Documentation](https://gleam.run/documentation/)
- [OTP Design Principles](https://www.erlang.org/doc/design_principles/des_princ.html)
- [Actor Model](https://en.wikipedia.org/wiki/Actor_model)
- [Zipf's Law](https://en.wikipedia.org/wiki/Zipf%27s_law)

## Quick Examples

### Register a User
```gleam
let result = actor.call(
  user_registry,
  protocol.RegisterUser("alice", _),
  5000
)
```

### Create a Post
```gleam
let result = actor.call(
  post_manager,
  protocol.CreatePost(subreddit_id, user_id, "Title", "Content", _),
  5000
)
```

### Vote on Post
```gleam
let result = actor.call(
  post_manager,
  protocol.VotePost(post_id, user_id, types.Upvote, _),
  5000
)
```

### Get Feed
```gleam
let feed = actor.call(
  feed_generator,
  protocol.GetFeed(user_id, 20, _),
  5000
)
```

## Remember

- **Message passing** is asynchronous by nature
- **State is immutable** - always return new state
- **Actors crash safely** - supervisors restart them
- **Types are your friend** - trust the compiler
- **Metrics matter** - always measure performance

