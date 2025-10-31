// Reddit Engine - Standalone Distributed Server
// This runs ONLY the engine actors in distributed mode
// Clients from other OS processes can connect to these actors
// Run with: gleam run -m reddit_engine_standalone

import gleam/erlang/process
import gleam/io
import reddit/distributed/node_manager
import reddit/engine/comment_manager
import reddit/engine/dm_manager
import reddit/engine/feed_generator
import reddit/engine/post_manager
import reddit/engine/subreddit_manager
import reddit/engine/user_registry

pub fn main() {
  io.println("╔═══════════════════════════════════════════════════════════╗")
  io.println("║   Reddit Engine - Distributed Standalone Server          ║")
  io.println("╚═══════════════════════════════════════════════════════════╝")
  io.println("")
  
  // Step 1: Initialize distributed node
  io.println("📡 Step 1: Initializing distributed Erlang node...")
  let assert Ok(node_name) = node_manager.init_node(node_manager.EngineNode)
  io.println("   Node name: " <> node_name)
  io.println("")
  
  // Step 2: Start all engine actors
  io.println("🚀 Step 2: Starting engine actors...")
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
  
  io.println("   ✓ User Registry")
  io.println("   ✓ Subreddit Manager")
  io.println("   ✓ Post Manager")
  io.println("   ✓ Comment Manager")
  io.println("   ✓ DM Manager")
  
  // Start feed generator (optional but useful)
  let assert Ok(feed_generator_started) =
    feed_generator.start(
      post_manager_subject,
      subreddit_manager_subject,
      user_registry_subject,
    )
  let _feed_generator_subject = feed_generator_started.data
  io.println("   ✓ Feed Generator")
  io.println("")
  
  // Step 3: Register actors globally for remote access
  io.println("🌐 Step 3: Registering actors globally...")
  let assert Ok(_) =
    node_manager.register_global("user_registry", user_registry_subject)
  let assert Ok(_) =
    node_manager.register_global("subreddit_manager", subreddit_manager_subject)
  let assert Ok(_) =
    node_manager.register_global("post_manager", post_manager_subject)
  let assert Ok(_) =
    node_manager.register_global("comment_manager", comment_manager_subject)
  let assert Ok(_) =
    node_manager.register_global("dm_manager", dm_manager_subject)
  io.println("")
  
  // Engine is ready
  io.println("╔═══════════════════════════════════════════════════════════╗")
  io.println("║   ✅ ENGINE IS RUNNING AND READY!                         ║")
  io.println("╚═══════════════════════════════════════════════════════════╝")
  io.println("")
  io.println("Engine Node: " <> node_name)
  io.println("Global Actors Registered:")
  io.println("  • user_registry")
  io.println("  • subreddit_manager")
  io.println("  • post_manager")
  io.println("  • comment_manager")
  io.println("  • dm_manager")
  io.println("")
  io.println("👉 Clients can now connect from other processes!")
  io.println("   Start clients with: gleam run -m reddit_client_process")
  io.println("")
  io.println("Press Ctrl+C to stop the engine.")
  io.println("═══════════════════════════════════════════════════════════")
  io.println("")
  
  // Keep the engine running indefinitely
  process.sleep_forever()
}

