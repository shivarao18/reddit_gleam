# Plan: Converting Reddit Clone from Simulator to REST API Server

## Table of Contents
1. [Overview](#overview)
2. [Architectural Changes](#architectural-changes)
3. [Step-by-Step Implementation](#step-by-step-implementation)
4. [API Endpoints](#api-endpoints)
5. [Code Transformation Examples](#code-transformation-examples)
6. [Testing Strategy](#testing-strategy)

---

## Overview

### Current Architecture (Part 1)
Your current implementation is a **closed-loop simulator** that:
- Starts all engine actors (user_registry, post_manager, comment_manager, etc.)
- Spawns 100 user_simulator actors that directly communicate with engine actors
- Uses `actor.call()` for synchronous communication and `process.send()` for async
- Simulates all activity in a single process space

### Target Architecture (Part 2)
The new implementation will be a **REST API web server** that:
- Keeps the engine actors running as backend services
- Exposes HTTP endpoints for clients to interact with
- Handles multiple concurrent client connections over HTTP
- Uses session tokens or JWT for authentication
- Replaces simulator actors with real client applications

---

## Architectural Changes

### Before: Simulator Architecture
```
┌─────────────────────────────────────────────────┐
│         Single Erlang Application               │
│                                                 │
│  ┌──────────────┐         ┌─────────────────┐  │
│  │ User Sim 1   │────────→│                 │  │
│  │ User Sim 2   │────────→│  Engine Actors  │  │
│  │ User Sim N   │────────→│  (User Registry,│  │
│  │              │         │   Post Manager, │  │
│  │ (Direct      │         │   etc.)         │  │
│  │  actor.call) │         │                 │  │
│  └──────────────┘         └─────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

### After: Web Server Architecture
```
┌────────────┐  HTTP/REST   ┌─────────────────────────────┐
│  Client 1  │─────────────→│   Mist HTTP Server          │
│  (CLI/Web) │              │   + Wisp Router             │
├────────────┤              │                             │
│  Client 2  │─────────────→│   ┌──────────────────────┐  │
│  (CLI/Web) │              │   │  Request Handlers    │  │
├────────────┤              │   │  (auth, posts, etc.) │  │
│  Client N  │─────────────→│   └──────────────────────┘  │
│  (CLI/Web) │              │           ↓                 │
└────────────┘              │   ┌──────────────────────┐  │
                            │   │  Engine Actors       │  │
                            │   │  (Same as before!)   │  │
                            │   │  - User Registry     │  │
                            │   │  - Post Manager      │  │
                            │   │  - Comment Manager   │  │
                            │   │  - etc.              │  │
                            │   └──────────────────────┘  │
                            └─────────────────────────────┘
```

**Key Insight**: The engine actors remain largely unchanged! We're just replacing the simulator actors with HTTP handlers.

---

## Step-by-Step Implementation

### Phase 1: Add Dependencies and Server Infrastructure

#### Step 1.1: Update `gleam.toml` dependencies
```toml
[dependencies]
gleam_stdlib = ">= 0.65.0 and < 1.0.0"
gleam_erlang = "~> 1.3"
gleam_otp    = "~> 1.2"
gleam_json   = "~> 3.0"
gleam_http   = "~> 3.6"
mist         = "~> 2.2"  # HTTP server
wisp         = "~> 0.15"  # Web framework
```

#### Step 1.2: Create server entry point
Create `src/reddit_server.gleam`:
```gleam
import gleam/erlang/process
import gleam/io
import mist
import wisp
import reddit/engine/user_registry
import reddit/engine/subreddit_manager
import reddit/engine/post_manager
import reddit/engine/comment_manager
import reddit/engine/dm_manager
import reddit/engine/feed_generator
import reddit/api/router

pub type ServerContext {
  ServerContext(
    user_registry: process.Subject(protocol.UserRegistryMessage),
    subreddit_manager: process.Subject(protocol.SubredditManagerMessage),
    post_manager: process.Subject(protocol.PostManagerMessage),
    comment_manager: process.Subject(protocol.CommentManagerMessage),
    dm_manager: process.Subject(protocol.DirectMessageManagerMessage),
    feed_generator: process.Subject(protocol.FeedGeneratorMessage),
  )
}

pub fn main() {
  io.println("Starting Reddit Clone REST API Server...")
  
  // Start all engine actors (same as before!)
  let assert Ok(user_registry_started) = user_registry.start()
  let assert Ok(subreddit_manager_started) = subreddit_manager.start()
  let assert Ok(post_manager_started) = post_manager.start()
  let assert Ok(comment_manager_started) = comment_manager.start()
  let assert Ok(dm_manager_started) = dm_manager.start()
  
  let user_registry_subject = user_registry_started.data
  let subreddit_manager_subject = subreddit_manager_started.data
  let post_manager_subject = post_manager_started.data
  let comment_manager_subject = comment_manager_started.data
  let dm_manager_subject = dm_manager_started.data
  
  // Wire up karma updates
  post_manager.set_user_registry(post_manager_subject, user_registry_subject)
  comment_manager.set_user_registry(comment_manager_subject, user_registry_subject)
  
  let assert Ok(feed_generator_started) =
    feed_generator.start(
      post_manager_subject,
      subreddit_manager_subject,
      user_registry_subject,
    )
  let feed_generator_subject = feed_generator_started.data
  
  // Create server context
  let context = ServerContext(
    user_registry: user_registry_subject,
    subreddit_manager: subreddit_manager_subject,
    post_manager: post_manager_subject,
    comment_manager: comment_manager_subject,
    dm_manager: dm_manager_subject,
    feed_generator: feed_generator_subject,
  )
  
  // Create HTTP handler
  let handler = router.handle_request(_, context)
  
  // Start HTTP server
  let assert Ok(_) =
    wisp.mist_handler(handler, "secret_key_for_sessions")
    |> mist.new
    |> mist.port(8080)
    |> mist.start_http
  
  io.println("✓ Server running on http://localhost:8080")
  io.println("✓ All engine actors started")
  io.println("✓ Ready to accept client connections")
  
  // Keep server running
  process.sleep_forever()
}
```

**What Changed?**
- ❌ No more user_simulator actors
- ❌ No more activity_coordinator or metrics_collector
- ✅ Engine actors remain the same
- ✅ HTTP server wraps the engine actors
- ✅ `process.sleep_forever()` instead of simulation cycles

---

### Phase 2: Create HTTP Router and Handlers

#### Step 2.1: Create router
Create `src/reddit/api/router.gleam`:
```gleam
import gleam/http.{Get, Post}
import gleam/string_builder
import wisp.{type Request, type Response}
import reddit_server.{type ServerContext}
import reddit/api/handlers/auth
import reddit/api/handlers/subreddit
import reddit/api/handlers/post
import reddit/api/handlers/comment
import reddit/api/handlers/feed

pub fn handle_request(req: Request, ctx: ServerContext) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  case wisp.path_segments(req) {
    // Authentication endpoints
    ["api", "auth", "register"] -> auth.register(req, ctx)
    ["api", "auth", "login"] -> auth.login(req, ctx)
    
    // Subreddit endpoints
    ["api", "subreddits"] -> subreddit.list_all(req, ctx)
    ["api", "subreddits", "create"] -> subreddit.create(req, ctx)
    ["api", "subreddits", id, "join"] -> subreddit.join(req, ctx, id)
    ["api", "subreddits", id, "leave"] -> subreddit.leave(req, ctx, id)
    
    // Post endpoints
    ["api", "posts", "create"] -> post.create(req, ctx)
    ["api", "posts", id] -> post.get(req, ctx, id)
    ["api", "posts", id, "vote"] -> post.vote(req, ctx, id)
    ["api", "posts", id, "repost"] -> post.repost(req, ctx, id)
    
    // Comment endpoints
    ["api", "comments", "create"] -> comment.create(req, ctx)
    ["api", "comments", id, "vote"] -> comment.vote(req, ctx, id)
    ["api", "posts", id, "comments"] -> comment.get_by_post(req, ctx, id)
    
    // Feed endpoint
    ["api", "feed"] -> feed.get_feed(req, ctx)
    
    // Health check
    ["health"] -> 
      wisp.ok()
      |> wisp.string_body("OK")
    
    _ -> wisp.not_found()
  }
}
```

#### Step 2.2: Create handler for user registration
Create `src/reddit/api/handlers/auth.gleam`:
```gleam
import gleam/json
import gleam/otp/actor
import wisp.{type Request, type Response}
import reddit_server.{type ServerContext}
import reddit/protocol
import reddit/types

pub fn register(req: Request, ctx: ServerContext) -> Response {
  use <- wisp.require_method(req, wisp.Post)
  
  // Parse JSON request body
  use json_body <- wisp.require_json(req)
  
  // Extract username from request
  let result = {
    use username <- decode_username(json_body)
    
    // Call the engine actor (same as before!)
    let reg_result =
      actor.call(
        ctx.user_registry,
        waiting: 5000,
        sending: protocol.RegisterUser(username, _),
      )
    
    case reg_result {
      types.RegistrationSuccess(user) -> {
        // Return success response
        let response_json =
          json.object([
            #("success", json.bool(True)),
            #("user_id", json.string(user.id)),
            #("username", json.string(user.username)),
            #("karma", json.int(user.karma)),
          ])
        
        wisp.json_response(
          json.to_string_builder(response_json),
          200,
        )
      }
      
      types.UsernameTaken -> {
        let error_json =
          json.object([
            #("success", json.bool(False)),
            #("error", json.string("Username already taken")),
          ])
        
        wisp.json_response(
          json.to_string_builder(error_json),
          409,
        )
      }
      
      types.RegistrationError(reason) -> {
        let error_json =
          json.object([
            #("success", json.bool(False)),
            #("error", json.string(reason)),
          ])
        
        wisp.json_response(
          json.to_string_builder(error_json),
          400,
        )
      }
    }
  }
}

fn decode_username(json: Dynamic) -> Result(String, Nil) {
  // JSON parsing logic here
  // You'll use gleam_json's decode functions
}
```

**Key Transformation:**
```gleam
// BEFORE (in user_simulator.gleam):
let result = actor.call(
  user_registry,
  waiting: 5000,
  sending: protocol.RegisterUser(username, _),
)
// Result used directly by simulator

// AFTER (in auth handler):
let result = actor.call(
  ctx.user_registry,
  waiting: 5000,
  sending: protocol.RegisterUser(username, _),
)
// Result converted to HTTP JSON response
```

---

### Phase 3: Authentication & Session Management

#### Step 3.1: Create simple session management
Create `src/reddit/api/auth.gleam`:
```gleam
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/otp/actor
import gleam/string
import reddit/types.{type UserId}

pub type SessionToken = String

pub type SessionState {
  SessionState(sessions: Dict(SessionToken, UserId))
}

pub type SessionMessage {
  CreateSession(user_id: UserId, reply: process.Subject(SessionToken))
  ValidateSession(token: SessionToken, reply: process.Subject(Result(UserId, Nil)))
  DeleteSession(token: SessionToken, reply: process.Subject(Nil))
}

pub fn start() -> actor.StartResult(process.Subject(SessionMessage)) {
  let initial_state = SessionState(sessions: dict.new())
  
  actor.new(initial_state)
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(
  state: SessionState,
  message: SessionMessage,
) -> actor.Next(SessionState, SessionMessage) {
  case message {
    CreateSession(user_id, reply) -> {
      let token = generate_token()
      let new_sessions = dict.insert(state.sessions, token, user_id)
      process.send(reply, token)
      actor.continue(SessionState(sessions: new_sessions))
    }
    
    ValidateSession(token, reply) -> {
      let result = dict.get(state.sessions, token)
      process.send(reply, result)
      actor.continue(state)
    }
    
    DeleteSession(token, reply) -> {
      let new_sessions = dict.delete(state.sessions, token)
      process.send(reply, Nil)
      actor.continue(SessionState(sessions: new_sessions))
    }
  }
}

fn generate_token() -> SessionToken {
  // Generate random token (use crypto library)
  "token_" <> int.to_string(erlang.system_time())
}
```

#### Step 3.2: Create middleware for authentication
Create `src/reddit/api/middleware.gleam`:
```gleam
import gleam/http
import gleam/list
import gleam/otp/actor
import wisp.{type Request, type Response}
import reddit/api/session

pub fn require_auth(
  req: Request,
  session_manager: process.Subject(session.SessionMessage),
  handler: fn(String) -> Response,
) -> Response {
  // Get token from header or cookie
  case get_auth_token(req) {
    Ok(token) -> {
      // Validate session
      let result =
        actor.call(
          session_manager,
          waiting: 1000,
          sending: session.ValidateSession(token, _),
        )
      
      case result {
        Ok(user_id) -> handler(user_id)
        Error(_) -> unauthorized_response()
      }
    }
    Error(_) -> unauthorized_response()
  }
}

fn get_auth_token(req: Request) -> Result(String, Nil) {
  // Check Authorization header
  case list.key_find(req.headers, "authorization") {
    Ok(auth_header) -> {
      // Parse "Bearer <token>"
      case string.split(auth_header, " ") {
        ["Bearer", token] -> Ok(token)
        _ -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn unauthorized_response() -> Response {
  wisp.response(401)
  |> wisp.string_body("Unauthorized")
}
```

---

### Phase 4: Create Client Application

#### Step 4.1: Create CLI client
Create `src/reddit_client.gleam`:
```gleam
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json
import gleam/result
import gleam/string

const base_url = "http://localhost:8080"

pub fn main() {
  io.println("=== Reddit Clone CLI Client ===")
  io.println("")
  
  // Example: Register a user
  io.println("1. Registering user...")
  let assert Ok(token) = register_user("alice")
  io.println("   ✓ Registered with token: " <> token)
  
  // Example: Create a subreddit
  io.println("2. Creating subreddit...")
  let assert Ok(_) = create_subreddit(token, "programming", "Discuss programming")
  io.println("   ✓ Created r/programming")
  
  // Example: Create a post
  io.println("3. Creating post...")
  let assert Ok(post_id) = create_post(token, "programming", "Hello World", "My first post!")
  io.println("   ✓ Created post: " <> post_id)
  
  // Example: Get feed
  io.println("4. Getting feed...")
  let assert Ok(feed) = get_feed(token)
  io.println("   ✓ Feed has " <> int.to_string(list.length(feed)) <> " posts")
  
  io.println("")
  io.println("✅ All operations successful!")
}

fn register_user(username: String) -> Result(String, String) {
  let body =
    json.object([#("username", json.string(username))])
    |> json.to_string
  
  let assert Ok(req) =
    request.to(base_url <> "/api/auth/register")
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> request.set_header("content-type", "application/json")
  
  // Send request (using httpc or similar)
  let assert Ok(resp) = http.send(req)
  
  case resp.status {
    200 -> {
      // Parse response to get token
      // ... JSON parsing ...
      Ok("token_123")  // Placeholder
    }
    _ -> Error("Registration failed")
  }
}

fn create_subreddit(
  token: String,
  name: String,
  description: String,
) -> Result(Nil, String) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
    ])
    |> json.to_string
  
  let assert Ok(req) =
    request.to(base_url <> "/api/subreddits/create")
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("authorization", "Bearer " <> token)
  
  let assert Ok(resp) = http.send(req)
  
  case resp.status {
    200 -> Ok(Nil)
    _ -> Error("Failed to create subreddit")
  }
}

fn create_post(
  token: String,
  subreddit: String,
  title: String,
  content: String,
) -> Result(String, String) {
  // Similar to above
  // Returns post_id
}

fn get_feed(token: String) -> Result(List(FeedPost), String) {
  // GET request to /api/feed
  // Parse JSON response
}
```

---

### Phase 5: Testing with Multiple Clients

#### Step 5.1: Create simulator for multiple clients
Create `src/reddit_load_tester.gleam`:
```gleam
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/otp/task

pub fn main() {
  io.println("=== Load Testing with Multiple Clients ===")
  
  // Spawn 10 concurrent client actors
  let tasks =
    list.range(1, 10)
    |> list.map(fn(i) {
      task.async(fn() {
        run_client_simulation(i)
      })
    })
  
  // Wait for all tasks to complete
  list.each(tasks, task.await_forever)
  
  io.println("✅ All clients completed!")
}

fn run_client_simulation(client_id: Int) -> Nil {
  let username = "user_" <> int.to_string(client_id)
  
  io.println("Client " <> int.to_string(client_id) <> " starting...")
  
  // Register
  let assert Ok(token) = reddit_client.register_user(username)
  
  // Perform random actions
  list.each(list.range(1, 20), fn(_) {
    // Random: post, comment, vote, etc.
    let _ = reddit_client.create_post(
      token,
      "programming",
      "Post by " <> username,
      "Content...",
    )
    process.sleep(100)
  })
  
  io.println("Client " <> int.to_string(client_id) <> " finished")
}
```

---

## API Endpoints

### Authentication
```
POST /api/auth/register
Body: { "username": "alice" }
Response: { "success": true, "user_id": "user_1", "token": "..." }

POST /api/auth/login
Body: { "username": "alice" }
Response: { "success": true, "token": "..." }
```

### Subreddits
```
GET /api/subreddits
Response: [ { "id": "...", "name": "programming", ... }, ... ]

POST /api/subreddits/create
Headers: Authorization: Bearer <token>
Body: { "name": "programming", "description": "..." }

POST /api/subreddits/:id/join
Headers: Authorization: Bearer <token>

POST /api/subreddits/:id/leave
Headers: Authorization: Bearer <token>
```

### Posts
```
POST /api/posts/create
Headers: Authorization: Bearer <token>
Body: {
  "subreddit_id": "sub_1",
  "title": "Hello",
  "content": "World"
}

GET /api/posts/:id
Response: { "id": "post_1", "title": "...", ... }

POST /api/posts/:id/vote
Headers: Authorization: Bearer <token>
Body: { "vote_type": "upvote" }

POST /api/posts/:id/repost
Headers: Authorization: Bearer <token>
Body: { "subreddit_id": "sub_2" }
```

### Comments
```
POST /api/comments/create
Headers: Authorization: Bearer <token>
Body: {
  "post_id": "post_1",
  "content": "Great post!",
  "parent_id": null  // or comment_id for replies
}

GET /api/posts/:id/comments
Response: [ { "id": "comment_1", ... }, ... ]

POST /api/comments/:id/vote
Headers: Authorization: Bearer <token>
Body: { "vote_type": "upvote" }
```

### Feed
```
GET /api/feed?limit=20
Headers: Authorization: Bearer <token>
Response: [ { "post": {...}, "subreddit_name": "...", ... }, ... ]
```

---

## Code Transformation Examples

### Transformation 1: User Registration

**BEFORE (Simulator):**
```gleam
// In user_simulator.gleam
fn initialize(state: State) -> State {
  let result =
    actor.call(
      state.user_registry,
      waiting: 5000,
      sending: protocol.RegisterUser(state.username, _),
    )
  
  case result {
    types.RegistrationSuccess(user) -> {
      State(..state, user_id: option.Some(user.id))
    }
    _ -> state
  }
}
```

**AFTER (Server Handler):**
```gleam
// In auth.gleam
pub fn register(req: Request, ctx: ServerContext) -> Response {
  use json_body <- wisp.require_json(req)
  use username <- decode_username(json_body)
  
  let result =
    actor.call(
      ctx.user_registry,
      waiting: 5000,
      sending: protocol.RegisterUser(username, _),
    )
  
  case result {
    types.RegistrationSuccess(user) -> {
      // Create session
      let token = create_session(ctx.session_manager, user.id)
      
      // Return JSON response
      json_response([
        #("success", json.bool(True)),
        #("user_id", json.string(user.id)),
        #("token", json.string(token)),
      ], 200)
    }
    types.UsernameTaken -> {
      json_error("Username taken", 409)
    }
    _ -> {
      json_error("Registration failed", 500)
    }
  }
}
```

### Transformation 2: Creating a Post

**BEFORE (Simulator):**
```gleam
// In user_simulator.gleam
fn create_post_activity(state: State) -> State {
  let subreddit_id = random_subreddit()
  
  let result =
    actor.call(
      state.post_manager,
      waiting: 5000,
      sending: protocol.CreatePost(
        subreddit_id,
        state.user_id,
        "Post by " <> state.username,
        "Content...",
        _,
      ),
    )
  
  case result {
    types.PostSuccess(post) -> {
      // Update metrics
      process.send(state.metrics, metrics_collector.IncrementPosts)
      state
    }
    _ -> state
  }
}
```

**AFTER (Server Handler):**
```gleam
// In post.gleam
pub fn create(req: Request, ctx: ServerContext) -> Response {
  use <- middleware.require_auth(req, ctx.session_manager)
  use json_body <- wisp.require_json(req)
  
  // Parse request
  use #(subreddit_id, title, content) <- decode_post_request(json_body)
  
  // Get user_id from session
  let user_id = get_user_from_session(req, ctx.session_manager)
  
  let result =
    actor.call(
      ctx.post_manager,
      waiting: 5000,
      sending: protocol.CreatePost(
        subreddit_id,
        user_id,
        title,
        content,
        _,
      ),
    )
  
  case result {
    types.PostSuccess(post) -> {
      json_response([
        #("success", json.bool(True)),
        #("post_id", json.string(post.id)),
        #("title", json.string(post.title)),
      ], 201)
    }
    types.PostError(reason) -> {
      json_error(reason, 400)
    }
    _ -> {
      json_error("Failed to create post", 500)
    }
  }
}
```

### Transformation 3: Main Entry Point

**BEFORE (Simulator):**
```gleam
// In reddit_simulator.gleam
pub fn main() {
  // Start engine actors
  let assert Ok(user_registry) = user_registry.start()
  // ... start other actors ...
  
  // Spawn 100 user simulators
  let user_simulators =
    list.map(list.range(1, 100), fn(i) {
      let assert Ok(sim) = user_simulator.start(...)
      process.send(sim.data, user_simulator.Initialize)
      sim.data
    })
  
  // Run activity cycles
  run_activity_cycles(user_simulators, 200, 50)
}
```

**AFTER (Server):**
```gleam
// In reddit_server.gleam
pub fn main() {
  // Start engine actors (SAME!)
  let assert Ok(user_registry) = user_registry.start()
  // ... start other actors ...
  
  // Create HTTP server context
  let ctx = ServerContext(
    user_registry: user_registry.data,
    // ... other actors ...
  )
  
  // Start HTTP server
  let handler = router.handle_request(_, ctx)
  
  wisp.mist_handler(handler, "secret_key")
  |> mist.new
  |> mist.port(8080)
  |> mist.start_http
  
  io.println("Server running on :8080")
  process.sleep_forever()
}
```

---

## Testing Strategy

### 1. Unit Tests
Test individual handlers without HTTP:
```gleam
// test/api/auth_test.gleam
pub fn register_handler_test() {
  // Start engine actors
  let assert Ok(user_registry) = user_registry.start()
  
  // Create mock context
  let ctx = ServerContext(user_registry: user_registry.data, ...)
  
  // Create mock request
  let req = create_mock_request("POST", "/api/auth/register", ...)
  
  // Call handler
  let response = auth.register(req, ctx)
  
  // Assert
  should.equal(response.status, 200)
}
```

### 2. Integration Tests
Test full HTTP flow:
```gleam
// test/integration_test.gleam
pub fn full_flow_test() {
  // Start server in test mode
  start_test_server()
  
  // Register user
  let assert Ok(token) = http_post("/api/auth/register", {...})
  
  // Create post
  let assert Ok(post_id) = http_post("/api/posts/create", {...}, token)
  
  // Get feed
  let assert Ok(feed) = http_get("/api/feed", token)
  
  // Verify post in feed
  should.be_true(list.any(feed, fn(p) { p.id == post_id }))
}
```

### 3. Load Testing
Test with multiple concurrent clients:
```bash
# Run server
gleam run -m reddit_server

# In another terminal, run load tester
gleam run -m reddit_load_tester
```

---

## Summary of Changes

### ✅ What Stays the Same
- All engine actors (user_registry, post_manager, comment_manager, etc.)
- All types in `types.gleam`
- All protocols in `protocol.gleam`
- The `actor.call()` pattern for communicating with engine actors
- Business logic and data structures

### ❌ What Gets Removed
- `user_simulator.gleam` - Replaced with HTTP clients
- `activity_coordinator.gleam` - Not needed (clients coordinate themselves)
- `metrics_collector.gleam` - Can add HTTP metrics endpoint instead
- `reddit_simulator.gleam` - Replaced with `reddit_server.gleam`

### ➕ What Gets Added
- `reddit_server.gleam` - Server entry point
- `src/reddit/api/router.gleam` - HTTP routing
- `src/reddit/api/handlers/*` - HTTP request handlers
- `src/reddit/api/auth.gleam` - Session management
- `src/reddit/api/middleware.gleam` - Authentication middleware
- `reddit_client.gleam` - CLI client application
- Dependencies: `mist`, `wisp`, `gleam_http`

---

## Next Steps

1. **Phase 1**: Add dependencies and create `reddit_server.gleam`
2. **Phase 2**: Implement router and basic auth handlers
3. **Phase 3**: Implement remaining handlers (posts, comments, etc.)
4. **Phase 4**: Create CLI client
5. **Phase 5**: Test with multiple clients
6. **Bonus**: Add digital signatures for posts

Would you like me to start implementing any specific phase?

