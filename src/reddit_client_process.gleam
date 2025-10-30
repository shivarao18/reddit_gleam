// Reddit Client Process - Independent client simulator
// This is a SEPARATE PROCESS that connects to the engine
// Run multiple instances with: gleam run -m reddit_client_process

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

pub type ClientProcessConfig {
  ClientProcessConfig(
    process_id: Int,
    // Number of users THIS process simulates
    num_users: Int,
    num_subreddits: Int,
    activity_cycles: Int,
    cycle_delay_ms: Int,
    // Username prefix for this process
    username_prefix: String,
  )
}

pub fn main() {
  io.println("=== Reddit Client Process ===")
  io.println("This is an independent client simulator process")
  io.println("")
  
  // Default config for a single client process
  let config =
    ClientProcessConfig(
      process_id: 1,
      num_users: 10,
      num_subreddits: 10,
      activity_cycles: 100,
      cycle_delay_ms: 100,
      username_prefix: "client1",
    )
  
  run_client_process(config)
}

pub fn run_client_process(config: ClientProcessConfig) {
  io.println(
    "Client Process #"
    <> int.to_string(config.process_id)
    <> " Configuration:",
  )
  io.println("  Users: " <> int.to_string(config.num_users))
  io.println("  Activity Cycles: " <> int.to_string(config.activity_cycles))
  io.println("")
  
  // NOTE: In a real distributed setup, you would connect to remote engine actors
  // For now, we'll start local actors but document the architecture
  io.println("⚠ TODO: Connect to remote engine actors")
  io.println("  For Part I, starting local engine actors as placeholder")
  io.println("")
  
  // Start local engine actors (in production, these would be remote references)
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
  
  // Get or create subreddits
  let subreddit_ids = get_or_create_subreddits(subreddit_manager_subject, config.num_subreddits)
  
  // Start metrics collector
  let assert Ok(metrics_started) = metrics_collector.start()
  let metrics_subject = metrics_started.data
  
  // Start activity coordinator
  let activity_config = activity_coordinator.default_config()
  let assert Ok(coordinator_started) =
    activity_coordinator.start(activity_config, subreddit_ids)
  let coordinator_subject = coordinator_started.data
  
  // Start user simulators with unique names for this process
  io.println("Starting user simulators...")
  let user_simulators =
    list.map(list.range(1, config.num_users), fn(i) {
      let username =
        config.username_prefix
        <> "_user_"
        <> int.to_string(i)
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
  
  io.println(
    "✓ Started "
    <> int.to_string(config.num_users)
    <> " user simulators in this process",
  )
  
  // Update active users count
  process.send(
    metrics_subject,
    metrics_collector.SetActiveUsers(config.num_users),
  )
  
  // Run simulation cycles
  io.println("\n=== Running Client Simulation ===")
  run_activity_cycles(
    user_simulators,
    metrics_subject,
    config.activity_cycles,
    config.cycle_delay_ms,
  )
  
  // Print final report
  io.println("\n=== Client Process Complete ===")
  let report =
    actor.call(
      metrics_subject,
      waiting: 5000,
      sending: metrics_collector.GetReport,
    )
  metrics_collector.print_report(report)
  
  io.println("Client process finished!")
}

fn get_or_create_subreddits(
  subreddit_manager: process.Subject(protocol.SubredditManagerMessage),
  num: Int,
) -> List(String) {
  let subreddit_names = [
    "programming", "gleam", "erlang", "news", "technology", "science", "music",
    "gaming", "movies", "sports",
  ]
  
  list.index_map(list.take(subreddit_names, num), fn(name, idx) {
    let creator_id = "system"
    let result =
      actor.call(
        subreddit_manager,
        waiting: 5000,
        sending: protocol.CreateSubreddit(
          name,
          "Subreddit about " <> name,
          creator_id,
          _,
        ),
      )
    case result {
      types.SubredditSuccess(sub) -> sub.id
      _ -> "sub_" <> int.to_string(idx + 1)
    }
  })
}

fn run_activity_cycles(
  user_simulators: List(process.Subject(user_simulator.UserSimulatorMessage)),
  metrics: process.Subject(metrics_collector.MetricsMessage),
  cycles: Int,
  delay_ms: Int,
) {
  case cycles > 0 {
    True -> {
      // Print progress every 10 cycles
      case cycles % 10 == 0 {
        True -> io.println("  Cycles remaining: " <> int.to_string(cycles))
        False -> Nil
      }
      
      // Trigger activity for all users
      list.each(user_simulators, fn(user_sim) {
        process.send(user_sim, user_simulator.PerformActivity)
      })
      
      // Wait before next cycle
      process.sleep(delay_ms)
      
      // Recurse
      run_activity_cycles(user_simulators, metrics, cycles - 1, delay_ms)
    }
    False -> Nil
  }
}


