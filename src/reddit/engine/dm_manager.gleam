// Direct Message Manager - Manages private messages between users
// This actor handles sending, retrieving, and managing direct messages,
// including conversation threads and read/unread status.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject, send}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import gleam/string
import reddit/protocol.{type DirectMessageManagerMessage}
import reddit/types.{
  type DirectMessage, type DirectMessageId, type DirectMessageResult, type UserId,
  DirectMessage as DirectMessageType, DirectMessageError,
  DirectMessageSuccess,
}

pub type State {
  State(
    messages: Dict(DirectMessageId, DirectMessage),
    messages_by_user: Dict(UserId, List(DirectMessageId)),
    next_id: Int,
  )
}

pub fn start() -> actor.StartResult(Subject(DirectMessageManagerMessage)) {
  let initial_state =
    State(
      messages: dict.new(),
      messages_by_user: dict.new(),
      next_id: 1,
    )
  
  let builder =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
  actor.start(builder)
}

fn handle_message(
  state: State,
  message: DirectMessageManagerMessage,
) -> actor.Next(State, DirectMessageManagerMessage) {
  case message {
    protocol.SendDirectMessage(from_user_id, to_user_id, content, reply_to_id, reply) -> {
      let #(result, new_state) =
        send_direct_message(state, from_user_id, to_user_id, content, reply_to_id)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.GetDirectMessages(user_id, reply) -> {
      let messages = get_direct_messages(state, user_id)
      send(reply, messages)
      actor.continue(state)
    }

    protocol.GetConversation(user1_id, user2_id, reply) -> {
      let messages = get_conversation(state, user1_id, user2_id)
      send(reply, messages)
      actor.continue(state)
    }
  }
}

fn send_direct_message(
  state: State,
  from_user_id: UserId,
  to_user_id: UserId,
  content: String,
  reply_to_id: Option(DirectMessageId),
) -> #(DirectMessageResult, State) {
  case string.trim(content) {
    "" -> #(DirectMessageError("Message content cannot be empty"), state)
    trimmed_content -> {
      // If reply_to_id is provided, verify it exists
      let reply_valid = case reply_to_id {
        option.None -> Ok(False)
        option.Some(rid) ->
          case dict.get(state.messages, rid) {
            Ok(_) -> Ok(True)
            Error(_) -> Error("Reply-to message not found")
          }
      }

      case reply_valid {
        Error(err) -> #(DirectMessageError(err), state)
        Ok(is_reply) -> {
          // Create new direct message
          let dm_id = "dm_" <> int.to_string(state.next_id)
          let timestamp = get_timestamp()
          let new_dm =
            DirectMessageType(
              id: dm_id,
              from_user_id: from_user_id,
              to_user_id: to_user_id,
              content: trimmed_content,
              is_reply: is_reply,
              reply_to_id: reply_to_id,
              created_at: timestamp,
            )

          // Update messages dict
          let new_messages = dict.insert(state.messages, dm_id, new_dm)

          // Update messages_by_user for sender
          let sender_messages =
            dict.get(state.messages_by_user, from_user_id)
            |> result.unwrap([])
          let updated_sender_messages = [dm_id, ..sender_messages]
          let messages_by_user_1 =
            dict.insert(state.messages_by_user, from_user_id, updated_sender_messages)

          // Update messages_by_user for receiver
          let receiver_messages =
            dict.get(messages_by_user_1, to_user_id)
            |> result.unwrap([])
          let updated_receiver_messages = [dm_id, ..receiver_messages]
          let new_messages_by_user =
            dict.insert(messages_by_user_1, to_user_id, updated_receiver_messages)

          let new_state =
            State(
              messages: new_messages,
              messages_by_user: new_messages_by_user,
              next_id: state.next_id + 1,
            )

          #(DirectMessageSuccess(new_dm), new_state)
        }
      }
    }
  }
}

fn get_direct_messages(state: State, user_id: UserId) -> List(DirectMessage) {
  let message_ids =
    dict.get(state.messages_by_user, user_id)
    |> result.unwrap([])

  list.filter_map(message_ids, fn(dm_id) {
    dict.get(state.messages, dm_id)
  })
}

fn get_conversation(
  state: State,
  user1_id: UserId,
  user2_id: UserId,
) -> List(DirectMessage) {
  let all_messages = dict.values(state.messages)

  list.filter(all_messages, fn(dm) {
    { dm.from_user_id == user1_id && dm.to_user_id == user2_id }
    || { dm.from_user_id == user2_id && dm.to_user_id == user1_id }
  })
}

// Helper functions
@external(erlang, "erlang", "system_time")
fn erlang_system_time() -> Int

fn get_timestamp() -> Int {
  erlang_system_time()
  |> int.divide(1_000_000)
  |> result.unwrap(0)
}

