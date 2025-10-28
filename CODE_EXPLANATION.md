# Reddit Clone - Code Explanation

## Table of Contents
1. [Overall Architecture](#overall-architecture)
2. [Core Data Types](#core-data-types)
3. [The Engine](#the-engine)
4. [The Simulator](#the-simulator)
5. [Communication Protocol](#communication-protocol)
6. [Code Flow Examples](#code-flow-examples)


---

## Overall Architecture

This Reddit clone is built using the **Actor Model** in Gleam, which is a functional programming language that runs on the Erlang VM (BEAM). The system is divided into two main components:

### High-Level Structure

```
reddit/
├── src/
│   ├── reddit.gleam                    # Main entry point
│   ├── reddit_engine.gleam             # Standalone engine launcher
│   ├── reddit_simulator.gleam          # Simulator with integrated engine
│   └── reddit/
│       ├── types.gleam                 # Core data types
│       ├── protocol.gleam              # Message definitions
│       ├── engine/                     # Backend actors (the "server")
│       │   ├── supervisor.gleam        # Supervises all engine actors
│       │   ├── user_registry.gleam     # Manages users
│       │   ├── subreddit_manager.gleam # Manages subreddits
│       │   ├── post_manager.gleam      # Manages posts
│       │   ├── comment_manager.gleam   # Manages comments
│       │   ├── dm_manager.gleam        # Manages direct messages
│       │   ├── karma_calculator.gleam  # Calculates karma
│       │   └── feed_generator.gleam    # Generates feeds
│       └── client/                     # Simulation actors (the "clients")
│           ├── supervisor.gleam        # Supervises client actors
│           ├── user_simulator.gleam    # Simulates user behavior
│           ├── activity_coordinator.gleam  # Coordinates activities
│           ├── metrics_collector.gleam # Collects performance metrics
│           └── zipf.gleam              # Zipf distribution for realistic activity
```

### Key Design Principles

1. **Actor-Based Concurrency**: Each component (user registry, post manager, etc.) runs as an independent actor/process
2. **Message Passing**: Actors communicate exclusively through message passing (no shared state)
3. **Supervision**: A supervisor monitors and restarts actors if they crash
4. **Type Safety**: Gleam's type system ensures compile-time safety
5. **Immutability**: All data structures are immutable

---

## Core Data Types

All core types are defined in `src/reddit/types.gleam`:

### User Type
```gleam
pub type User {
  User(
    id: UserId,
    username: String,
    karma: Int,
    joined_subreddits: List(SubredditId),
    is_online: Bool,
    created_at: Int,
  )
}
```

### Subreddit Type
```gleam
pub type Subreddit {
  Subreddit(
    id: SubredditId,
    name: String,
    description: String,
    creator_id: UserId,
    members: List(UserId),
    member_count: Int,
    created_at: Int,
  )
}
```

### Post Type
```gleam
pub type Post {
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
}
```

### Comment Type
```gleam
pub type Comment {
  Comment(
    id: CommentId,
    post_id: PostId,
    parent_id: Option(CommentId),  // Supports nested comments
    author_id: UserId,
    content: String,
    upvotes: Int,
    downvotes: Int,
    created_at: Int,
  )
}
```

---

## The Engine

The **Engine** is the backend of the Reddit clone. It consists of multiple actor processes, each managing a specific domain.

### Engine Supervisor

The supervisor starts and monitors all engine actors:

```gleam
// src/reddit/engine/supervisor.gleam
pub fn start() -> Result(Supervisor, supervisor.StartError) {
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

### Engine Components

#### 1. User Registry (`user_registry.gleam`)

**Purpose**: Manages all user accounts and their state.

**State Structure**:
```gleam
pub type State {
  State(
    users: Dict(UserId, User),           // User ID → User data
    username_to_id: Dict(String, UserId), // Username → User ID (for lookups)
    next_id: Int,                         // Auto-incrementing ID counter
  )
}
```

**Key Operations**:
- **RegisterUser**: Creates a new user account
- **GetUser**: Retrieves user by ID
- **UpdateUserKarma**: Updates user's karma score
- **AddSubredditToUser**: Adds a subreddit to user's joined list

**Example - User Registration**:
```gleam
fn register_user(state: State, username: String) -> #(RegistrationResult, State) {
  case string.trim(username) {
    "" -> #(RegistrationError("Username cannot be empty"), state)
    trimmed_username -> {
      // Check if username already exists
      case dict.get(state.username_to_id, trimmed_username) {
        Ok(_) -> #(UsernameTaken, state)
        Error(_) -> {
          // Create new user
          let user_id = "user_" <> int.to_string(state.next_id)
          let new_user = User(
            id: user_id,
            username: trimmed_username,
            karma: 0,
            joined_subreddits: [],
            is_online: True,
            created_at: get_timestamp(),
          )
          // Update state with new user
          let new_state = State(
            users: dict.insert(state.users, user_id, new_user),
            username_to_id: dict.insert(state.username_to_id, trimmed_username, user_id),
            next_id: state.next_id + 1,
          )
          #(RegistrationSuccess(new_user), new_state)
        }
      }
    }
  }
}
```

#### 2. Subreddit Manager (`subreddit_manager.gleam`)

**Purpose**: Manages subreddits and memberships.

**State Structure**:
```gleam
pub type State {
  State(
    subreddits: Dict(SubredditId, Subreddit),  // Subreddit ID → Subreddit data
    name_to_id: Dict(String, SubredditId),     // Name → Subreddit ID
    next_id: Int,
  )
}
```

**Key Operations**:
- **CreateSubreddit**: Creates a new subreddit
- **JoinSubreddit**: Adds a user to a subreddit
- **LeaveSubreddit**: Removes a user from a subreddit
- **ListAllSubreddits**: Returns all subreddits

**Example - Joining a Subreddit**:
```gleam
fn join_subreddit(
  state: State,
  subreddit_id: SubredditId,
  user_id: UserId,
) -> #(Result(Nil, String), State) {
  case dict.get(state.subreddits, subreddit_id) {
    Ok(subreddit) -> {
      // Check if user is already a member
      case list.contains(subreddit.members, user_id) {
        True -> #(Error("User is already a member"), state)
        False -> {
          // Add user to members list and increment count
          let updated_subreddit = Subreddit(
            ..subreddit,
            members: [user_id, ..subreddit.members],
            member_count: subreddit.member_count + 1,
          )
          let new_state = State(
            ..state,
            subreddits: dict.insert(state.subreddits, subreddit_id, updated_subreddit)
          )
          #(Ok(Nil), new_state)
        }
      }
    }
    Error(_) -> #(Error("Subreddit not found"), state)
  }
}
```

#### 3. Post Manager (`post_manager.gleam`)

**Purpose**: Manages posts and voting.

**State Structure**:
```gleam
pub type State {
  State(
    posts: Dict(PostId, Post),
    posts_by_subreddit: Dict(SubredditId, List(PostId)),  // Index for fast queries
    post_votes: Dict(PostId, Dict(UserId, VoteType)),     // Tracks who voted what
    next_id: Int,
  )
}
```

**Key Operations**:
- **CreatePost**: Creates a new post
- **VotePost**: Upvote or downvote a post
- **GetPostsBySubreddit**: Retrieves all posts in a subreddit

**Example - Voting on a Post**:
```gleam
fn vote_post(
  state: State,
  post_id: PostId,
  user_id: UserId,
  vote_type: VoteType,
) -> #(Result(Nil, String), State) {
  case dict.get(state.posts, post_id) {
    Ok(post) -> {
      let votes = dict.get(state.post_votes, post_id) |> result.unwrap(dict.new())
      let previous_vote = dict.get(votes, user_id)
      
      // Calculate vote changes (handles vote switching)
      let #(upvote_delta, downvote_delta) = case previous_vote, vote_type {
        Ok(Upvote), Upvote -> #(0, 0)        // Already upvoted
        Ok(Downvote), Downvote -> #(0, 0)    // Already downvoted
        Ok(Upvote), Downvote -> #(-1, 1)     // Switch from up to down
        Ok(Downvote), Upvote -> #(1, -1)     // Switch from down to up
        Error(_), Upvote -> #(1, 0)          // New upvote
        Error(_), Downvote -> #(0, 1)        // New downvote
      }
      
      // Update post with new vote counts
      let updated_post = Post(
        ..post,
        upvotes: post.upvotes + upvote_delta,
        downvotes: post.downvotes + downvote_delta,
      )
      
      let new_state = State(
        ..state,
        posts: dict.insert(state.posts, post_id, updated_post),
        post_votes: dict.insert(state.post_votes, post_id, 
                                dict.insert(votes, user_id, vote_type)),
      )
      #(Ok(Nil), new_state)
    }
    Error(_) -> #(Error("Post not found"), state)
  }
}
```

#### 4. Comment Manager (`comment_manager.gleam`)

**Purpose**: Manages comments and nested replies.

**State Structure**:
```gleam
pub type State {
  State(
    comments: Dict(CommentId, Comment),
    comments_by_post: Dict(PostId, List(CommentId)),
    comment_votes: Dict(CommentId, Dict(UserId, VoteType)),
    next_id: Int,
  )
}
```

**Key Features**:
- Supports hierarchical comments through `parent_id: Option(CommentId)`
- Validates parent comment exists before creating a reply
- Tracks votes separately from posts

**Example - Creating a Comment**:
```gleam
fn create_comment(
  state: State,
  post_id: PostId,
  author_id: UserId,
  content: String,
  parent_id: Option(CommentId),
) -> #(CommentResult, State) {
  // Validate parent comment exists if this is a reply
  let parent_valid = case parent_id {
    option.None -> Ok(Nil)
    option.Some(pid) ->
      case dict.get(state.comments, pid) {
        Ok(_) -> Ok(Nil)
        Error(_) -> Error("Parent comment not found")
      }
  }
  
  case parent_valid {
    Ok(_) -> {
      let comment_id = "comment_" <> int.to_string(state.next_id)
      let new_comment = Comment(
        id: comment_id,
        post_id: post_id,
        parent_id: parent_id,  // Links to parent for threading
        author_id: author_id,
        content: content,
        upvotes: 0,
        downvotes: 0,
        created_at: get_timestamp(),
      )
      // Update state...
    }
    Error(err) -> #(CommentError(err), state)
  }
}
```

#### 5. Direct Message Manager (`dm_manager.gleam`)

**Purpose**: Manages private messages between users.

**State Structure**:
```gleam
pub type State {
  State(
    messages: Dict(DirectMessageId, DirectMessage),
    messages_by_user: Dict(UserId, List(DirectMessageId)),  // Inbox/outbox index
    next_id: Int,
  )
}
```

**Key Operations**:
- **SendDirectMessage**: Sends a DM from one user to another
- **GetDirectMessages**: Gets all messages for a user
- **GetConversation**: Gets messages between two specific users

---

## The Simulator

The **Simulator** simulates realistic user behavior to test the engine at scale.

### Simulator Architecture

The simulator has three main components:

1. **User Simulators**: Each simulates one user's behavior
2. **Activity Coordinator**: Decides what activities users should perform
3. **Metrics Collector**: Tracks performance metrics

### Simulator Main Flow

```gleam
// src/reddit_simulator.gleam
pub fn run_simulation(config: SimulatorConfig) {
  // 1. Start engine actors
  let assert Ok(user_registry_subject) = user_registry.start()
  let assert Ok(subreddit_manager_subject) = subreddit_manager.start()
  let assert Ok(post_manager_subject) = post_manager.start()
  let assert Ok(comment_manager_subject) = comment_manager.start()
  let assert Ok(dm_manager_subject) = dm_manager.start()

  // 2. Create initial subreddits
  let subreddit_ids = create_subreddits(...)

  // 3. Start activity coordinator
  let assert Ok(coordinator_subject) = 
    activity_coordinator.start(activity_config, subreddit_ids)

  // 4. Start user simulators (50 by default)
  let user_simulators = list.map(list.range(1, config.num_users), fn(i) {
    let assert Ok(simulator) = user_simulator.start(
      "user_" <> int.to_string(i),
      user_registry_subject,
      subreddit_manager_subject,
      post_manager_subject,
      comment_manager_subject,
      dm_manager_subject,
      coordinator_subject,
      metrics_subject,
    )
    simulator
  })

  // 5. Run activity cycles
  run_activity_cycles(user_simulators, metrics_subject, 
                      config.activity_cycles, config.cycle_delay_ms)

  // 6. Print metrics
  let report = actor.call(metrics_subject, GetReport, 5000)
  metrics_collector.print_report(report)
}
```

### 1. User Simulator (`user_simulator.gleam`)

Each user simulator is an actor that maintains user state and performs activities.

**State Structure**:
```gleam
pub type UserSimulatorState {
  UserSimulatorState(
    user_id: Option(UserId),
    username: String,
    is_online: Bool,
    joined_subreddits: List(SubredditId),
    my_posts: List(PostId),              // Tracks own posts for commenting/voting
    my_comments: List(CommentId),
    user_registry: Subject(UserRegistryMessage),
    subreddit_manager: Subject(SubredditManagerMessage),
    post_manager: Subject(PostManagerMessage),
    comment_manager: Subject(CommentManagerMessage),
    dm_manager: Subject(DirectMessageManagerMessage),
    activity_coordinator: Subject(ActivityCoordinatorMessage),
    metrics: Subject(MetricsMessage),
  )
}
```

**Activity Cycle**:
```gleam
fn perform_activity(state: UserSimulatorState) -> UserSimulatorState {
  case state.is_online, state.user_id {
    True, option.Some(user_id) -> {
      // Ask coordinator what to do
      let activity_type = actor.call(
        state.activity_coordinator,
        GetActivityType,
        5000,
      )
      
      // Perform the activity
      case activity_type {
        CreatePost -> create_post(state, user_id)
        CreateComment -> create_comment(state, user_id)
        CastVote -> cast_vote(state, user_id)
        SendDirectMessage -> send_dm(state, user_id)
        JoinSubreddit -> join_subreddit(state, user_id)
      }
    }
    _, _ -> state
  }
}
```

**Example - Creating a Post**:
```gleam
fn create_post(state: UserSimulatorState, user_id: UserId) -> UserSimulatorState {
  // Get a subreddit to post in (uses Zipf distribution for realism)
  let subreddit_id = actor.call(
    state.activity_coordinator,
    GetSubredditForActivity,
    5000,
  )
  
  let title = "Post by " <> state.username <> " at " <> int.to_string(get_timestamp())
  let content = "This is a simulated post content."
  
  // Send message to post_manager actor
  let result = actor.call(
    state.post_manager,
    CreatePost(subreddit_id, user_id, title, content, _),
    5000,
  )
  
  case result {
    PostSuccess(post) -> {
      // Record metric
      actor.send(state.metrics, RecordMetric(PostCreated))
      // Track the post for future interactions
      UserSimulatorState(..state, my_posts: [post.id, ..state.my_posts])
    }
    _ -> state
  }
}
```

### 2. Activity Coordinator (`activity_coordinator.gleam`)

The activity coordinator determines:
- **What activity** each user should perform (post, comment, vote, etc.)
- **Which subreddit** to interact with (using Zipf distribution for realistic popularity)

**Zipf Distribution**: Models real-world behavior where some subreddits are much more popular than others.

```gleam
fn select_activity_type(config: ActivityConfig) -> ActivityType {
  let random = generate_random()  // 0.0 to 1.0
  
  // Normalize probabilities
  let total = config.post_probability 
            +. config.comment_probability 
            +. config.vote_probability 
            +. config.dm_probability
  
  let post_threshold = config.post_probability /. total
  let comment_threshold = post_threshold +. config.comment_probability /. total
  let vote_threshold = comment_threshold +. config.vote_probability /. total
  
  case random {
    r if r <. post_threshold -> CreatePost
    r if r <. comment_threshold -> CreateComment
    r if r <. vote_threshold -> CastVote
    _ -> SendDirectMessage
  }
}
```

**Subreddit Selection**:
```gleam
fn select_subreddit(state: State) -> SubredditId {
  // Use Zipf distribution to select a subreddit
  let random = generate_random()
  let rank = zipf.sample(state.zipf_dist, random)
  
  // Get subreddit at this rank (1-indexed)
  // Lower ranks (1, 2, 3...) are selected more frequently
  case list.at(state.popular_subreddits, rank - 1) {
    Ok(subreddit) -> subreddit
    Error(_) -> "default_subreddit"  // Fallback
  }
}
```

### 3. Metrics Collector (`metrics_collector.gleam`)

Tracks performance metrics during simulation.

**State Structure**:
```gleam
pub type State {
  State(
    operation_counts: Dict(String, Int),  // Count of each operation type
    total_operations: Int,
    latencies: List(OperationLatency),
    start_time: Int,
    active_users: Int,
  )
}
```

**Metrics Report**:
```gleam
pub type MetricsReport {
  MetricsReport(
    total_operations: Int,
    operation_counts: Dict(String, Int),
    operations_per_second: Float,
    average_latency_ms: Float,
    active_users: Int,
    runtime_seconds: Int,
  )
}
```

**Example Output**:
```
=== Performance Metrics Report ===
Runtime: 10 seconds
Active Users: 50
Total Operations: 5000
Operations/Second: 500.0
Average Latency: 2.5 ms

Operation Breakdown:
  posts_created: 1500
  comments_created: 1500
  votes_cast: 1500
  subreddits_joined: 500
```

---

## Communication Protocol

All message types are defined in `src/reddit/protocol.gleam`.

### Message Pattern

Each message follows the **request-reply pattern**:

```gleam
pub type UserRegistryMessage {
  RegisterUser(
    username: String,
    reply: Subject(RegistrationResult),  // Reply channel
  )
  GetUser(
    user_id: UserId,
    reply: Subject(UserResult),
  )
  // ... more messages
}
```

### How Messages Work

1. **Sender** creates a message with data and a reply channel
2. **Actor** receives message, processes it, sends result to reply channel
3. **Sender** waits for response (or times out)

**Example - Calling an Actor**:
```gleam
// Synchronous call with 5-second timeout
let result = actor.call(
  user_registry_subject,
  RegisterUser("alice", _),  // _ is filled with reply channel automatically
  5000,  // 5000ms timeout
)

case result {
  RegistrationSuccess(user) -> {
    io.println("User registered: " <> user.username)
  }
  UsernameTaken -> {
    io.println("Username already taken")
  }
  RegistrationError(reason) -> {
    io.println("Error: " <> reason)
  }
}
```

**Example - Sending without waiting**:
```gleam
// Fire-and-forget (async)
actor.send(metrics_subject, RecordMetric(PostCreated))
```

---

## Code Flow Examples

### Example 1: User Creates a Post

**Step-by-step flow**:

1. **User Simulator** decides to create a post
```gleam
// user_simulator.gleam
fn perform_activity(state) {
  let activity = actor.call(state.activity_coordinator, GetActivityType, 5000)
  case activity {
    CreatePost -> create_post(state, user_id)
    // ...
  }
}
```

2. **User Simulator** asks coordinator which subreddit
```gleam
let subreddit_id = actor.call(
  state.activity_coordinator,
  GetSubredditForActivity,
  5000,
)
```

3. **Activity Coordinator** uses Zipf distribution to select popular subreddit
```gleam
// activity_coordinator.gleam
GetSubredditForActivity(reply) -> {
  let subreddit = select_subreddit(state)  // Uses Zipf
  actor.send(reply, subreddit)
}
```

4. **User Simulator** sends CreatePost message to Post Manager
```gleam
let result = actor.call(
  state.post_manager,
  CreatePost(subreddit_id, user_id, title, content, _),
  5000,
)
```

5. **Post Manager** validates and creates post
```gleam
// post_manager.gleam
CreatePost(subreddit_id, author_id, title, content, reply) -> {
  let #(result, new_state) = create_post(state, subreddit_id, author_id, title, content)
  actor.send(reply, result)  // Send back to user simulator
  actor.continue(new_state)
}
```

6. **User Simulator** records metric
```gleam
case result {
  PostSuccess(post) -> {
    actor.send(state.metrics, RecordMetric(PostCreated))
    UserSimulatorState(..state, my_posts: [post.id, ..state.my_posts])
  }
}
```

### Example 2: User Votes on Post

**Visual Flow**:
```
User Simulator
    |
    | 1. VotePost(post_id, user_id, Upvote)
    v
Post Manager
    |
    | 2. Check if post exists
    | 3. Get previous vote (if any)
    | 4. Calculate vote delta
    | 5. Update post upvotes/downvotes
    | 6. Record vote
    |
    | 7. Ok(Nil)
    v
User Simulator
    |
    | 8. RecordMetric(VoteCast)
    v
Metrics Collector
```

**Code**:
```gleam
// User simulator
let _ = actor.call(
  state.post_manager,
  VotePost(post_id, user_id, types.Upvote, _),
  5000,
)
actor.send(state.metrics, RecordMetric(VoteCast))

// Post manager handles it
fn vote_post(state, post_id, user_id, vote_type) {
  // Get current post
  case dict.get(state.posts, post_id) {
    Ok(post) -> {
      // Check previous vote
      let previous_vote = dict.get(votes, user_id)
      
      // Calculate delta (handles switching votes)
      let #(up_delta, down_delta) = calculate_vote_delta(previous_vote, vote_type)
      
      // Update post
      let updated_post = Post(
        ..post,
        upvotes: post.upvotes + up_delta,
        downvotes: post.downvotes + down_delta,
      )
      
      // Update state and return
      #(Ok(Nil), new_state)
    }
  }
}
```

### Example 3: Creating a Nested Comment

**Scenario**: User wants to reply to an existing comment

```gleam
// 1. User simulator creates a reply
let parent_comment_id = option.Some("comment_42")

let result = actor.call(
  state.comment_manager,
  CreateComment(post_id, user_id, "Great point!", parent_comment_id, _),
  5000,
)

// 2. Comment manager validates parent exists
fn create_comment(state, post_id, author_id, content, parent_id) {
  let parent_valid = case parent_id {
    option.None -> Ok(Nil)  // Top-level comment
    option.Some(pid) ->
      case dict.get(state.comments, pid) {
        Ok(_) -> Ok(Nil)  // Parent exists, valid reply
        Error(_) -> Error("Parent comment not found")
      }
  }
  
  // 3. Create comment with parent link
  case parent_valid {
    Ok(_) -> {
      let new_comment = Comment(
        id: "comment_" <> int.to_string(state.next_id),
        post_id: post_id,
        parent_id: parent_id,  // Links to parent comment
        author_id: author_id,
        content: content,
        upvotes: 0,
        downvotes: 0,
        created_at: get_timestamp(),
      )
      // ... store and return
    }
  }
}
```

---

## Summary

### Engine (Backend)
- **Actor-based**: Each manager is an independent process
- **State management**: Each actor maintains its own state (users, posts, etc.)
- **Message passing**: All communication via typed messages
- **Concurrent**: Handles multiple operations simultaneously

### Simulator (Testing/Load Generation)
- **User simulation**: Each simulated user is an actor
- **Realistic behavior**: Uses Zipf distribution for subreddit popularity
- **Coordinated**: Activity coordinator manages what users do
- **Metrics**: Tracks performance (ops/sec, latency, etc.)

### Key Advantages
1. **Fault tolerance**: Supervisors restart crashed actors
2. **Scalability**: Actors can run on multiple cores/machines
3. **Type safety**: Gleam's type system catches errors at compile time
4. **Immutability**: No shared state = no race conditions
5. **Testability**: Easy to test individual components

### Message Flow
```
Client (User Simulator)
    ↓ (sends message)
Engine Actor (e.g., Post Manager)
    ↓ (processes request)
    ↓ (updates internal state)
    ↓ (sends reply)
Client (receives response)
    ↓ (records metrics)
Metrics Collector
```

This architecture mirrors real distributed systems like Reddit, where the frontend (simulator) communicates with backend services (engine actors) via message passing!

