// Comment Handlers - Create and manage comments
// This module handles comment-related endpoints

import gleam/bit_array
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option
import gleam/otp/actor
import mist
import reddit/api/types
import reddit/protocol
import reddit/server_context.{type ServerContext}
import reddit/types as reddit_types

/// Create a new comment
/// POST /api/comments/create
/// Body: { "post_id": "post_1", "author_id": "user_1", "content": "Great post!", "parent_id": null }
pub fn create(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> create_comment(req, ctx)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn create_comment(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          case
            types.extract_json_string_field(body_str, "post_id"),
            types.extract_json_string_field(body_str, "author_id"),
            types.extract_json_string_field(body_str, "content")
          {
            Ok(post_id), Ok(author_id), Ok(content) -> {
              // Parent ID is optional
              let parent_id = case
                types.extract_json_string_field(body_str, "parent_id")
              {
                Ok("") -> option.None
                Ok(id) -> option.Some(id)
                Error(_) -> option.None
              }

              let result =
                actor.call(
                  ctx.comment_manager,
                  waiting: 5000,
                  sending: protocol.CreateComment(
                    post_id,
                    author_id,
                    content,
                    parent_id,
                    _,
                  ),
                )

              case result {
                reddit_types.CommentSuccess(comment) -> {
                  types.created(
                    json.object([
                      #("comment_id", json.string(comment.id)),
                      #("post_id", json.string(comment.post_id)),
                      #("author_id", json.string(comment.author_id)),
                      #("content", json.string(comment.content)),
                      #("upvotes", json.int(comment.upvotes)),
                      #("downvotes", json.int(comment.downvotes)),
                      #("created_at", json.int(comment.created_at)),
                    ]),
                  )
                }

                reddit_types.CommentError(reason) -> types.bad_request(reason)
                _ -> types.internal_error("Unexpected error")
              }
            }

            _, _, _ ->
              types.bad_request(
                "Missing required fields: post_id, author_id, content",
              )
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}

/// Get all comments for a post
/// GET /api/posts/:id/comments
pub fn get_by_post(
  req: Request(mist.Connection),
  ctx: ServerContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> get_post_comments(ctx, post_id)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn get_post_comments(
  ctx: ServerContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  let comments =
    actor.call(
      ctx.comment_manager,
      waiting: 5000,
      sending: protocol.GetCommentsByPost(post_id, _),
    )

  let comments_json =
    json.array(comments, fn(comment) {
      json.object([
        #("comment_id", json.string(comment.id)),
        #("post_id", json.string(comment.post_id)),
        #("author_id", json.string(comment.author_id)),
        #("content", json.string(comment.content)),
        #("upvotes", json.int(comment.upvotes)),
        #("downvotes", json.int(comment.downvotes)),
        #("parent_id", case comment.parent_id {
          option.Some(id) -> json.string(id)
          option.None -> json.null()
        }),
        #("created_at", json.int(comment.created_at)),
      ])
    })

  types.success_response(comments_json)
}

/// Vote on a comment
/// POST /api/comments/:id/vote
/// Body: { "user_id": "user_1", "vote_type": "upvote" }
pub fn vote(
  req: Request(mist.Connection),
  ctx: ServerContext,
  comment_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> vote_on_comment(req, ctx, comment_id)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn vote_on_comment(
  req: Request(mist.Connection),
  ctx: ServerContext,
  comment_id: String,
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
                  ctx.comment_manager,
                  waiting: 5000,
                  sending: protocol.VoteComment(
                    comment_id,
                    user_id,
                    vote_type,
                    _,
                  ),
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
