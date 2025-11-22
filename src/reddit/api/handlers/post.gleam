// Post Handlers - Create and manage posts
// This module handles post-related endpoints

import gleam/bit_array
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/otp/actor
import mist
import reddit/api/types
import reddit/protocol
import reddit/server_context.{type ServerContext}
import reddit/types as reddit_types

/// Create a new post
/// POST /api/posts/create
/// Body: { "subreddit_id": "sub_1", "author_id": "user_1", "title": "Hello", "content": "World" }
pub fn create(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> create_post(req, ctx)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn create_post(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          case
            types.extract_json_string_field(body_str, "subreddit_id"),
            types.extract_json_string_field(body_str, "author_id"),
            types.extract_json_string_field(body_str, "title"),
            types.extract_json_string_field(body_str, "content")
          {
            Ok(subreddit_id), Ok(author_id), Ok(title), Ok(content) -> {
              let result =
                actor.call(
                  ctx.post_manager,
                  waiting: 5000,
                  sending: protocol.CreatePost(
                    subreddit_id,
                    author_id,
                    title,
                    content,
                    _,
                  ),
                )

              case result {
                reddit_types.PostSuccess(post) -> {
                  types.created(
                    json.object([
                      #("post_id", json.string(post.id)),
                      #("title", json.string(post.title)),
                      #("content", json.string(post.content)),
                      #("author_id", json.string(post.author_id)),
                      #("subreddit_id", json.string(post.subreddit_id)),
                      #("upvotes", json.int(post.upvotes)),
                      #("downvotes", json.int(post.downvotes)),
                      #("created_at", json.int(post.created_at)),
                    ]),
                  )
                }

                reddit_types.PostError(reason) -> types.bad_request(reason)
                _ -> types.internal_error("Unexpected error")
              }
            }

            _, _, _, _ ->
              types.bad_request(
                "Missing required fields: subreddit_id, author_id, title, content",
              )
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}

/// Get a post by ID
/// GET /api/posts/:id
pub fn get(
  req: Request(mist.Connection),
  ctx: ServerContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> get_post(ctx, post_id)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn get_post(ctx: ServerContext, post_id: String) -> Response(mist.ResponseData) {
  let result =
    actor.call(ctx.post_manager, waiting: 5000, sending: protocol.GetPost(
      post_id,
      _,
    ))

  case result {
    reddit_types.PostSuccess(post) -> {
      types.success_response(
        json.object([
          #("post_id", json.string(post.id)),
          #("title", json.string(post.title)),
          #("content", json.string(post.content)),
          #("author_id", json.string(post.author_id)),
          #("subreddit_id", json.string(post.subreddit_id)),
          #("upvotes", json.int(post.upvotes)),
          #("downvotes", json.int(post.downvotes)),
          #("is_repost", json.bool(post.is_repost)),
          #("created_at", json.int(post.created_at)),
        ]),
      )
    }

    reddit_types.PostNotFound -> types.not_found("Post not found")
    reddit_types.PostError(reason) -> types.internal_error(reason)
  }
}

/// Vote on a post
/// POST /api/posts/:id/vote
/// Body: { "user_id": "user_1", "vote_type": "upvote" }
pub fn vote(
  req: Request(mist.Connection),
  ctx: ServerContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> vote_on_post(req, ctx, post_id)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn vote_on_post(
  req: Request(mist.Connection),
  ctx: ServerContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          case
            types.extract_json_string_field(body_str, "user_id"),
            types.extract_json_string_field(body_str, "vote_type")
          {
            Ok(user_id), Ok(vote_type_str) -> {
              let vote_type = case vote_type_str {
                "upvote" -> reddit_types.Upvote
                "downvote" -> reddit_types.Downvote
                _ -> reddit_types.Upvote
              }

              let result =
                actor.call(
                  ctx.post_manager,
                  waiting: 5000,
                  sending: protocol.VotePost(post_id, user_id, vote_type, _),
                )

              case result {
                Ok(_) -> {
                  types.success_response(
                    json.object([
                      #("message", json.string("Vote recorded successfully")),
                    ]),
                  )
                }

                Error(reason) -> types.bad_request(reason)
              }
            }

            _, _ ->
              types.bad_request("Missing required fields: user_id, vote_type")
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}

/// Create a repost
/// POST /api/posts/:id/repost
/// Body: { "author_id": "user_2", "subreddit_id": "sub_2" }
pub fn repost(
  req: Request(mist.Connection),
  ctx: ServerContext,
  original_post_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> create_repost(req, ctx, original_post_id)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn create_repost(
  req: Request(mist.Connection),
  ctx: ServerContext,
  original_post_id: String,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          case
            types.extract_json_string_field(body_str, "author_id"),
            types.extract_json_string_field(body_str, "subreddit_id")
          {
            Ok(author_id), Ok(subreddit_id) -> {
              let result =
                actor.call(
                  ctx.post_manager,
                  waiting: 5000,
                  sending: protocol.CreateRepost(
                    original_post_id,
                    author_id,
                    subreddit_id,
                    _,
                  ),
                )

              case result {
                reddit_types.PostSuccess(post) -> {
                  types.created(
                    json.object([
                      #("post_id", json.string(post.id)),
                      #("title", json.string(post.title)),
                      #("is_repost", json.bool(True)),
                      #("author_id", json.string(post.author_id)),
                      #("subreddit_id", json.string(post.subreddit_id)),
                      #("created_at", json.int(post.created_at)),
                    ]),
                  )
                }

                reddit_types.PostError(reason) -> types.bad_request(reason)
                _ -> types.internal_error("Unexpected error")
              }
            }

            _, _ ->
              types.bad_request(
                "Missing required fields: author_id, subreddit_id",
              )
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}
