# Reddit Clone - Part I: Implementation Report

## Table of Contents
1. [Project Overview](#project-overview)
2. [Requirements](#requirements)
3. [Implementation](#implementation)
4. [Architecture](#architecture)
5. [Key Features](#key-features)
6. [Performance Results](#performance-results)
7. [Challenges and Solutions](#challenges-and-solutions)
8. [How to Run](#how-to-run)
9. [Conclusion](#conclusion)

---

## Project Overview

This project implements a **Reddit Clone** engine with a comprehensive client simulator in **Gleam**, leveraging the **OTP (Open Telecom Platform)** framework and the **actor model** for concurrent, fault-tolerant operation. The implementation demonstrates all required Reddit-like functionality including user management, subreddit operations, posts, hierarchical comments, voting, karma calculation, and direct messaging.

### Technology Stack
- **Language**: Gleam (Type-safe functional language on the BEAM VM)
- **Runtime**: Erlang/OTP (BEAM Virtual Machine)
- **Architecture**: Actor Model with OTP Supervision Trees
- **Data Storage**: In-memory using persistent data structures

---

## Requirements

### Reddit-like Engine Functionality
The engine implements the following core features:

✅ **User Registration**: Create unique user accounts with username validation  
✅ **Subreddit Management**: Create, join, and leave subreddits  
✅ **Posts**: Create text posts in subreddits with upvote/downvote support  
✅ **Hierarchical Comments**: Comment on posts and other comments (nested structure)  
✅ **Voting & Karma**: Upvote/downvote posts and comments, calculate user karma  
✅ **Feed Generation**: Personalized feeds based on joined subreddits  
✅ **Direct Messages**: Send and receive DMs with conversation threading  
✅ **Repost Functionality**: Repost existing content to different subreddits 

### Tester/Simulator Requirements
The simulator provides realistic testing with:

✅ **Multiple Users**: Simulates hundreds of concurrent users  
✅ **Live Connection/Disconnection**: Users connect and disconnect dynamically  
✅ **Zipf Distribution**: Realistic subreddit popularity following power-law distribution  
✅ **High Activity on Popular Subreddits**: More posts on popular subreddits  
✅ **Reposts**: Includes reposting functionality for content sharing  

### Architecture Requirements
✅ **Separate Processes**: Engine and client actors run as independent Erlang processes  
✅ **Multiple Client Processes**: Hundreds of independent user simulator actors  
✅ **Single Engine Process**: Centralized engine with multiple actor components  
✅ **Concurrent Operations**: Thousands of operations per second  

---

## Implementation

### Core Components

#### Engine Actors

1. **User Registry Actor** (`user_registry.gleam`)
   - Manages user accounts, authentication, and online status
   - Tracks user karma and joined subreddits
   - Handles user registration and profile updates

2. **Subreddit Manager Actor** (`subreddit_manager.gleam`)
   - Creates and manages subreddits
   - Tracks subreddit members and metadata
   - Handles join/leave operations

3. **Post Manager Actor** (`post_manager.gleam`)
   - Creates and retrieves posts
   - Manages post voting (upvotes/downvotes)
   - Tracks post scores and associations
   - **Sends karma updates to authors when posts are voted on**

4. **Comment Manager Actor** (`comment_manager.gleam`)
   - Handles hierarchical comment structure
   - Supports nested comment replies
   - Manages comment voting
   - **Sends karma updates to authors when comments are voted on**

5. **Direct Message Manager** (`dm_manager.gleam`)
   - Handles private messaging between users
   - Maintains conversation threading
   - Retrieves message history

6. **Feed Generator Actor** (`feed_generator.gleam`)
   - Generates personalized feeds based on subscriptions
   - Ranks posts by score and recency
   - Includes author and subreddit information

7. **Karma Calculator Actor** (`karma_calculator.gleam`)
   - Placeholder for future batch karma calculations
   - Currently, karma updates happen in real-time via async messages

#### Client Simulator Actors

1. **User Simulator Actors** (`user_simulator.gleam`)
   - Each simulates a single user's behavior
   - Performs random activities: post, comment, vote, join subreddits, send DMs
   - **40% chance to create nested comments** (replies to existing comments)
   - **50% chance to vote on posts, 50% on comments**

2. **Activity Coordinator** (`activity_coordinator.gleam`)
   - Coordinates simulation activities using Zipf distribution
   - Selects subreddits based on popularity
   - Determines activity types with configurable probabilities:
     - 20% Create Post
     - 20% Create Comment
     - 20% Cast Vote
     - 15% Create Repost
     - 15% Join Subreddit
     - 10% Send Direct Message

3. **Metrics Collector** (`metrics_collector.gleam`)
   - Tracks all operations (posts, comments, votes, etc.)
   - Calculates throughput (operations per second)
   - Reports detailed statistics

4. **Zipf Distribution** (`zipf.gleam`)
   - Implements Zipf/power-law distribution
   - Models realistic subreddit popularity
   - Ensures popular subreddits receive more activity

---

## Architecture

### Actor Model Design

```
┌─────────────────────────────────────────────────────────────┐
│                    REDDIT CLONE ENGINE                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   User      │  │  Subreddit   │  │    Post      │      │
│  │  Registry   │  │   Manager    │  │   Manager    │      │
│  └─────────────┘  └──────────────┘  └──────────────┘      │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Comment    │  │     DM       │  │    Feed      │      │
│  │  Manager    │  │   Manager    │  │  Generator   │      │
│  └─────────────┘  └──────────────┘  └──────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ OTP Message Passing
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   CLIENT SIMULATOR                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Activity   │  │   Metrics    │  │  User Sim 1  │      │
│  │ Coordinator │  │  Collector   │  │  User Sim 2  │      │
│  │   (Zipf)    │  │              │  │  User Sim 3  │      │
│  └─────────────┘  └──────────────┘  │     ...      │      │
│                                      │  User Sim N  │      │
│                                      └──────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Message Passing Architecture

All communication between actors uses **asynchronous message passing**:

1. **Synchronous Calls** (`actor.call`): Used when a response is needed
   - Register user → Returns user ID
   - Create post → Returns post ID
   - Get feed → Returns list of posts

2. **Asynchronous Messages** (`process.send`): Fire-and-forget operations
   - **Karma updates** (special async message type)
   - User initialization
   - Activity coordination

### Karma Update System

**Real-time karma tracking** is implemented through a special async message system:

1. When a post/comment receives a vote:
   - `post_manager` or `comment_manager` calculates karma delta
   - Sends `UpdateUserKarmaAsync` message to `user_registry`
   - No response needed (fire-and-forget)

2. This eliminates "actor discarding unexpected message" warnings

3. User karma reflects all votes on their posts and comments in real-time

---

## Key Features

### 1. Hierarchical Comments

**Implementation**: Comments support unlimited nesting depth

```
Post
├─ Comment 1
│  ├─ Reply to Comment 1
│  │  └─ Reply to Reply
│  └─ Another Reply
└─ Comment 2
```

**Simulator**: 40% chance to reply to existing comments instead of top-level comments

### 2. Voting & Karma System

**Voting**:
- Users can upvote or downvote posts and comments
- 70% probability for upvotes, 30% for downvotes (realistic distribution)
- Prevents duplicate votes (changes vote if user votes again)

**Karma Calculation**:
- `karma = total_upvotes - total_downvotes` across all user's posts and comments
- Updates in real-time when votes are cast
- Displayed in user profiles

### 3. Repost Functionality

**Feature**: Users can repost existing content to different subreddits
- Maintains reference to original post
- Displays repost indicator (🔁) in feed
- Allows content sharing across communities

### 4. Feed Generation

**Personalized Feeds**:
- Shows posts only from joined subreddits
- Sorted by score (upvotes - downvotes)
- Includes post metadata, author, subreddit, vote counts

**Display Example**:
```
🔥 Top 10 Posts in Feed:
═══════════════════════════

👍 #1 • Post by user_75 at 1762145599657
   └─ r/programming • u/user_75 • ↑5 ↓0 (Score: 5)
   
      💬 Comments (2):
      ├─ ➖ u/user_61: Comment by user_61
      └─ ↑0 ↓0
            ├─ ➖ u/user_85: Reply by user_85
               └─ ↑0 ↓0
```

### 5. Zipf Distribution Simulation

**Implementation**:
- Models real-world subreddit popularity
- Popular subreddits (e.g., r/programming) receive significantly more activity
- Long tail of less popular subreddits

**Parameters**:
- Zipf exponent: 1.0 (classic power-law)
- Applied to subreddit selection for posts and joins

### 6. Concurrent User Simulation

**Scalability**:
- Simulates 100 concurrent users by default
- Each user is an independent actor
- Performs activities asynchronously
- Can scale to thousands of users

---

## Performance Results

### Typical Simulation Run (100 users, 200 cycles)

```
┌─ Execution Summary ─────────────────────────────────────────┐
│ Runtime:            10 seconds                              │
│ Active Users:       100 concurrent users                    │
│ Total Operations:   13,913                                  │
│ Throughput:         1,391.3 ops/sec                         │
└─────────────────────────────────────────────────────────────┘

┌─ Feature Implementation Status ─────────────────────────────┐
│ ✓ User Registration        │    100 users registered       │
│ ✓ Create & Join Subreddits │    737 joins                  │
│ ✓ Post in Subreddit        │   3,300 posts created         │
│ ✓ Repost Content (NEW!)    │   2,605 reposts created       │
│ ✓ Hierarchical Comments    │   3,304 comments              │
│ ✓ Upvote/Downvote + Karma  │   2,247 votes cast            │
│ ✓ Direct Messages          │   1,620 messages sent         │
│ ✓ Get Feed                 │ Active                        │
│ ✓ Zipf Distribution        │ Active                        │
│ ✓ Connection Simulation    │ Active                        │
└─────────────────────────────────────────────────────────────┘
```

### Performance Characteristics

- **Throughput**: ~1,400 operations per second on typical hardware
- **Concurrency**: 100+ concurrent user actors
- **Memory**: Efficient due to BEAM VM's lightweight processes
- **Scalability**: Can handle thousands of operations with consistent performance

### Karma Tracking Validation

User karma correctly reflects votes:
```
┌─ User Profile ──────────────────────────────────────────────┐
│ 📱 Username: @user_5
│ 🏆 Karma: 12 points  ← Real-time karma from votes
│ 📚 Subscribed to 7 subreddit(s)
│ 🟢 Status: Online
└─────────────────────────────────────────────────────────────┘
```

---


## How to Run

### Prerequisites
```bash
# Ensure Gleam and Erlang are installed
gleam --version  # Should be >= 1.0.0
erl -version     # Should be >= 26.0
```

### Build the Project
```bash
cd reddit
gleam build
```

### Run the Simulation
```bash
gleam run
```

This will:
1. Start all engine actors (user registry, subreddit manager, etc.)
2. Create 10 initial subreddits
3. Start 100 user simulator actors
4. Run 200 activity cycles
5. Display detailed metrics and sample feed

### Customize Simulation

Edit `src/reddit_simulator.gleam`:

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

### Expected Output

The simulation displays:
1. Configuration summary
2. Engine actor initialization
3. Subreddit creation
4. Activity progress (every 50 cycles)
5. Performance metrics
6. Sample user profile with karma
7. Sample feed with nested comments
8. Final success confirmation

---

## Conclusion

### Achievements

✅ **All Requirements Met**:
- Complete Reddit-like engine functionality
- Comprehensive client simulator
- Zipf distribution for realistic load
- Connection/disconnection simulation
- Separate process architecture (Erlang actors)

✅ **Bonus Features**:
- Repost functionality
- Real-time karma calculation
- Performance metrics tracking
- Beautiful formatted output

✅ **Quality Implementation**:
- Type-safe with Gleam's strong type system
- Fault-tolerant using OTP principles
- Efficient concurrent operations
- Clean, maintainable code structure

### Technical Highlights

1. **Actor Model**: Natural fit for Reddit's domain model
2. **OTP Framework**: Robust, battle-tested concurrency
3. **Message Passing**: Clean separation of concerns
4. **In-Memory Storage**: Fast operations with persistent data structures
5. **Zipf Distribution**: Realistic load testing patterns

### Performance Metrics

- **13,913 total operations** in 10 seconds
- **~1,400 ops/sec** throughput
- **100 concurrent users**
- **Zero errors** or warnings
- **All features working** as demonstrated

### Readiness for Part II

The architecture is designed to easily extend to Part II:
- Add REST API layer on top of engine actors
- Expose WebSocket connections for real-time updates
- Add database persistence layer
- Implement authentication middleware
- Deploy as distributed system

---

## Project Structure

```
reddit/
├── src/
│   ├── reddit.gleam                    # Entry point
│   ├── reddit_simulator.gleam          # Main simulator
│   └── reddit/
│       ├── types.gleam                 # Core types
│       ├── protocol.gleam              # Message protocols
│       ├── engine/                     # Engine actors
│       │   ├── user_registry.gleam
│       │   ├── subreddit_manager.gleam
│       │   ├── post_manager.gleam
│       │   ├── comment_manager.gleam
│       │   ├── dm_manager.gleam
│       │   ├── karma_calculator.gleam
│       │   └── feed_generator.gleam
│       └── client/                     # Simulator actors
│           ├── user_simulator.gleam
│           ├── activity_coordinator.gleam
│           ├── metrics_collector.gleam
│           └── zipf.gleam
├── test/
│   └── reddit_test.gleam
├── README.md                           # Quick start guide
├── report.md                           # This file
└── gleam.toml                          # Project configuration
```

---

**Team Members**:  Shiva Kumar Thummanapalli and Ruchita Potamsetti


