# Reddit Clone - Gleam Implementation

A Reddit-like social platform implementation in Gleam using OTP and the actor model, featuring **cryptographic digital signatures** for post authentication.

## 🔐 Bonus Feature: Digital Signatures

This implementation includes a **public-key cryptographic signature system** for all posts:

- ✅ **RSA-2048** and **ECDSA P-256** support
- ✅ Users provide public keys during registration
- ✅ Posts are digitally signed at creation time
- ✅ Signatures automatically verified when posts are retrieved
- ✅ Tamper detection and authentication guarantees

## Quick Start

### Prerequisites

- **Gleam** >= 1.0.0
- **Erlang/OTP** >= 26.0

### Installation

```bash
# Clone or navigate to the project directory
cd reddit

# Download dependencies
gleam deps download

# Build the project
gleam build
```

### Run the Simulation

```bash
gleam run
```

This will:
1. Start the Reddit Clone engine (all actors)
2. Create initial subreddits
3. Simulate 100 concurrent users
4. Run 200 activity cycles
5. Display performance metrics and sample feed

### Run Crypto Demo

```bash
gleam run -m reddit_crypto_demo
```

This demonstrates:
1. **RSA-2048 Digital Signatures** - Key generation, signing, and verification
2. **ECDSA P-256 Digital Signatures** - Key generation, signing, and verification
3. **Tampering Detection** - Shows how signature verification fails when content is modified

**Expected Output**:
- ✓ RSA-2048 keypair generation and signature verification
- ✓ ECDSA P-256 keypair generation and signature verification
- ✓ Tampering detection demonstration (verification fails on modified content)

### Expected Output

The simulation will display:
- ✅ Configuration summary
- ✅ Engine initialization progress
- ✅ Subreddit creation
- ✅ Real-time activity updates
- ✅ Performance metrics (throughput, operation counts)
- ✅ Sample user profile with karma
- ✅ Sample feed with nested comments
- ✅ Success confirmation

## Features Implemented

### Core Features
✅ User Registration & Authentication  
✅ Create/Join/Leave Subreddits  
✅ Post in Subreddits  
✅ Hierarchical Comments (nested replies)  
✅ Upvote/Downvote with Real-time Karma  
✅ Personalized Feed Generation  
✅ Direct Messaging  
✅ Repost Functionality  
✅ Zipf Distribution for Realistic Load  
✅ Concurrent User Simulation  

### 🔐 Bonus: Cryptographic Signatures
✅ **RSA-2048** with SHA-256 digital signatures  
✅ **ECDSA P-256** with SHA-256 digital signatures  
✅ Public key storage and retrieval  
✅ Automatic signature verification on post retrieval  
✅ Client-side key generation and signing  
✅ Server-side signature validation  
✅ Tamper detection and authenticity guarantees  

**Security Properties**:
- ✅ Authentication: Signatures prove post authorship
- ✅ Integrity: Detects any content modification
- ✅ Non-repudiation: Authors can't deny signed posts
- ✅ Isolation: Cross-user signature forgery prevented  

## Configuration

To customize the simulation, edit `src/reddit_simulator.gleam`:

```gleam
pub fn default_config() -> SimulatorConfig {
  SimulatorConfig(
    num_users: 100,          // Number of simulated users
    num_subreddits: 20,      // Subreddits to create
    activity_cycles: 200,    // Activity cycles to run
    cycle_delay_ms: 50,      // Delay between cycles (ms)
  )
}
```

## Architecture

### Engine Actors (Separate Erlang Processes)
- **User Registry** - User accounts, authentication, and **public key storage**
- **Subreddit Manager** - Subreddit lifecycle management
- **Post Manager** - Post creation, voting, and **signature validation**
- **Comment Manager** - Hierarchical comments
- **DM Manager** - Direct messaging
- **Feed Generator** - Personalized feed generation

### Cryptographic Components (New)
- **Key Manager** - RSA-2048 and ECDSA P-256 key generation
- **Signature Module** - Message signing and verification
- **Crypto Types** - Type definitions for keys and signatures

### Client Simulator
- **100 User Simulator Actors** - Independent concurrent users with **crypto support**
- **Activity Coordinator** - Zipf distribution for realistic load
- **Metrics Collector** - Performance tracking

All components run as **separate Erlang processes** (actors) communicating via message passing.

## Performance

Typical results with 100 users, 200 cycles:
- **~14,000 total operations** in 10 seconds
- **~1,400 ops/sec** throughput
- **Zero warnings or errors**
- **All features working** as demonstrated

## Project Structure

