// Reddit Clone Server - REST API Server Entry Point
// This is the main entry point for the HTTP server that exposes the Reddit engine via REST API.

import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import mist
import reddit/api/router
import reddit/engine/comment_manager
import reddit/engine/dm_manager
import reddit/engine/feed_generator
import reddit/engine/post_manager
import reddit/engine/subreddit_manager
import reddit/engine/user_registry
import reddit/server_context.{ServerContext}

pub fn main() {
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║           REDDIT CLONE - REST API SERVER                    ║")
  io.println("║                                                              ║")
  io.println("║  Converting Part I Simulator to Web Server (Part II)        ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")

  // Start all engine actors (same as simulator!)
  io.println("┌─ Starting Engine Actors ────────────────────────────────────┐")
  io.println("│ Initializing Reddit Clone Engine...                         │")

  let assert Ok(user_registry_started) = user_registry.start()
  io.println("│   ✓ User Registry Actor                                      │")

  let assert Ok(subreddit_manager_started) = subreddit_manager.start()
  io.println("│   ✓ Subreddit Manager Actor                                  │")

  let assert Ok(post_manager_started) = post_manager.start()
  io.println("│   ✓ Post Manager Actor                                       │")

  let assert Ok(comment_manager_started) = comment_manager.start()
  io.println("│   ✓ Comment Manager Actor                                    │")

  let assert Ok(dm_manager_started) = dm_manager.start()
  io.println("│   ✓ Direct Message Manager Actor                            │")

  let user_registry_subject = user_registry_started.data
  let subreddit_manager_subject = subreddit_manager_started.data
  let post_manager_subject = post_manager_started.data
  let comment_manager_subject = comment_manager_started.data
  let dm_manager_subject = dm_manager_started.data

  // Wire up user_registry to post and comment managers for karma updates
  post_manager.set_user_registry(post_manager_subject, user_registry_subject)
  comment_manager.set_user_registry(
    comment_manager_subject,
    user_registry_subject,
  )

  let assert Ok(feed_generator_started) =
    feed_generator.start(
      post_manager_subject,
      subreddit_manager_subject,
      user_registry_subject,
    )
  io.println("│   ✓ Feed Generator Actor                                     │")
  io.println("└─────────────────────────────────────────────────────────────┘")
  io.println("")

  let feed_generator_subject = feed_generator_started.data

  // Create server context with all actor references
  let context =
    ServerContext(
      user_registry: user_registry_subject,
      subreddit_manager: subreddit_manager_subject,
      post_manager: post_manager_subject,
      comment_manager: comment_manager_subject,
      dm_manager: dm_manager_subject,
      feed_generator: feed_generator_subject,
    )

  // Create HTTP request handler function for mist
  let handler = fn(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
    router.handle_request(req, context)
  }

  // Start HTTP server
  io.println("┌─ Starting HTTP Server ──────────────────────────────────────┐")
  let assert Ok(_) =
    mist.new(handler)
    |> mist.port(3000)
    |> mist.start

  io.println("│   ✓ HTTP Server running on http://localhost:3000            │")
  io.println("│   ✓ Ready to accept client connections                      │")
  io.println("└─────────────────────────────────────────────────────────────┘")
  io.println("")
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║          SERVER STARTED SUCCESSFULLY! ✓                      ║")
  io.println("║                                                              ║")
  io.println("║  Try: curl http://localhost:3000/health                      ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")

  // Keep server running forever
  process.sleep_forever()
}
