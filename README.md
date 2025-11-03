# Reddit Clone - Part I

A Reddit-like social platform implementation in Gleam using OTP and the actor model.

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
- **User Registry** - User accounts and authentication
- **Subreddit Manager** - Subreddit lifecycle management
- **Post Manager** - Post creation and voting
- **Comment Manager** - Hierarchical comments
- **DM Manager** - Direct messaging
- **Feed Generator** - Personalized feed generation

### Client Simulator
- **100 User Simulator Actors** - Independent concurrent users
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
└── reddit/
    ├── types.gleam                 # Core data types
    ├── protocol.gleam              # Message protocols
    ├── engine/                     # Engine actors
    │   ├── user_registry.gleam
    │   ├── subreddit_manager.gleam
    │   ├── post_manager.gleam
    │   ├── comment_manager.gleam
    │   ├── dm_manager.gleam
    │   ├── karma_calculator.gleam
    │   └── feed_generator.gleam
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

## Documentation

- **README.md** (this file) - Quick start guide
- **report.md** - Comprehensive implementation report with:
  - Detailed architecture
  - Implementation challenges and solutions
  - Performance analysis
  - Complete feature documentation

## Technology Stack

- **Language**: Gleam (Type-safe functional language)
- **Runtime**: Erlang/OTP (BEAM Virtual Machine)
- **Architecture**: Actor Model with OTP Supervision
- **Data Storage**: In-memory with persistent data structures

## License

Educational use only.

---

**For detailed implementation information, see [report.md](report.md)**
