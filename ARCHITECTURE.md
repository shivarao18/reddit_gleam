# Reddit Clone - Architecture Details

## System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         REDDIT CLONE SYSTEM                          │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                          ENGINE PROCESS                              │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    Engine Supervisor                           │ │
│  │                  (Fault Tolerance Layer)                       │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                 │                                   │
│                ┌────────────────┴───────────────────┐              │
│                │                                    │              │
│  ┌─────────────▼──────────┐        ┌──────────────▼────────────┐ │
│  │   User Registry        │        │  Subreddit Manager       │ │
│  │  ┌──────────────────┐  │        │  ┌────────────────────┐  │ │
│  │  │ users: Dict      │  │        │  │ subreddits: Dict   │  │ │
│  │  │ username_map     │  │        │  │ name_to_id: Dict   │  │ │
│  │  │ next_id: Int     │  │        │  │ next_id: Int       │  │ │
│  │  └──────────────────┘  │        │  └────────────────────┘  │ │
│  └────────────────────────┘        └─────────────────────────┘ │
│                │                                    │              │
│  ┌─────────────▼──────────┐        ┌──────────────▼────────────┐ │
│  │   Post Manager         │        │  Comment Manager         │ │
│  │  ┌──────────────────┐  │        │  ┌────────────────────┐  │ │
│  │  │ posts: Dict      │  │        │  │ comments: Dict     │  │ │
│  │  │ by_subreddit     │  │        │  │ by_post: Dict      │  │ │
│  │  │ votes: Dict      │  │        │  │ votes: Dict        │  │ │
│  │  └──────────────────┘  │        │  └────────────────────┘  │ │
│  └────────────────────────┘        └─────────────────────────┘ │
│                │                                    │              │
│  ┌─────────────▼──────────┐        ┌──────────────▼────────────┐ │
│  │   DM Manager           │        │  Karma Calculator        │ │
│  │  ┌──────────────────┐  │        │  ┌────────────────────┐  │ │
│  │  │ messages: Dict   │  │        │  │ Queries other      │  │ │
│  │  │ by_user: Dict    │  │        │  │ actors for karma   │  │ │
│  │  └──────────────────┘  │        │  └────────────────────┘  │ │
│  └────────────────────────┘        └─────────────────────────┘ │
│                                                 │                 │
│                            ┌────────────────────▼──────────────┐ │
│                            │   Feed Generator                  │ │
│                            │  ┌──────────────────────────────┐ │ │
│                            │  │ Aggregates from multiple     │ │ │
│                            │  │ actors to build feeds        │ │ │
│                            │  └──────────────────────────────┘ │ │
│                            └───────────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ OTP Messages
                                    │ (actor.call / actor.send)
                                    ▼
┌────────────────────────────────────────────────────────────────────┐
│                      CLIENT SIMULATOR PROCESS                      │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │              Client Supervisor                               │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                 │                                 │
│         ┌───────────────────────┼───────────────────────┐        │
│         │                       │                       │        │
│  ┌──────▼─────────┐   ┌─────────▼────────┐   ┌────────▼──────┐ │
│  │   Activity     │   │    Metrics       │   │ User          │ │
│  │  Coordinator   │   │   Collector      │   │ Simulators    │ │
│  │  ┌──────────┐  │   │  ┌────────────┐  │   │ (N actors)    │ │
│  │  │Zipf Dist │  │   │  │Ops/Sec     │  │   │               │ │
│  │  │Activity  │  │   │  │Latency     │  │   │┌────────────┐ │ │
│  │  │Selector  │  │   │  │Counts      │  │   ││User Sim 1  │ │ │
│  │  └──────────┘  │   │  └────────────┘  │   │└────────────┘ │ │
│  └────────────────┘   └──────────────────┘   │┌────────────┐ │ │
│                                               ││User Sim 2  │ │ │
│                                               │└────────────┘ │ │
│                                               │┌────────────┐ │ │
│                                               ││User Sim 3  │ │ │
│                                               │└────────────┘ │ │
│                                               │     ...       │ │
│                                               └──────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

## Message Flow Examples

### 1. User Registration Flow

```
User Simulator
     │
     │ RegisterUser("alice", reply_channel)
     ▼
User Registry Actor
     │
     ├─ Check if "alice" exists in username_map
     │
     ├─ Generate new user_id: "user_1"
     │
     ├─ Create User record
     │
     ├─ Insert into users Dict
     │
     ├─ Insert into username_map Dict
     │
     ├─ Increment next_id
     │
     │ RegistrationSuccess(user)
     ▼
User Simulator
```

### 2. Create Post Flow

