// Feed Handlers - Get personalized feed
// This module handles feed-related endpoints

import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/otp/actor
import mist
import reddit/api/types
import reddit/protocol
import reddit/server_context.{type ServerContext}

/// Get personalized feed for a user
/// GET /api/feed?user_id=user_1&limit=20
pub fn get_feed(
  req: Request(mist.Connection),
  ctx: ServerContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> fetch_feed(ctx, user_id)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn fetch_feed(
  ctx: ServerContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  let feed_posts =
    actor.call(ctx.feed_generator, waiting: 5000, sending: protocol.GetFeed(
      user_id,
      20,
      _,
    ))

  let feed_json =
    json.array(feed_posts, fn(feed_post) {
      json.object([
        #(
          "post",
          json.object([
            #("post_id", json.string(feed_post.post.id)),
            #("title", json.string(feed_post.post.title)),
            #("content", json.string(feed_post.post.content)),
            #("author_id", json.string(feed_post.post.author_id)),
            #("subreddit_id", json.string(feed_post.post.subreddit_id)),
            #("upvotes", json.int(feed_post.post.upvotes)),
            #("downvotes", json.int(feed_post.post.downvotes)),
            #("is_repost", json.bool(feed_post.post.is_repost)),
            #("created_at", json.int(feed_post.post.created_at)),
          ]),
        ),
        #("subreddit_name", json.string(feed_post.subreddit_name)),
        #("author_username", json.string(feed_post.author_username)),
        #("score", json.int(feed_post.score)),
      ])
    })

  types.success_response(feed_json)
}
