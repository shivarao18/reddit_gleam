// API Router - Routes HTTP requests to appropriate handlers
// This module provides the main routing logic for the REST API

import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import mist
import reddit/api/handlers/auth
import reddit/api/handlers/comment
import reddit/api/handlers/dm
import reddit/api/handlers/feed
import reddit/api/handlers/post
import reddit/api/handlers/subreddit
import reddit/api/types
import reddit/server_context.{type ServerContext}

/// Main request handler - routes requests to appropriate handlers
pub fn handle_request(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  // Log the request
  io.println(
    "Request: " <> http.method_to_string(req.method) <> " " <> req.path,
  )

  // Parse path segments
  let path_segments =
    req.path
    |> string.split("/")
    |> list.filter(fn(seg) { seg != "" })

  // Route based on path and method
  case path_segments {
    // Health check
    ["health"] -> health_check(req)

    // API info
    [] -> api_info(req)

    // Authentication endpoints
    ["api", "auth", "register"] -> auth.register(req, ctx)
    ["api", "auth", "user", username] -> auth.get_user(req, ctx, username)

    // Subreddit endpoints
    ["api", "subreddits", "create"] -> subreddit.create(req, ctx)
    ["api", "subreddits"] -> subreddit.list_all(req, ctx)
    ["api", "subreddits", subreddit_id, "join"] ->
      subreddit.join(req, ctx, subreddit_id)
    ["api", "subreddits", subreddit_id, "leave"] ->
      subreddit.leave(req, ctx, subreddit_id)

    // Post endpoints
    ["api", "posts", "create"] -> post.create(req, ctx)
    ["api", "posts", post_id] -> post.get(req, ctx, post_id)
    ["api", "posts", post_id, "vote"] -> post.vote(req, ctx, post_id)
    ["api", "posts", post_id, "repost"] -> post.repost(req, ctx, post_id)
    ["api", "posts", post_id, "comments"] ->
      comment.get_by_post(req, ctx, post_id)

    // Comment endpoints
    ["api", "comments", "create"] -> comment.create(req, ctx)
    ["api", "comments", comment_id, "vote"] ->
      comment.vote(req, ctx, comment_id)

    // Feed endpoints
    ["api", "feed", user_id] -> feed.get_feed(req, ctx, user_id)

    // Direct Message endpoints
    ["api", "dm", "send"] -> dm.send_dm(req, ctx)
    ["api", "dm", "user", user_id] -> dm.get_user_dms(req, ctx, user_id)
    ["api", "dm", "conversation", user1_id, user2_id] ->
      dm.get_conversation(req, ctx, user1_id, user2_id)

    // 404 for unknown routes
    _ -> not_found()
  }
}

/// Health check endpoint
fn health_check(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
  case req.method {
    http.Get -> {
      types.success_response(
        json.object([
          #("status", json.string("healthy")),
          #("message", json.string("Reddit Clone API Server is running")),
        ]),
      )
    }
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

/// API info endpoint
fn api_info(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
  case req.method {
    http.Get -> {
      types.success_response(
        json.object([
          #("name", json.string("Reddit Clone REST API")),
          #("version", json.string("2.0")),
          #("description", json.string("Part II - REST API Server")),
          #(
            "endpoints",
            json.object([
              #("health", json.string("GET /health")),
              #("info", json.string("GET /")),
              #(
                "auth",
                json.object([
                  #("register", json.string("POST /api/auth/register")),
                  #("get_user", json.string("GET /api/auth/user/:username")),
                ]),
              ),
              #(
                "subreddits",
                json.object([
                  #("create", json.string("POST /api/subreddits/create")),
                  #("list_all", json.string("GET /api/subreddits")),
                  #("join", json.string("POST /api/subreddits/:id/join")),
                  #("leave", json.string("POST /api/subreddits/:id/leave")),
                ]),
              ),
              #(
                "posts",
                json.object([
                  #("create", json.string("POST /api/posts/create")),
                  #("get", json.string("GET /api/posts/:id")),
                  #("vote", json.string("POST /api/posts/:id/vote")),
                  #("repost", json.string("POST /api/posts/:id/repost")),
                  #("comments", json.string("GET /api/posts/:id/comments")),
                ]),
              ),
              #(
                "comments",
                json.object([
                  #("create", json.string("POST /api/comments/create")),
                  #("vote", json.string("POST /api/comments/:id/vote")),
                ]),
              ),
              #(
                "feed",
                json.object([
                  #("get_feed", json.string("GET /api/feed/:user_id")),
                ]),
              ),
            ]),
          ),
          #(
            "status",
            json.string("Phase 3 Complete - All core endpoints implemented"),
          ),
        ]),
      )
    }
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

/// 404 Not Found response
fn not_found() -> Response(mist.ResponseData) {
  types.not_found("The requested endpoint does not exist")
}