```
User Simulator
     │
     │ CreatePost(sub_id, user_id, title, content, reply)
     ▼
Post Manager Actor
     │
     ├─ Validate title not empty
     │
     ├─ Generate post_id: "post_1"
     │
     ├─ Create Post record
     │
     ├─ Insert into posts Dict
     │
     ├─ Update posts_by_subreddit Dict
     │
     ├─ Initialize votes Dict for post
     │
     ├─ Increment next_id
     │
     │ PostSuccess(post)
     ▼
User Simulator
```

### 3. Feed Generation Flow (Complex)

```
User Simulator
     │
     │ GetFeed(user_id, limit=20, reply)
     ▼
Feed Generator
     │
     │ GetUser(user_id, reply)
     ├──────────────────────────────────────────► User Registry
     │                                                    │
     │ UserSuccess(user)                                  │
     ◄────────────────────────────────────────────────────┘
     │
     │ For each joined_subreddit:
     │   GetPostsBySubreddit(sub_id, reply)
     ├──────────────────────────────────────────► Post Manager
     │                                                    │
     │ List(Post)                                         │
     ◄────────────────────────────────────────────────────┘
     │
     │ For each post:
     │   GetSubreddit(sub_id, reply)
     ├──────────────────────────────────────────► Subreddit Mgr
     │                                                    │
     │ SubredditSuccess(subreddit)                        │
     ◄────────────────────────────────────────────────────┘
     │
     │   GetUser(author_id, reply)
     ├──────────────────────────────────────────► User Registry
     │                                                    │
     │ UserSuccess(author)                                │
     ◄────────────────────────────────────────────────────┘
     │
     ├─ Enrich post with subreddit name, author name
     │
     ├─ Calculate score (upvotes - downvotes)
     │
     ├─ Sort by score and recency
     │
     ├─ Take top 20
     │
     │ List(FeedPost)
     ▼
User Simulator
```

## Actor State Management

### User Registry State

```gleam
State(
  users: Dict(UserId, User),
  // Quick lookup: username → user_id
  username_to_id: Dict(String, UserId),
  // Auto-incrementing ID generator
  next_id: Int,
)
```

**Operations:**
- `O(log n)` user lookup by ID
- `O(log n)` user lookup by username
- `O(log n)` user insertion
- `O(1)` ID generation

### Post Manager State

```gleam
State(
  posts: Dict(PostId, Post),
  // Index for feed generation
  posts_by_subreddit: Dict(SubredditId, List(PostId)),
  // Vote tracking: post_id → (user_id → vote_type)
  post_votes: Dict(PostId, Dict(UserId, VoteType)),
  next_id: Int,
)
```

**Operations:**
- `O(log n)` post lookup
- `O(log n)` post insertion
- `O(m)` subreddit post retrieval (m = posts in subreddit)
- `O(log n)` vote recording

### Comment Manager State

```gleam
State(
  comments: Dict(CommentId, Comment),
  // Index for comment threads
  comments_by_post: Dict(PostId, List(CommentId)),
  // Vote tracking
  comment_votes: Dict(CommentId, Dict(UserId, VoteType)),
  next_id: Int,
)
```

**Features:**
- Hierarchical comments via `parent_id: Option(CommentId)`
- Efficient retrieval by post
- Per-comment vote tracking

## Concurrency Model

### Actor Isolation

```
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  User Registry   │    │  Post Manager    │    │Comment Manager   │
│                  │    │                  │    │                  │
│  Private State   │    │  Private State   │    │  Private State   │
│  ┌────────────┐  │    │  ┌────────────┐  │    │  ┌────────────┐  │
│  │users: Dict │  │    │  │posts: Dict │  │    │  │comments    │  │
│  └────────────┘  │    │  └────────────┘  │    │  └────────────┘  │
│                  │    │                  │    │                  │
│  Message Queue   │    │  Message Queue   │    │  Message Queue   │
│  ┌────────────┐  │    │  ┌────────────┐  │    │  ┌────────────┐  │
│  │Msg1        │  │    │  │Msg3        │  │    │  │Msg5        │  │
│  │Msg2        │  │    │  │Msg4        │  │    │  │Msg6        │  │
│  └────────────┘  │    │  └────────────┘  │    │  └────────────┘  │
└──────────────────┘    └──────────────────┘    └──────────────────┘
        ▲                       ▲                       ▲
        │ Messages              │                       │
        └───────────────────────┴───────────────────────┘
                     From User Simulators
```

**Key Properties:**
- Each actor has **isolated state**
- Messages are **asynchronous** (non-blocking)
- Actors process messages **sequentially** (no race conditions)
- **No shared memory** between actors
- **No locks** needed

### Fault Tolerance

