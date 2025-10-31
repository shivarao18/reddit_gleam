// Reddit Clone Simulator - Main simulation orchestrator
// This file sets up and runs the complete Reddit simulation, including:
// - Engine actors (user registry, subreddit manager, post manager, etc.)
// - Client actors (user simulators, activity coordinator, metrics collector)
// - Simulation configuration and execution

import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import reddit/client/activity_coordinator
import reddit/client/metrics_collector
import reddit/client/user_simulator
import reddit/engine/comment_manager
import reddit/engine/dm_manager
import reddit/engine/post_manager
import reddit/engine/subreddit_manager
import reddit/engine/user_registry
import reddit/protocol
import reddit/types

pub type SimulatorConfig {
  SimulatorConfig(
    num_users: Int,
    num_subreddits: Int,
    activity_cycles: Int,
    cycle_delay_ms: Int,
  )
}

pub fn default_config() -> SimulatorConfig {
  SimulatorConfig(
    num_users: 100,
    num_subreddits: 20,
    activity_cycles: 200,
    cycle_delay_ms: 50,
  )
}

pub fn main() {
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║              REDDIT CLONE - PART I SIMULATOR                ║")
  io.println("║                                                              ║")
  io.println("║  Demonstrating Full Reddit-like Functionality               ║")
  io.println("║  - OTP Actor Model with Separate Processes                  ║")
  io.println("║  - Zipf Distribution for Realistic Activity                 ║")
  io.println("║  - All Required Features Implemented                        ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")

  let config = default_config()
  run_simulation(config)
}

pub fn run_simulation(config: SimulatorConfig) {
  io.println("┌─ Simulation Configuration ──────────────────────────────────┐")
  io.println("│ Number of Users:        " <> int.to_string(config.num_users) <> " concurrent users                  │")
  io.println("│ Number of Subreddits:   " <> int.to_string(config.num_subreddits) <> " subreddits                     │")
  io.println("│ Activity Cycles:        " <> int.to_string(config.activity_cycles) <> " cycles                         │")
  io.println("│ Cycle Delay:            " <> int.to_string(config.cycle_delay_ms) <> " ms                             │")
  io.println("└─────────────────────────────────────────────────────────────┘")
  io.println("")

  // Start engine actors
  io.println("┌─ Starting Engine Actors ────────────────────────────────────┐")
  io.println("│ Initializing Reddit Clone Engine...                         │")
  
  let assert Ok(user_registry_started) = user_registry.start()
  io.println("│   ✓ User Registry Actor                                      │")
  let assert Ok(subreddit_manager_started) = subreddit_manager.start()
  io.println("│   ✓ Subreddit Manager Actor                                  │")
  let assert Ok(post_manager_started) = post_manager.start()
  io.println("│   ✓ Post Manager Actor (with repost support!)               │")
  let assert Ok(comment_manager_started) = comment_manager.start()
  io.println("│   ✓ Comment Manager Actor (hierarchical)                    │")
  let assert Ok(dm_manager_started) = dm_manager.start()
  io.println("│   ✓ Direct Message Manager Actor                            │")
  io.println("└─────────────────────────────────────────────────────────────┘")
  io.println("")
  
  let user_registry_subject = user_registry_started.data
  let subreddit_manager_subject = subreddit_manager_started.data
  let post_manager_subject = post_manager_started.data
  let comment_manager_subject = comment_manager_started.data
  let dm_manager_subject = dm_manager_started.data

  // Create some initial subreddits
  io.println("┌─ Creating Subreddits (Zipf Distribution) ───────────────────┐")
  let subreddit_names = [
    "programming", "gleam", "erlang", "news", "technology",
    "science", "music", "gaming", "movies", "sports",
  ]

  let subreddit_ids =
    list.index_map(list.take(subreddit_names, config.num_subreddits), fn(name, idx) {
      let creator_id = "system"
      let result =
        actor.call(
          subreddit_manager_subject,
          waiting: 5000,
          sending: protocol.CreateSubreddit(name, "Subreddit about " <> name, creator_id, _),
        )
      case result {
        types.SubredditSuccess(sub) -> {
          io.println("│   ✓ r/" <> name <> " (id: " <> sub.id <> ")                        │")
          sub.id
        }
        _ -> {
          "sub_" <> int.to_string(idx + 1)
        }
      }
    })
  
  io.println("└─────────────────────────────────────────────────────────────┘")
  io.println("")

  // Start metrics collector
  let assert Ok(metrics_started) = metrics_collector.start()
  let metrics_subject = metrics_started.data
  
  // Start activity coordinator
  let activity_config = activity_coordinator.default_config()
  let assert Ok(coordinator_started) =
    activity_coordinator.start(activity_config, subreddit_ids)
  let coordinator_subject = coordinator_started.data

  io.println("┌─ Starting Client Simulators ────────────────────────────────┐")
  io.println("│ Activity Coordinator: Zipf distribution active              │")
  io.println("│ Metrics Collector: Real-time performance tracking           │")
  io.println("│ Spawning user simulator actors...                           │")
  let user_simulators =
    list.map(list.range(1, config.num_users), fn(i) {
      let username = "user_" <> int.to_string(i)
      let assert Ok(simulator_started) =
        user_simulator.start(
          username,
          user_registry_subject,
          subreddit_manager_subject,
          post_manager_subject,
          comment_manager_subject,
          dm_manager_subject,
          coordinator_subject,
          metrics_subject,
        )
      let simulator = simulator_started.data
      
      // Initialize the user
      process.send(simulator, user_simulator.Initialize)
      simulator
    })

  io.println("│ ✓ Started " <> int.to_string(config.num_users) <> " concurrent user simulators                     │")
  io.println("└─────────────────────────────────────────────────────────────┘")
  io.println("")

  // Update active users count
  process.send(metrics_subject, metrics_collector.SetActiveUsers(config.num_users))

  // Run simulation cycles
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║                 RUNNING SIMULATION                           ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")
  io.println("Simulating Reddit activities (posts, comments, votes, reposts)...")
  io.println("Users connecting/disconnecting, Zipf distribution in effect...")
  io.println("")
  run_activity_cycles(
    user_simulators,
    metrics_subject,
    config.activity_cycles,
    config.cycle_delay_ms,
  )

  // Print final report
  io.println("")
  let report =
    actor.call(
      metrics_subject,
      waiting: 5000,
      sending: metrics_collector.GetReport,
    )
  metrics_collector.print_report(report)
  
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║          SIMULATION COMPLETED SUCCESSFULLY! ✓                ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
}

fn run_activity_cycles(
  user_simulators: List(process.Subject(user_simulator.UserSimulatorMessage)),
  metrics: process.Subject(metrics_collector.MetricsMessage),
  cycles: Int,
  delay_ms: Int,
) -> Nil {
  case cycles > 0 {
    True -> {
      // Print progress every 50 cycles
      case cycles % 50 == 0 {
        True -> io.println("⚡ Cycles remaining: " <> int.to_string(cycles) <> " (Users posting, commenting, voting, reposting...)")
        False -> Nil
      }

      // Have each user perform an activity
      list.each(user_simulators, fn(simulator) {
        process.send(simulator, user_simulator.PerformActivity)
      })

      // Wait before next cycle
      process.sleep(delay_ms)

      run_activity_cycles(user_simulators, metrics, cycles - 1, delay_ms)
    }
    False -> Nil
  }
}

