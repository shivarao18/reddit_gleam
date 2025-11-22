// Subreddit Handlers - Create and manage subreddits
// This module handles subreddit-related endpoints

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

/// Create a new subreddit
/// POST /api/subreddits/create
/// Body: { "name": "programming", "description": "All about programming" }
pub fn create(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> create_subreddit(req, ctx)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn create_subreddit(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          // Extract fields
          case
            types.extract_json_string_field(body_str, "name"),
            types.extract_json_string_field(body_str, "description"),
            types.extract_json_string_field(body_str, "creator_id")
          {
            Ok(name), Ok(description), Ok(creator_id) -> {
              // Call engine actor
              let result =
                actor.call(
                  ctx.subreddit_manager,
                  waiting: 5000,
                  sending: protocol.CreateSubreddit(
                    name,
                    description,
                    creator_id,
                    _,
                  ),
                )

              case result {
                reddit_types.SubredditSuccess(subreddit) -> {
                  types.created(
                    json.object([
                      #("subreddit_id", json.string(subreddit.id)),
                      #("name", json.string(subreddit.name)),
                      #("description", json.string(subreddit.description)),
                      #("creator_id", json.string(subreddit.creator_id)),
                      #("member_count", json.int(subreddit.member_count)),
                      #("created_at", json.int(subreddit.created_at)),
                    ]),
                  )
                }

                reddit_types.SubredditAlreadyExists -> {
                  types.conflict("Subreddit name already exists")
                }

                reddit_types.SubredditError(reason) -> {
                  types.bad_request(reason)
                }

                _ -> types.internal_error("Unexpected error")
              }
            }

            _, _, _ ->
              types.bad_request(
                "Missing required fields: name, description, creator_id",
              )
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}

/// List all subreddits
/// GET /api/subreddits
pub fn list_all(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> get_all_subreddits(ctx)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn get_all_subreddits(ctx: ServerContext) -> Response(mist.ResponseData) {
  let subreddits =
    actor.call(
      ctx.subreddit_manager,
      waiting: 5000,
      sending: protocol.ListAllSubreddits,
    )

  let subreddits_json =
    json.array(subreddits, fn(sub) {
      json.object([
        #("subreddit_id", json.string(sub.id)),
        #("name", json.string(sub.name)),
        #("description", json.string(sub.description)),
        #("member_count", json.int(sub.member_count)),
        #("created_at", json.int(sub.created_at)),
      ])
    })

  types.success_response(subreddits_json)
}

/// Join a subreddit
/// POST /api/subreddits/:id/join
/// Body: { "user_id": "user_1" }
pub fn join(
  req: Request(mist.Connection),
  ctx: ServerContext,
  subreddit_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> join_subreddit(req, ctx, subreddit_id)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn join_subreddit(
  req: Request(mist.Connection),
  ctx: ServerContext,
  subreddit_id: String,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          case types.extract_json_string_field(body_str, "user_id") {
            Ok(user_id) -> {
              // Call engine actors to join subreddit
              let result =
                actor.call(
                  ctx.subreddit_manager,
                  waiting: 5000,
                  sending: protocol.JoinSubreddit(subreddit_id, user_id, _),
                )

              case result {
                Ok(_) -> {
                  // Also update user registry
                  let _ =
                    actor.call(
                      ctx.user_registry,
                      waiting: 5000,
                      sending: protocol.AddSubredditToUser(
                        user_id,
                        subreddit_id,
                        _,
                      ),
                    )

                  types.success_response(
                    json.object([
                      #("message", json.string("Successfully joined subreddit")),
                    ]),
                  )
                }

                Error(reason) -> types.bad_request(reason)
              }
            }

            Error(err) -> types.bad_request(err)
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}

/// Leave a subreddit
/// POST /api/subreddits/:id/leave
/// Body: { "user_id": "user_1" }
pub fn leave(
  req: Request(mist.Connection),
  ctx: ServerContext,
  subreddit_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> leave_subreddit(req, ctx, subreddit_id)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn leave_subreddit(
  req: Request(mist.Connection),
  ctx: ServerContext,
  subreddit_id: String,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          case types.extract_json_string_field(body_str, "user_id") {
            Ok(user_id) -> {
              // Call engine actors to leave subreddit
              let result =
                actor.call(
                  ctx.subreddit_manager,
                  waiting: 5000,
                  sending: protocol.LeaveSubreddit(subreddit_id, user_id, _),
                )

              case result {
                Ok(_) -> {
                  // Also update user registry
                  let _ =
                    actor.call(
                      ctx.user_registry,
                      waiting: 5000,
                      sending: protocol.RemoveSubredditFromUser(
                        user_id,
                        subreddit_id,
                        _,
                      ),
                    )

                  types.success_response(
                    json.object([
                      #("message", json.string("Successfully left subreddit")),
                    ]),
                  )
                }

                Error(reason) -> types.bad_request(reason)
              }
            }

            Error(err) -> types.bad_request(err)
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}
