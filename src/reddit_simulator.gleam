import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import reddit/client/activity_coordinator
import reddit/client/metrics_collector
import reddit/client/user_simulator
import reddit/engine/comment_manager
import reddit/engine/dm_manager
import reddit/engine/post_manager
import reddit/engine/subreddit_manager
import reddit/engine/user_registry
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
    num_users: 50,
    num_subreddits: 10,
    activity_cycles: 100,
    cycle_delay_ms: 100,
  )
}

pub fn main() {
  io.println("=== Reddit Clone Simulator ===")
  io.println("Starting simulator...")

  let config = default_config()
  run_simulation(config)
}

pub fn run_simulation(config: SimulatorConfig) {
  io.println("\nSimulation Configuration:")
  io.println("  Users: " <> int.to_string(config.num_users))
  io.println("  Subreddits: " <> int.to_string(config.num_subreddits))
  io.println("  Activity Cycles: " <> int.to_string(config.activity_cycles))
  io.println("")

  // Start engine actors
  io.println("Starting engine actors...")
  
  let assert Ok(user_registry_subject) = user_registry.start()
  let assert Ok(subreddit_manager_subject) = subreddit_manager.start()
  let assert Ok(post_manager_subject) = post_manager.start()
  let assert Ok(comment_manager_subject) = comment_manager.start()
  let assert Ok(dm_manager_subject) = dm_manager.start()

  io.println("✓ Engine actors started")

  // Create some initial subreddits
  io.println("\nCreating initial subreddits...")
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
          protocol.CreateSubreddit(name, "Subreddit about " <> name, creator_id, _),
          5000,
        )
      case result {
        types.SubredditSuccess(sub) -> {
          io.println("  ✓ Created r/" <> name)
          sub.id
        }
        _ -> {
          io.println("  ✗ Failed to create r/" <> name)
          "sub_" <> int.to_string(idx + 1)
        }
      }
    })

  // Start metrics collector
  let assert Ok(metrics_subject) = metrics_collector.start()
  
  // Start activity coordinator
  let activity_config = activity_coordinator.default_config()
  let assert Ok(coordinator_subject) =
    activity_coordinator.start(activity_config, subreddit_ids)

  io.println("\n✓ Activity coordinator started")

  // Start user simulators
  io.println("\nStarting user simulators...")
  let user_simulators =
    list.map(list.range(1, config.num_users), fn(i) {
      let username = "user_" <> int.to_string(i)
      let assert Ok(simulator) =
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
      
      // Initialize the user
      actor.send(simulator, user_simulator.Initialize)
      simulator
    })

  io.println("✓ Started " <> int.to_string(config.num_users) <> " user simulators")

  // Update active users count
  actor.send(metrics_subject, metrics_collector.SetActiveUsers(config.num_users))

  // Run simulation cycles
  io.println("\n=== Running Simulation ===")
  run_activity_cycles(
    user_simulators,
    metrics_subject,
    config.activity_cycles,
    config.cycle_delay_ms,
  )

  // Print final report
  io.println("\n=== Simulation Complete ===")
  let report =
    actor.call(metrics_subject, metrics_collector.GetReport, 5000)
  metrics_collector.print_report(report)

  io.println("Simulation finished successfully!")
}

fn run_activity_cycles(
  user_simulators: List(actor.Subject(user_simulator.UserSimulatorMessage)),
  metrics: actor.Subject(metrics_collector.MetricsMessage),
  cycles: Int,
  delay_ms: Int,
) -> Nil {
  case cycles > 0 {
    True -> {
      // Print progress every 10 cycles
      case cycles % 10 == 0 {
        True -> io.println("  Cycles remaining: " <> int.to_string(cycles))
        False -> Nil
      }

      // Have each user perform an activity
      list.each(user_simulators, fn(simulator) {
        actor.send(simulator, user_simulator.PerformActivity)
      })

      // Wait before next cycle
      process.sleep(delay_ms)

      run_activity_cycles(user_simulators, metrics, cycles - 1, delay_ms)
    }
    False -> Nil
  }
}

