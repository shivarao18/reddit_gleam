// User Registry - Manages user accounts and authentication
// This actor handles user registration, retrieval, and maintains a registry
// of all users in the system with unique IDs and usernames.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject, send}
import gleam/int
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import reddit/crypto/types as crypto_types
import reddit/protocol.{type UserRegistryMessage}
import reddit/types.{
  type RegistrationResult, type User, type UserId, type UserResult,
  RegistrationError, RegistrationSuccess, User as UserType, UserNotFound,
  UserSuccess, UsernameTaken,
}

pub type State {
  State(
    users: Dict(UserId, User),
    username_to_id: Dict(String, UserId),
    next_id: Int,
  )
}

pub fn start() -> actor.StartResult(Subject(UserRegistryMessage)) {
  let initial_state =
    State(users: dict.new(), username_to_id: dict.new(), next_id: 1)

  let builder =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
  actor.start(builder)
}

fn handle_message(
  state: State,
  message: UserRegistryMessage,
) -> actor.Next(State, UserRegistryMessage) {
  case message {
    protocol.RegisterUser(username, public_key, reply) -> {
      let #(result, new_state) = register_user(state, username, public_key)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.GetUser(user_id, reply) -> {
      let result = get_user(state, user_id)
      send(reply, result)
      actor.continue(state)
    }

    protocol.GetUserByUsername(username, reply) -> {
      let result = get_user_by_username(state, username)
      send(reply, result)
      actor.continue(state)
    }

    protocol.UpdateUserOnlineStatus(user_id, is_online, reply) -> {
      let #(result, new_state) =
        update_user_online_status(state, user_id, is_online)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.AddSubredditToUser(user_id, subreddit_id, reply) -> {
      let #(result, new_state) =
        add_subreddit_to_user(state, user_id, subreddit_id)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.RemoveSubredditFromUser(user_id, subreddit_id, reply) -> {
      let #(result, new_state) =
        remove_subreddit_from_user(state, user_id, subreddit_id)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.UpdateUserKarma(user_id, karma_delta, reply) -> {
      let #(result, new_state) = update_user_karma(state, user_id, karma_delta)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.UpdateUserKarmaAsync(user_id, karma_delta) -> {
      let #(_result, new_state) = update_user_karma(state, user_id, karma_delta)
      actor.continue(new_state)
    }
  }
}

fn register_user(
  state: State,
  username: String,
  public_key: option.Option(crypto_types.PublicKey),
) -> #(RegistrationResult, State) {
  // Validate username
  case string.trim(username) {
    "" -> #(RegistrationError("Username cannot be empty"), state)
    trimmed_username -> {
      // Check if username already exists
      case dict.get(state.username_to_id, trimmed_username) {
        Ok(_) -> #(UsernameTaken, state)
        Error(_) -> {
          // Create new user
          let user_id = "user_" <> int.to_string(state.next_id)
          let timestamp = get_timestamp()

          // Extract key_algorithm from public_key if provided
          let key_algorithm = case public_key {
            option.Some(pk) -> option.Some(pk.algorithm)
            option.None -> option.None
          }

          let new_user =
            UserType(
              id: user_id,
              username: trimmed_username,
              karma: 0,
              joined_subreddits: [],
              is_online: True,
              created_at: timestamp,
              public_key: public_key,
              key_algorithm: key_algorithm,
            )

          // Update state
          let new_users = dict.insert(state.users, user_id, new_user)
          let new_username_map =
            dict.insert(state.username_to_id, trimmed_username, user_id)
          let new_state =
            State(
              users: new_users,
              username_to_id: new_username_map,
              next_id: state.next_id + 1,
            )

          #(RegistrationSuccess(new_user), new_state)
        }
      }
    }
  }
}

fn get_user(state: State, user_id: UserId) -> UserResult {
  case dict.get(state.users, user_id) {
    Ok(user) -> UserSuccess(user)
    Error(_) -> UserNotFound
  }
}

fn get_user_by_username(state: State, username: String) -> UserResult {
  case dict.get(state.username_to_id, username) {
    Ok(user_id) -> get_user(state, user_id)
    Error(_) -> UserNotFound
  }
}

fn update_user_online_status(
  state: State,
  user_id: UserId,
  is_online: Bool,
) -> #(Result(Nil, String), State) {
  case dict.get(state.users, user_id) {
    Ok(user) -> {
      let updated_user = UserType(..user, is_online: is_online)
      let new_users = dict.insert(state.users, user_id, updated_user)
      let new_state = State(..state, users: new_users)
      #(Ok(Nil), new_state)
    }
    Error(_) -> #(Error("User not found"), state)
  }
}

fn add_subreddit_to_user(
  state: State,
  user_id: UserId,
  subreddit_id: String,
) -> #(Result(Nil, String), State) {
  case dict.get(state.users, user_id) {
    Ok(user) -> {
      // Check if already joined
      case list_contains(user.joined_subreddits, subreddit_id) {
        True -> #(Error("Already joined this subreddit"), state)
        False -> {
          let updated_subreddits = [subreddit_id, ..user.joined_subreddits]
          let updated_user =
            UserType(..user, joined_subreddits: updated_subreddits)
          let new_users = dict.insert(state.users, user_id, updated_user)
          let new_state = State(..state, users: new_users)
          #(Ok(Nil), new_state)
        }
      }
    }
    Error(_) -> #(Error("User not found"), state)
  }
}

fn remove_subreddit_from_user(
  state: State,
  user_id: UserId,
  subreddit_id: String,
) -> #(Result(Nil, String), State) {
  case dict.get(state.users, user_id) {
    Ok(user) -> {
      let updated_subreddits = list_filter(user.joined_subreddits, subreddit_id)
      let updated_user = UserType(..user, joined_subreddits: updated_subreddits)
      let new_users = dict.insert(state.users, user_id, updated_user)
      let new_state = State(..state, users: new_users)
      #(Ok(Nil), new_state)
    }
    Error(_) -> #(Error("User not found"), state)
  }
}

fn update_user_karma(
  state: State,
  user_id: UserId,
  karma_delta: Int,
) -> #(Result(Nil, String), State) {
  case dict.get(state.users, user_id) {
    Ok(user) -> {
      let new_karma = user.karma + karma_delta
      let updated_user = UserType(..user, karma: new_karma)
      let new_users = dict.insert(state.users, user_id, updated_user)
      let new_state = State(..state, users: new_users)
      #(Ok(Nil), new_state)
    }
    Error(_) -> #(Error("User not found"), state)
  }
}

// Helper functions
@external(erlang, "erlang", "system_time")
fn erlang_system_time() -> Int

fn get_timestamp() -> Int {
  erlang_system_time()
  |> int.divide(1_000_000)
  |> result.unwrap(0)
}

fn list_contains(list: List(a), item: a) -> Bool {
  case list {
    [] -> False
    [first, ..rest] ->
      case first == item {
        True -> True
        False -> list_contains(rest, item)
      }
  }
}

fn list_filter(list: List(a), item_to_remove: a) -> List(a) {
  case list {
    [] -> []
    [first, ..rest] ->
      case first == item_to_remove {
        True -> list_filter(rest, item_to_remove)
        False -> [first, ..list_filter(rest, item_to_remove)]
      }
  }
}