```
┌─────────────────────────────────────────────┐
│         Engine Supervisor                   │
│         Strategy: one_for_one               │
│  (If one child crashes, restart only it)    │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
   ┌────▼────┐ ┌───▼────┐ ┌───▼────┐
   │Actor A  │ │Actor B │ │Actor C │
   │         │ │        │ │        │
   │  ✓      │ │  💥    │ │  ✓     │
   └─────────┘ └───▲────┘ └────────┘
                   │
              Crash detected!
                   │
                   ▼
            Supervisor restarts
            Actor B with fresh state
                   │
                   ▼
   ┌─────────┐ ┌───▼────┐ ┌────────┐
   │Actor A  │ │Actor B │ │Actor C │
   │         │ │        │ │        │
   │  ✓      │ │  ✓ NEW │ │  ✓     │
   └─────────┘ └────────┘ └────────┘
```

## Data Flow Patterns

### Read Pattern (Simple Query)

```
Client → Actor → Response
   │        │         │
   │ call() │         │
   │───────►│         │
   │        │ process │
   │        │────────►│
   │        │  reply  │
   │◄───────┼─────────┘
   │        │
   ▼        ▼
```

### Write Pattern (State Mutation)

```
Client → Actor
   │        │
   │ call() │
   │───────►│
   │        │ 1. Validate
   │        │ 2. Update state
   │        │ 3. Reply success
   │◄───────┤
   │        │
   ▼        ▼
```

### Aggregation Pattern (Multiple Actors)

```
Client → Coordinator → Multiple Actors
   │          │              │
   │  call()  │              │
   │─────────►│  parallel    │
   │          │  calls       │
   │          ├─────────────►│ Actor 1
   │          ├─────────────►│ Actor 2
   │          ├─────────────►│ Actor 3
   │          │              │
   │          │◄──results────┤
   │          │              │
   │          │ aggregate    │
   │◄─────────┤  & sort      │
   │          │              │
   ▼          ▼              ▼
```

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| User lookup | O(log n) | Dict lookup |
| Post creation | O(log n) | Dict insert |
| Vote recording | O(log n) | Nested dict |
| Feed generation | O(m × s) | m=posts per sub, s=subs |
| Comment retrieval | O(c) | c=comments on post |

### Space Complexity

| Data Structure | Space | Notes |
|---------------|-------|-------|
| User Registry | O(n) | n = users |
| Post Manager | O(p + v) | p=posts, v=votes |
| Comment Manager | O(c + v) | c=comments, v=votes |
| Subreddit Manager | O(s + m) | s=subs, m=members |

### Scalability Limits

**BEAM VM (Erlang) characteristics:**
- Processes: Millions per node
- Message passing: Millions per second
- Memory: ~2KB per process overhead
- Scheduling: Preemptive, fair

**Practical limits (single node):**
- Users: 10,000s simultaneously
- Operations: 100,000s per second
- Actors: 100,000s active
- Memory: Depends on data size

## Message Protocol Design

### Request-Reply Pattern

```gleam
// In protocol.gleam
pub type UserRegistryMessage {
  RegisterUser(
    username: String,
    reply: Subject(RegistrationResult),  // ← Reply channel
  )
}

// Usage
let result = actor.call(
  user_registry,
  RegisterUser("alice", _),  // ← _ is filled by actor.call
  5000,  // timeout
)
```

### Fire-and-Forget Pattern

```gleam
// In protocol.gleam
pub type MetricsMessage {
  RecordMetric(metric_type: MetricType)  // No reply channel
}

// Usage
actor.send(metrics, RecordMetric(PostCreated))
```

## Why This Architecture Works

### 1. Natural Domain Mapping
Reddit concepts map directly to actors:
- Users → User Registry
- Subreddits → Subreddit Manager
- Posts → Post Manager
- Comments → Comment Manager

### 2. Scalability
- Horizontal: Add more nodes
- Vertical: BEAM uses all cores
- Data: In-memory for speed

### 3. Reliability
- Supervisors restart crashed actors
- State is isolated per actor
- No cascading failures

### 4. Maintainability
- Clear boundaries between components
- Type-safe message passing
- Easy to test individual actors

### 5. Performance
- Lock-free concurrency
- Lightweight processes
- Efficient message passing
- Minimal overhead

## Future Enhancements (Part II)

```
┌────────────────────────────────────────┐
│         Web Clients (Browsers)         │
└────────────────────────────────────────┘
                  │
           HTTP/WebSocket
                  │
                  ▼
┌────────────────────────────────────────┐
│          REST API Layer                │
│  ┌──────────────────────────────────┐  │
│  │  Routes → Actor Message Mapping  │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
                  │
            OTP Messages
                  │
                  ▼
┌────────────────────────────────────────┐
│       Existing Engine Actors           │
│  (No changes needed!)                  │
└────────────────────────────────────────┘
                  │
           Database Layer
                  │
                  ▼
┌────────────────────────────────────────┐
│      PostgreSQL / Mnesia / ETS         │
└────────────────────────────────────────┘
```

The actor core remains unchanged; we just add interface layers!

