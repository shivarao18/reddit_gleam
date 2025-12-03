// Authentication Handlers - User registration and login
// This module handles user authentication endpoints

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

/// Handle user registration
/// POST /api/auth/register
/// Body: { "username": "alice" }
pub fn register(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> register_user(req, ctx)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn register_user(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  // Read request body
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          // Extract username from JSON
          case types.extract_json_string_field(body_str, "username") {
            Ok(username) -> {
              // Parse optional public key from JSON
              let public_key =
                types.parse_optional_public_key_from_json(body_str)

              // Call engine actor to register user with optional public key
              let result =
                actor.call(
                  ctx.user_registry,
                  waiting: 5000,
                  sending: protocol.RegisterUser(username, public_key, _),
                )

              // Convert result to HTTP response
              case result {
                reddit_types.RegistrationSuccess(user) -> {
                  types.created(
                    json.object([
                      #("user_id", json.string(user.id)),
                      #("username", json.string(user.username)),
                      #("karma", json.int(user.karma)),
                      #("created_at", json.int(user.created_at)),
                      #(
                        "public_key",
                        types.optional_public_key_to_json(user.public_key),
                      ),
                      #("key_algorithm", case user.key_algorithm {
                        option.Some(alg) ->
                          json.string(types.key_algorithm_to_string(alg))
                        option.None -> json.null()
                      }),
                    ]),
                  )
                }

                reddit_types.UsernameTaken -> {
                  types.conflict("Username is already taken")
                }

                reddit_types.RegistrationError(reason) -> {
                  types.bad_request(reason)
                }
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

/// Handle user info lookup (simple login alternative)
/// GET /api/auth/user/:username
pub fn get_user(
  req: Request(mist.Connection),
  ctx: ServerContext,
  username: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> lookup_user(ctx, username)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn lookup_user(
  ctx: ServerContext,
  username: String,
) -> Response(mist.ResponseData) {
  // Call engine actor to get user
  let result =
    actor.call(
      ctx.user_registry,
      waiting: 5000,
      sending: protocol.GetUserByUsername(username, _),
    )

  case result {
    reddit_types.UserSuccess(user) -> {
      types.success_response(
        json.object([
          #("user_id", json.string(user.id)),
          #("username", json.string(user.username)),
          #("karma", json.int(user.karma)),
          #(
            "joined_subreddits",
            json.array(user.joined_subreddits, json.string),
          ),
          #("is_online", json.bool(user.is_online)),
          #("created_at", json.int(user.created_at)),
        ]),
      )
    }

    reddit_types.UserNotFound -> {
      types.not_found("User not found")
    }

    reddit_types.UserError(reason) -> {
      types.internal_error(reason)
    }
  }
}
