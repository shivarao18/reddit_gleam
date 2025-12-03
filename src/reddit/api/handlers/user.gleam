// User Handlers - User-related endpoints including public key retrieval
// This module handles endpoints for retrieving user information and public keys

import gleam/http.{Get}
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

/// GET /api/users/:id/public-key
/// Retrieves the public key for a specific user
pub fn get_public_key(
  req: Request(mist.Connection),
  ctx: ServerContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> retrieve_public_key(ctx, user_id)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn retrieve_public_key(
  ctx: ServerContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  // Get user from registry
  let result =
    actor.call(ctx.user_registry, waiting: 5000, sending: protocol.GetUser(
      user_id,
      _,
    ))

  case result {
    reddit_types.UserSuccess(user) -> {
      // Return public key if available
      case user.public_key {
        option.Some(public_key) -> {
          types.success_response(
            json.object([
              #("user_id", json.string(user.id)),
              #("username", json.string(user.username)),
              #("public_key", types.public_key_to_json(public_key)),
            ]),
          )
        }

        option.None -> {
          types.not_found("User does not have a public key")
        }
      }
    }

    reddit_types.UserNotFound -> {
      types.not_found("User not found")
    }

    reddit_types.UserError(reason) -> {
      types.internal_error(reason)
    }
  }
}
