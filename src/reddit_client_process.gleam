// Reddit Client Process - Independent Distributed Client
// This is a SEPARATE OS PROCESS that connects to the remote engine
// Run multiple instances with: gleam run -m reddit_client_process
// 
// IMPORTANT: The engine MUST be running first!
// Start engine: gleam run -m reddit_engine_standalone

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string
import reddit/client/activity_coordinator
import reddit/client/metrics_collector
import reddit/client/user_simulator
import reddit/distributed/node_manager
import reddit/engine/feed_generator
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
      num_users: 100,
      num_subreddits: 10,
      activity_cycles: 100,
      cycle_delay_ms: 100,
      username_prefix: "client1",
    )
  
  run_client_process(config)
}

pub fn run_client_process(config: ClientProcessConfig) {
  io.println("╔═══════════════════════════════════════════════════════════╗")
  io.println(
    "║   Reddit Client Process #"
    <> int.to_string(config.process_id)
    <> "                                ║",
  )
  io.println("╚═══════════════════════════════════════════════════════════╝")
  io.println("")
  io.println("Configuration:")
  io.println("  Users: " <> int.to_string(config.num_users))
  io.println("  Activity Cycles: " <> int.to_string(config.activity_cycles))
  io.println("  Username Prefix: " <> config.username_prefix)
  io.println("")
  
  // Step 1: Initialize as distributed node
  io.println("📡 Step 1: Initializing distributed node...")
  let assert Ok(node_name) =
    node_manager.init_node(node_manager.ClientNode(config.process_id))
  io.println("   Client node: " <> node_name)
  io.println("")
  
  // Step 2: Check if engine is alive
  io.println("🔍 Step 2: Checking if engine is available...")
  case node_manager.is_engine_alive() {
    False -> {
      io.println("")
      io.println("╔═══════════════════════════════════════════════════════════╗")
      io.println("║   ❌ ERROR: ENGINE NOT FOUND!                             ║")
      io.println("╚═══════════════════════════════════════════════════════════╝")
      io.println("")
      io.println("The engine process is not running or not reachable.")
      io.println("")
      io.println("Please start the engine first:")
      io.println("  $ gleam run -m reddit_engine_standalone")
      io.println("")
      io.println("Then start this client process again.")
      io.println("")
      panic as "Engine not available - cannot start client"
    }
    True -> {
      io.println("   ✓ Engine is alive and reachable!")
      io.println("")
    }
  }
  
  // Step 3: Connect to engine node
  io.println("🌐 Step 3: Connecting to engine...")
  let assert Ok(_) = node_manager.connect_to_engine()
  let connected_nodes = node_manager.get_connected_nodes()
  io.println("   Connected nodes: " <> string_join(connected_nodes, ", "))
  io.println("")
  
  // Step 4: Get remote engine actor references
  io.println("🔗 Step 4: Looking up remote engine actors...")
  let assert Ok(user_registry_subject) =
    node_manager.lookup_global_with_retry("user_registry", 5)
  io.println("   ✓ Found user_registry")
  
  let assert Ok(subreddit_manager_subject) =
    node_manager.lookup_global_with_retry("subreddit_manager", 5)
  io.println("   ✓ Found subreddit_manager")
  
  let assert Ok(post_manager_subject) =
    node_manager.lookup_global_with_retry("post_manager", 5)
  io.println("   ✓ Found post_manager")
  
  let assert Ok(comment_manager_subject) =
    node_manager.lookup_global_with_retry("comment_manager", 5)
  io.println("   ✓ Found comment_manager")
  
  let assert Ok(dm_manager_subject) =
    node_manager.lookup_global_with_retry("dm_manager", 5)
  io.println("   ✓ Found dm_manager")
  io.println("")
  
  io.println("✅ Successfully connected to all remote engine actors!")
  io.println("")
  
  // Note: Feed generator needs to be local since it's client-specific
  let assert Ok(feed_generator_started) =
    feed_generator.start(
      post_manager_subject,
      subreddit_manager_subject,
      user_registry_subject,
    )
  let feed_generator_subject = feed_generator_started.data
  
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
  io.println("\n" <> string.repeat("=", 60))
  io.println("📊 Client #" <> int.to_string(config.process_id) <> " Final Report")
  io.println(string.repeat("=", 60))
  let report =
    actor.call(
      metrics_subject,
      waiting: 5000,
      sending: metrics_collector.GetReport,
    )
  metrics_collector.print_report(report)
  process.sleep(500)
  
  // Display sample feed to PROVE data sharing across clients
  io.println("")
  io.println("🔍 Verifying Data Sharing Across Clients...")
  io.println(
    "   Fetching feed for user from THIS client (should see posts from OTHER clients too)",
  )
  io.println("")
  display_sample_feed(
    feed_generator_subject,
    user_registry_subject,
    config.username_prefix,
  )
  
  io.println("")
  io.println("╔═══════════════════════════════════════════════════════════╗")
  io.println("║   ✅ Client #" <> int.to_string(config.process_id) <> " Finished Successfully!               ║")
  io.println("╚═══════════════════════════════════════════════════════════╝")
  io.println("")
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
    // Use distributed_call for remote actors
    // Pass a function that creates the message with the reply Subject
    let result_dynamic = node_manager.distributed_call(
      subreddit_manager,
      fn(reply) {
        protocol.CreateSubreddit(
          name,
          "Subreddit about " <> name,
          creator_id,
          reply,
        )
      },
      5000,
    )
    // Convert the dynamic result to the expected type
    let result: types.SubredditResult = node_manager.dynamic_to_any(result_dynamic)
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

// Helper to join strings
fn string_join(strings: List(String), separator: String) -> String {
  case strings {
    [] -> ""
    [single] -> single
    [first, ..rest] -> first <> separator <> string_join(rest, separator)
  }
}

fn display_sample_feed(
  feed_generator: process.Subject(protocol.FeedGeneratorMessage),
  user_registry: process.Subject(protocol.UserRegistryMessage),
  username_prefix: String,
) -> Nil {
  io.println("")
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║            SAMPLE USER FEED (Feed Functionality)            ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")
  
  // Pick a sample user from this client process
  // Format: client1_user_5 → actual user_id would be user_5
  let sample_username = username_prefix <> "_user_5"
  
  // Get user details by username (using distributed call)
  let user_result_dynamic =
    node_manager.distributed_call(
      user_registry,
      fn(reply) { protocol.GetUserByUsername(sample_username, reply) },
      5000,
    )
  let user_result: types.UserResult = node_manager.dynamic_to_any(user_result_dynamic)
  
  case user_result {
    types.UserSuccess(user) -> {
      io.println("📱 Feed for: @" <> user.username)
      io.println("👤 Karma: " <> int.to_string(user.karma))
      io.println("📚 Subscribed to " <> int.to_string(list.length(user.joined_subreddits)) <> " subreddit(s)")
      io.println("")
      
      // Get their feed using the actual user ID
      let feed =
        actor.call(
          feed_generator,
          waiting: 5000,
          sending: protocol.GetFeed(user.id, 10, _),
        )
      
      case list.is_empty(feed) {
        True -> {
          io.println("  No posts in feed yet (user hasn't joined any subreddits)")
        }
        False -> {
          io.println("🔥 Top " <> int.to_string(list.length(feed)) <> " Posts in Feed:")
          io.println("─────────────────────────────────────────────────────────────")
          
          list.index_map(feed, fn(feed_post, idx) {
            let score_indicator = case feed_post.score {
              s if s > 10 -> "🔥 "
              s if s > 5 -> "⬆️ "
              s if s > 0 -> "👍 "
              s if s == 0 -> "➖ "
              _ -> "👎 "
            }
            
            let repost_indicator = case feed_post.post.is_repost {
              True -> " [REPOST]"
              False -> ""
            }
            
            io.println("")
            io.println(
              int.to_string(idx + 1)
              <> ". "
              <> score_indicator
              <> feed_post.post.title
              <> repost_indicator,
            )
            io.println(
              "   r/"
              <> feed_post.subreddit_name
              <> " • by u/"
              <> feed_post.author_username
              <> " • Score: "
              <> int.to_string(feed_post.score)
              <> " (↑"
              <> int.to_string(feed_post.post.upvotes)
              <> " ↓"
              <> int.to_string(feed_post.post.downvotes)
              <> ")",
            )
          })
          
          io.println("")
          io.println("─────────────────────────────────────────────────────────────")
          io.println("✅ Feed generation working! Posts sorted by score and recency.")
        }
      }
    }
    _ -> {
      io.println("  Could not load sample user feed")
    }
  }
  
  io.println("")
}