```
src/
├── reddit_simulator.gleam          # Main entry point & simulator
├── reddit_client.gleam             # CLI client with crypto support
├── reddit_multi_client.gleam       # Multi-client demo with crypto
├── reddit_key_generator.gleam      # Crypto key generator (RSA/ECDSA)
├── reddit_server.gleam             # REST API server
└── reddit/
    ├── types.gleam                 # Core data types (with crypto fields)
    ├── protocol.gleam              # Message protocols
    ├── crypto/                     # 🔐 Cryptographic modules (NEW)
    │   ├── types.gleam             # Crypto type definitions
    │   ├── key_manager.gleam       # Key generation and management
    │   └── signature.gleam         # Signing and verification
    ├── engine/                     # Engine actors
    │   ├── user_registry.gleam     # (updated with public keys)
    │   ├── subreddit_manager.gleam
    │   ├── post_manager.gleam      # (updated with signatures)
    │   ├── comment_manager.gleam
    │   ├── dm_manager.gleam
    │   ├── karma_calculator.gleam
    │   └── feed_generator.gleam
    ├── api/                        # REST API handlers
    │   ├── router.gleam
    │   ├── types.gleam
    │   └── handlers/
    │       ├── auth.gleam          # (updated with key handling)
    │       ├── post.gleam          # (updated with signatures)
    │       ├── subreddit.gleam
    │       ├── comment.gleam
    │       └── dm.gleam
    └── client/                     # Simulator actors
        ├── user_simulator.gleam
        ├── activity_coordinator.gleam
        ├── metrics_collector.gleam
        └── zipf.gleam
```

## Testing

```bash
gleam test
```

**Test Coverage**:
- ✅ 6 Core functionality tests
- ✅ 20 Cryptographic integration tests
- ✅ Total: 26 tests, 100% pass rate

## REST API Server

### Starting the Server

```bash
gleam run -m reddit_server
```

The server starts on `http://localhost:3000` with 6 OTP actors handling all operations.

### API Endpoints (18 Total)

#### Health & Info
- `GET /health` - Server health check
- `GET /` - API information and endpoint list

#### Authentication
- `POST /api/auth/register` - Register new user
  - Body: `{"username":"alice"}` (basic)
  - Body: `{"username":"alice","public_key":"...","key_algorithm":"RSA2048"}` (with crypto)
- `GET /api/auth/user/:username` - Get user by username

#### Users
- `GET /api/users/:user_id/public-key` - Get user's public key (for signature verification)

#### Subreddits
- `GET /api/subreddits` - List all subreddits
- `POST /api/subreddits/create` - Create subreddit
  - Body: `{"name":"gleam","description":"Gleam programming","creator_id":"user_1"}`
- `POST /api/subreddits/:id/join` - Join subreddit
  - Body: `{"user_id":"user_1"}`
- `POST /api/subreddits/:id/leave` - Leave subreddit
  - Body: `{"user_id":"user_1"}`

#### Posts
- `POST /api/posts/create` - Create new post
  - Body: `{"author_id":"user_1","subreddit_id":"sub_1","title":"Hello","content":"World"}` (basic)
  - Body: `{"author_id":"user_1","subreddit_id":"sub_1","title":"Hello","content":"World","signature":"...","signature_algorithm":"RSA2048"}` (signed)
- `GET /api/posts/:id` - Get post by ID (includes `signature_verified` field)
- `POST /api/posts/:id/vote` - Vote on post
  - Body: `{"user_id":"user_2","vote_type":"upvote"}` or `"downvote"`
- `POST /api/posts/:id/repost` - Repost content
  - Body: `{"user_id":"user_2","subreddit_id":"sub_2"}`
- `GET /api/posts/:id/comments` - Get all comments for a post

#### Comments
- `POST /api/comments/create` - Create comment
  - Body: `{"author_id":"user_3","post_id":"post_1","content":"Great!"}` (top-level)
  - Body: `{"author_id":"user_3","post_id":"post_1","parent_comment_id":"comment_1","content":"Reply"}` (nested)
- `POST /api/comments/:id/vote` - Vote on comment
  - Body: `{"user_id":"user_1","vote_type":"upvote"}`

#### Feed
- `GET /api/feed/:user_id` - Get personalized feed (posts from joined subreddits)

#### Direct Messages
- `POST /api/dm/send` - Send direct message
  - Body: `{"from_user_id":"user_1","to_user_id":"user_2","content":"Hello!"}`
- `GET /api/dm/user/:user_id` - Get all DMs for a user
- `GET /api/dm/conversation/:user1_id/:user2_id` - Get conversation between two users

### Example Usage

