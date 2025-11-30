// Direct Message Handlers - Send and retrieve private messages
// This module handles DM-related endpoints

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

/// Send a direct message
/// POST /api/dm/send
/// Body: { "from_user_id": "user_1", "to_user_id": "user_2", "content": "Hello!" }
pub fn send_dm(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case req.method {
    Post -> handle_send_dm(req, ctx)
    _ -> types.error_response("MethodNotAllowed", "Only POST allowed", 405)
  }
}

fn handle_send_dm(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(request.Request(body: body, ..)) -> {
      case bit_array.to_string(body) {
        Ok(body_str) -> {
          case
            types.extract_json_string_field(body_str, "from_user_id"),
            types.extract_json_string_field(body_str, "to_user_id"),
            types.extract_json_string_field(body_str, "content")
          {
            Ok(from_user_id), Ok(to_user_id), Ok(content) -> {
              // Call DM manager actor
              let result =
                actor.call(
                  ctx.dm_manager,
                  waiting: 5000,
                  sending: protocol.SendDirectMessage(
                    from_user_id,
                    to_user_id,
                    content,
                    option.None,
                    _,
                  ),
                )

              case result {
                reddit_types.DirectMessageSuccess(dm) -> {
                  let response_json =
                    json.object([
                      #("success", json.bool(True)),
                      #(
                        "data",
                        json.object([
                          #("message_id", json.string(dm.id)),
                          #("from_user_id", json.string(dm.from_user_id)),
                          #("to_user_id", json.string(dm.to_user_id)),
                          #("content", json.string(dm.content)),
                          #("timestamp", json.int(dm.created_at)),
                        ]),
                      ),
                    ])
                  types.success_response(response_json)
                }

                reddit_types.DirectMessageNotFound -> {
                  types.error_response(
                    "DirectMessageNotFound",
                    "Message not found",
                    404,
                  )
                }

                reddit_types.DirectMessageError(reason) -> {
                  types.error_response("DirectMessageError", reason, 400)
                }
              }
            }

            _, _, _ ->
              types.bad_request(
                "Missing required fields: from_user_id, to_user_id, content",
              )
          }
        }

        Error(_) -> types.bad_request("Invalid UTF-8 in request body")
      }
    }

    Error(_) -> types.internal_error("Failed to read request body")
  }
}

/// Get all direct messages for a user
/// GET /api/dm/user/:user_id
pub fn get_user_dms(
  req: Request(mist.Connection),
  ctx: ServerContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> handle_get_user_dms(ctx, user_id)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn handle_get_user_dms(
  ctx: ServerContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  let messages =
    actor.call(
      ctx.dm_manager,
      waiting: 5000,
      sending: protocol.GetDirectMessages(user_id, _),
    )

  let messages_json =
    json.array(messages, fn(dm) {
      json.object([
        #("message_id", json.string(dm.id)),
        #("from_user_id", json.string(dm.from_user_id)),
        #("to_user_id", json.string(dm.to_user_id)),
        #("content", json.string(dm.content)),
        #("timestamp", json.int(dm.created_at)),
      ])
    })

  types.success_response(messages_json)
}

/// Get conversation between two users
/// GET /api/dm/conversation/:user1_id/:user2_id
pub fn get_conversation(
  req: Request(mist.Connection),
  ctx: ServerContext,
  user1_id: String,
  user2_id: String,
) -> Response(mist.ResponseData) {
  case req.method {
    Get -> handle_get_conversation(ctx, user1_id, user2_id)
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

fn handle_get_conversation(
  ctx: ServerContext,
  user1_id: String,
  user2_id: String,
) -> Response(mist.ResponseData) {
  let messages =
    actor.call(ctx.dm_manager, waiting: 5000, sending: protocol.GetConversation(
      user1_id,
      user2_id,
      _,
    ))

  let messages_json =
    json.array(messages, fn(dm) {
      json.object([
        #("message_id", json.string(dm.id)),
        #("from_user_id", json.string(dm.from_user_id)),
        #("to_user_id", json.string(dm.to_user_id)),
        #("content", json.string(dm.content)),
        #("timestamp", json.int(dm.created_at)),
      ])
    })

  types.success_response(messages_json)
}
