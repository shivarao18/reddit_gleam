# Reddit Clone - Part I

A Reddit-like social platform implementation in Gleam using OTP and the actor model.

## Architecture

This project leverages Gleam's OTP capabilities to build a distributed, fault-tolerant Reddit clone with a client simulator.

### Engine Architecture

The engine uses a supervision tree with dedicated actors for each domain:

```
Engine Supervisor (one_for_one)
├── User Registry Actor          - Manages user accounts and authentication
├── Subreddit Manager Actor      - Handles subreddit lifecycle
├── Post Manager Actor           - Manages post creation and voting
├── Comment Manager Actor        - Handles hierarchical comments
├── DM Manager Actor             - Direct messaging between users
├── Karma Calculator Actor       - Computes user karma
└── Feed Generator Actor         - Generates personalized feeds
```

### Client Simulator Architecture

The simulator creates multiple user actors that simulate realistic behavior:

```
Client Simulator
├── Activity Coordinator         - Coordinates simulation activities
│   └── Zipf Distribution       - Models subreddit popularity
├── Metrics Collector            - Tracks performance metrics
└── User Simulator Actors (N)    - Individual user simulations
    ├── Register/Login
    ├── Join/Leave subreddits
    ├── Create posts
    ├── Comment on posts
    ├── Vote (upvote/downvote)
    └── Send direct messages
```

## Key Features

### Implemented Functionality

✅ **User Registration & Authentication**
- Unique username registration
- User state management (karma, joined subreddits, online status)
- Connection/disconnection tracking

✅ **Subreddit Management**
- Create subreddits
- Join/Leave subreddits
- Member tracking and counts

✅ **Posts**
- Create text posts in subreddits
- Upvote/Downvote posts
- Track post scores

✅ **Comments**
- Hierarchical comment structure
- Comment on posts and comments
- Upvote/Downvote comments

✅ **Direct Messaging**
- Send DMs between users
- Reply to messages
- Retrieve conversation history

✅ **Feed Generation**
- Personalized feeds based on joined subreddits
- Sorted by score and recency

✅ **Karma Calculation**
- Compute karma from upvotes/downvotes
- Real-time karma updates

### Simulator Features

✅ **Zipf Distribution**
- Realistic subreddit popularity distribution
- Popular subreddits get more activity

✅ **Activity Simulation**
- Configurable user behaviors
- Connection/disconnection cycles
- Realistic activity patterns

✅ **Performance Metrics**
- Throughput tracking (ops/sec)
- Latency measurements
- Active user counts
- Operation breakdowns

## Technical Implementation

### Actor Model Benefits

1. **Isolation**: Each component has its own isolated state
2. **Fault Tolerance**: Supervisors automatically restart failed actors
3. **Concurrency**: Thousands of lightweight processes run simultaneously
4. **Message Passing**: No shared state, all communication via messages

### Data Storage

- **In-memory**: All data stored in actor state using Gleam's persistent data structures
- **Dictionaries**: Fast lookups for users, subreddits, posts, comments
- **Lists**: Ordered collections for feeds and relationships

### Distribution Strategy

- **Engine Process**: Single Erlang node running all engine actors
- **Client Processes**: Multiple client simulator actors (can be distributed)
- **Communication**: Native OTP message passing between actors

## Project Structure

```
src/
├── reddit.gleam                          # Main entry point
├── reddit_engine.gleam                   # Engine standalone entry
├── reddit_simulator.gleam                # Simulator entry point
├── reddit/
│   ├── types.gleam                       # Core data types
│   ├── protocol.gleam                    # Message protocols
│   ├── engine/
│   │   ├── supervisor.gleam              # Engine supervisor
│   │   ├── user_registry.gleam           # User management
│   │   ├── subreddit_manager.gleam       # Subreddit management
│   │   ├── post_manager.gleam            # Post management
│   │   ├── comment_manager.gleam         # Comment management
│   │   ├── dm_manager.gleam              # Direct messaging
│   │   ├── karma_calculator.gleam        # Karma computation
│   │   └── feed_generator.gleam          # Feed generation
│   └── client/
│       ├── supervisor.gleam              # Client supervisor
│       ├── user_simulator.gleam          # User simulation
│       ├── activity_coordinator.gleam    # Activity coordination
│       ├── metrics_collector.gleam       # Performance metrics
│       └── zipf.gleam                    # Zipf distribution
```

## Installation & Setup

### Prerequisites

- Gleam >= 1.0.0
- Erlang/OTP >= 26.0

### Install Dependencies

```bash
gleam deps download
```

### Build

```bash
gleam build
```

## Running the Project

### Run Complete Simulation (Recommended)

This starts both the engine and client simulator:

```bash
gleam run
```

### Run Engine Only

```bash
gleam run -m reddit_engine
```

### Run Custom Simulation

Edit `reddit_simulator.gleam` to adjust the `SimulatorConfig`:

```gleam
SimulatorConfig(
  num_users: 50,           // Number of simulated users
  num_subreddits: 10,      // Number of subreddits to create
  activity_cycles: 100,    // How many activity cycles to run
  cycle_delay_ms: 100,     // Delay between cycles (ms)
)
```

## Performance Characteristics

### Target Scale (Part I)

- **Users**: Hundreds of concurrent users
- **Operations**: Thousands of operations per second
- **Latency**: Sub-millisecond for most operations
- **Memory**: Efficient thanks to BEAM VM

### Measured Metrics

The simulator tracks and reports:
- Total operations performed
- Operations per second (throughput)
- Average latency per operation
- Operation breakdown (posts, comments, votes, etc.)
- Active user count
- Runtime duration

## Design Decisions

### Why OTP/Actor Model?

1. **Natural fit**: Reddit's domain naturally maps to actors (users, posts, comments)
2. **Scalability**: BEAM VM can handle millions of lightweight processes
3. **Fault tolerance**: Supervisor trees ensure system reliability
4. **Distribution**: Easy to extend to distributed systems in Part II

### Why In-Memory Storage?

1. **Performance**: Fastest possible for Part I requirements
2. **Simplicity**: No database setup or maintenance
3. **Actor state**: Natural fit with actor model
4. **Part II ready**: Can easily add persistence layer

### Why Zipf Distribution?

Real social platforms follow Zipf/power-law distributions:
- Few subreddits are very popular
- Most subreddits have moderate activity
- Long tail of less popular subreddits

This creates realistic load testing scenarios.

## Future Enhancements (Part II)

- REST API endpoints
- WebSocket support for real-time updates
- Web client interface
- Database persistence
- Authentication/authorization
- Rate limiting
- Content moderation features
- Search functionality

## Testing

```bash
gleam test
```

## Development

### Adding New Features

1. Define types in `reddit/types.gleam`
2. Define messages in `reddit/protocol.gleam`
3. Implement actor in `reddit/engine/`
4. Add to supervisor in `reddit/engine/supervisor.gleam`
5. Update client simulator if needed

### Debugging

Gleam provides excellent error messages. Common issues:

- **Actor timeout**: Increase timeout in `actor.call(..., 5000)` calls
- **Pattern matching**: Ensure all cases are covered
- **Type errors**: Follow compiler suggestions

## Contributing

This is a student project for learning purposes.

## License

Educational use only.

## Acknowledgments

Built with:
- [Gleam](https://gleam.run/) - Type-safe functional language
- [OTP](https://www.erlang.org/doc/design_principles/des_princ.html) - Open Telecom Platform
- [BEAM](https://www.erlang.org/) - Erlang VM