```bash
# Start server
gleam run -m reddit_server

# Register user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice"}'

# Create subreddit
curl -X POST http://localhost:3000/api/subreddits/create \
  -H "Content-Type: application/json" \
  -d '{"name":"gleam","description":"Gleam programming language","creator_id":"user_1"}'

# Create post
curl -X POST http://localhost:3000/api/posts/create \
  -H "Content-Type: application/json" \
  -d '{"author_id":"user_1","subreddit_id":"sub_1","title":"Why Gleam is awesome","content":"Type safety on the BEAM!"}'

# Get feed
curl http://localhost:3000/api/feed/user_1
```

### Response Format

All endpoints return JSON in this format:

**Success**:
```json
{
  "success": true,
  "data": { /* resource data */ }
}
```

**Error**:
```json
{
  "success": false,
  "error": "ErrorType",
  "message": "Description"
}
```

## Cryptographic Signatures

### Supported Algorithms

- **RSA-2048** with SHA-256 (industry standard, max compatibility)
- **ECDSA P-256** with SHA-256 (modern, smaller keys/signatures)

### Signature Workflow

1. **Client generates keypair** (RSA or ECDSA)
2. **Register with public key**: `POST /api/auth/register` with `public_key` and `key_algorithm`
3. **Sign posts client-side** before sending
4. **Server verifies signatures** automatically using stored public key
5. **Posts include** `signature_verified: true/false` field

### Security Properties

- ✅ **Authentication**: Proves who created the post
- ✅ **Integrity**: Detects any content modification
- ✅ **Non-repudiation**: Authors can't deny signed posts
- ✅ **Isolation**: Cross-user forgery prevented

### Example: Creating Signed Post

```bash
# 1. Generate keys (client-side)
gleam run -m reddit_client  # Generates RSA-2048 keypair

# 2. Register with public key
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","public_key":"MIIBIjAN...","key_algorithm":"RSA2048"}'

# 3. Sign post (client computes signature)
# Message format: post_id|author_id|title|content|timestamp

# 4. Create signed post
curl -X POST http://localhost:3000/api/posts/create \
  -H "Content-Type: application/json" \
  -d '{
    "author_id":"user_1",
    "subreddit_id":"sub_1",
    "title":"My Post",
    "content":"Content here",
    "signature":"W8vS6Tm9fxE...",
    "signature_algorithm":"RSA2048"
  }'

# 5. Retrieve post (server already verified)
curl http://localhost:3000/api/posts/post_1
# Response includes: "signature_verified": true
```

## Automated Clients

### Key Generator (For Manual Testing)

```bash
gleam run -m reddit_key_generator
```

Generates valid cryptographic keys for manual API testing:
- **RSA-2048** keypair (public + private keys)
- **ECDSA P-256** keypair (public + private keys)
- Ready-to-use `curl` commands for user registration
- Solves PowerShell quote escaping issues

**Use Case**: Run this before manually registering users with crypto keys via `curl` commands.

### Single Client Demo

```bash
gleam run -m reddit_client
```

Demonstrates complete workflow:
- RSA-2048 keypair generation
- User registration with public key
- Subreddit creation
- Signed post creation
- Signature verification (server and client-side)

### Multi-Client Demo

```bash
gleam run -m reddit_multi_client
```

Demonstrates:
- 3 concurrent HTTP clients
- User 1: RSA-2048 signatures
- User 2: ECDSA P-256 signatures
- User 3: No crypto (backward compatible)
- Signature isolation testing

## Documentation

- **README.md** (this file) - Quick start guide and API documentation
- **report.md** - Part I implementation report
- **PART2_REPORT.md** - Part II REST API report

## Technology Stack

- **Language**: Gleam (Type-safe functional language)
- **Runtime**: Erlang/OTP (BEAM Virtual Machine)
- **Architecture**: Actor Model with OTP Supervision
- **Data Storage**: In-memory with persistent data structures
- **Cryptography**: gleam_crypto (~> 1.3) - RSA-2048 & ECDSA P-256
- **Web Framework**: Mist + Wisp for REST API
- **Encoding**: Base64 for key/signature transmission

---

## Project Status

**Completion**: 100% (Part I + Part II + Bonus)  
**Tests**: 26/26 passing (6 core + 20 crypto)  
**REST API**: 18 endpoints fully functional  
**Crypto**: RSA-2048 and ECDSA P-256 signatures  

### Key Achievements
✅ Complete Reddit Clone with actor-based engine (Part I)  
✅ RESTful API with 18 endpoints (Part II)  
✅ HTTP-based client-server communication  
✅ RSA-2048 and ECDSA P-256 digital signatures (Bonus)  
✅ Automatic signature verification  
✅ Multiple concurrent clients supported  
✅ Comprehensive test coverage (100% passing)  

---

## License

Educational use only.

---

**For detailed implementation information, see [report.md](report.md)**
