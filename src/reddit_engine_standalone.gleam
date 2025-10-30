// Reddit Engine - Standalone server mode
// This runs ONLY the engine actors and waits for client connections
// Run with: gleam run -m reddit_engine_standalone

import gleam/erlang/process
import gleam/io
import reddit/engine/comment_manager
import reddit/engine/dm_manager
import reddit/engine/post_manager
import reddit/engine/subreddit_manager
import reddit/engine/user_registry

pub fn main() {
  io.println("=== Reddit Engine - Standalone Mode ===")
  io.println("Starting engine actors...")
  
  // Start all engine actors
  let assert Ok(user_registry_started) = user_registry.start()
  let assert Ok(subreddit_manager_started) = subreddit_manager.start()
  let assert Ok(post_manager_started) = post_manager.start()
  let assert Ok(comment_manager_started) = comment_manager.start()
  let assert Ok(dm_manager_started) = dm_manager.start()
  
  io.println("")
  io.println("✅ Engine is running!")
  io.println("Engine actors:")
  io.println("  - User Registry")
  io.println("  - Subreddit Manager")
  io.println("  - Post Manager")
  io.println("  - Comment Manager")
  io.println("  - DM Manager")
  io.println("")
  io.println("Engine is ready to accept client connections.")
  io.println("Press Ctrl+C to stop.")
  io.println("")
  
  // Keep the engine running indefinitely
  process.sleep_forever()
}

