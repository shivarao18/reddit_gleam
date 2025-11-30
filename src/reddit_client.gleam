// Reddit Clone CLI Client - Interactive command-line client
// This demonstrates how to interact with the REST API from a client application

import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string

const base_url = "http://localhost:3000"

pub fn main() {
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║        REDDIT CLONE - CLI CLIENT DEMO                       ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")

  // Scenario: Alice's journey through Reddit
  io.println("📖 Scenario: Alice joins Reddit and explores...")
  io.println("")

  // Step 1: Register Alice
  io.println("1️⃣  Registering user 'alice'...")
  let user_id = case register_user("alice") {
    Ok(id) -> {
      io.println("   ✅ Registered! User ID: " <> id)
      id
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
      "user_1"
    }
  }
  io.println("")

  // Step 2: Create a subreddit
  io.println("2️⃣  Creating subreddit 'r/gleamlang'...")
  let sub_id = case
    create_subreddit(user_id, "gleamlang", "All things Gleam programming")
  {
    Ok(id) -> {
      io.println("   ✅ Created! Subreddit ID: " <> id)
      io.println("   ℹ️  (Creators are automatically members)")
      id
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
      "sub_1"
    }
  }
  io.println("")

  // Step 3: Create another subreddit to join
  io.println("3️⃣  Creating another subreddit 'r/programming'...")
  let other_sub_id = case
    create_subreddit("user_0", "programming", "Programming discussions")
  {
    Ok(id) -> {
      io.println("   ✅ Created! Subreddit ID: " <> id)
      id
    }
    Error(_) -> {
      // If it already exists, assume it's sub_2
      io.println("   ℹ️  Using existing subreddit")
      "sub_2"
    }
  }
  io.println("")

  // Step 4: Join the other subreddit
  io.println("4️⃣  Joining subreddit '" <> other_sub_id <> "'...")
  case join_subreddit(user_id, other_sub_id) {
    Ok(_) -> {
      io.println("   ✅ Joined successfully!")
    }
    Error(msg) -> {
      io.println("   ⚠️  Already a member or failed: " <> msg)
    }
  }
  io.println("")

  // Step 5: Create a post
  io.println("5️⃣  Creating a post in '" <> sub_id <> "'...")
  let post_id = case
    create_post(
      user_id,
      sub_id,
      "My First Gleam Post!",
      "Hello everyone! Just started learning Gleam and loving it!",
    )
  {
    Ok(id) -> {
      io.println("   ✅ Posted! Post ID: " <> id)
      id
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
      "post_1"
    }
  }
  io.println("")

  // Step 6: Add a comment
  io.println("6️⃣  Adding a comment...")
  case create_comment(user_id, post_id, "This is my first comment!") {
    Ok(comment_id) -> {
      io.println("   ✅ Commented! Comment ID: " <> comment_id)
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
    }
  }
  io.println("")

  // Step 7: Get user feed
  io.println("7️⃣  Fetching personalized feed...")
  case get_feed(user_id) {
    Ok(feed_count) -> {
      io.println("   ✅ Feed retrieved! Posts in feed: " <> feed_count)
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
    }
  }
  io.println("")

  // Step 8: List all subreddits
  io.println("8️⃣  Listing all subreddits...")
  case list_subreddits() {
    Ok(count) -> {
      io.println("   ✅ Found " <> count <> " subreddits")
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
    }
  }
  io.println("")

  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║           ✅ CLIENT DEMO COMPLETED SUCCESSFULLY!             ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
}

// Register a new user
pub fn register_user(username: String) -> Result(String, String) {
  let body =
    json.object([#("username", json.string(username))])
    |> json.to_string

  let assert Ok(req) =
    request.to(base_url <> "/api/auth/register")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, body))
    |> result.map(request.prepend_header(_, "content-type", "application/json"))

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 || resp.status == 201 -> {
      // Extract user_id from response
      case string.contains(resp.body, "user_id") {
        True -> {
          // Simple extraction - find "user_id":"user_X"
          let parts = string.split(resp.body, "\"user_id\":\"")
          case parts {
            [_, rest, ..] -> {
              let id_parts = string.split(rest, "\"")
              case id_parts {
                [user_id, ..] -> Ok(user_id)
                _ -> Error("Failed to parse user_id")
              }
            }
            _ -> Error("user_id not found in response")
          }
        }
        False -> Error("Invalid response format")
      }
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Create a subreddit
pub fn create_subreddit(
  creator_id: String,
  name: String,
  description: String,
) -> Result(String, String) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
      #("creator_id", json.string(creator_id)),
    ])
    |> json.to_string

  let assert Ok(req) =
    request.to(base_url <> "/api/subreddits/create")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, body))
    |> result.map(request.prepend_header(_, "content-type", "application/json"))

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 || resp.status == 201 -> {
      // Extract subreddit_id
      let parts = string.split(resp.body, "\"subreddit_id\":\"")
      case parts {
        [_, rest, ..] -> {
          let id_parts = string.split(rest, "\"")
          case id_parts {
            [sub_id, ..] -> Ok(sub_id)
            _ -> Error("Failed to parse subreddit_id")
          }
        }
        _ -> Ok("created")
      }
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Join a subreddit
pub fn join_subreddit(
  user_id: String,
  subreddit_id: String,
) -> Result(Nil, String) {
  let body =
    json.object([#("user_id", json.string(user_id))])
    |> json.to_string

  let assert Ok(req) =
    request.to(base_url <> "/api/subreddits/" <> subreddit_id <> "/join")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, body))
    |> result.map(request.prepend_header(_, "content-type", "application/json"))

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 -> Ok(Nil)
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Create a post
pub fn create_post(
  author_id: String,
  subreddit_id: String,
  title: String,
  content: String,
) -> Result(String, String) {
  let body =
    json.object([
      #("subreddit_id", json.string(subreddit_id)),
      #("author_id", json.string(author_id)),
      #("title", json.string(title)),
      #("content", json.string(content)),
    ])
    |> json.to_string

  let assert Ok(req) =
    request.to(base_url <> "/api/posts/create")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, body))
    |> result.map(request.prepend_header(_, "content-type", "application/json"))

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 || resp.status == 201 -> {
      // Extract post_id
      let parts = string.split(resp.body, "\"post_id\":\"")
      case parts {
        [_, rest, ..] -> {
          let id_parts = string.split(rest, "\"")
          case id_parts {
            [post_id, ..] -> Ok(post_id)
            _ -> Error("Failed to parse post_id")
          }
        }
        _ -> Ok("created")
      }
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Create a comment
pub fn create_comment(
  author_id: String,
  post_id: String,
  content: String,
) -> Result(String, String) {
  let body =
    json.object([
      #("post_id", json.string(post_id)),
      #("author_id", json.string(author_id)),
      #("content", json.string(content)),
      #("parent_id", json.string("")),
    ])
    |> json.to_string

  let assert Ok(req) =
    request.to(base_url <> "/api/comments/create")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, body))
    |> result.map(request.prepend_header(_, "content-type", "application/json"))

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 || resp.status == 201 -> {
      // Extract comment_id
      let parts = string.split(resp.body, "\"comment_id\":\"")
      case parts {
        [_, rest, ..] -> {
          let id_parts = string.split(rest, "\"")
          case id_parts {
            [comment_id, ..] -> Ok(comment_id)
            _ -> Error("Failed to parse comment_id")
          }
        }
        _ -> Ok("created")
      }
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Get user's feed
pub fn get_feed(user_id: String) -> Result(String, String) {
  let assert Ok(req) = request.to(base_url <> "/api/feed/" <> user_id)

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 -> {
      // Count posts in feed
      let post_count =
        string.split(resp.body, "\"post_id\"") |> list.length |> fn(n) { n - 1 }
      Ok(string.inspect(post_count))
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// List all subreddits
pub fn list_subreddits() -> Result(String, String) {
  let assert Ok(req) = request.to(base_url <> "/api/subreddits")

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 -> {
      // Count subreddits
      let count =
        string.split(resp.body, "\"subreddit_id\"")
        |> list.length
        |> fn(n) { n - 1 }
      Ok(string.inspect(count))
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Send a direct message
pub fn send_dm(
  from_user_id: String,
  to_user_id: String,
  content: String,
) -> Result(String, String) {
  let body =
    json.object([
      #("from_user_id", json.string(from_user_id)),
      #("to_user_id", json.string(to_user_id)),
      #("content", json.string(content)),
    ])
    |> json.to_string

  let assert Ok(req) =
    request.to(base_url <> "/api/dm/send")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, body))
    |> result.map(request.prepend_header(_, "content-type", "application/json"))

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 || resp.status == 201 -> {
      // Extract message_id
      let parts = string.split(resp.body, "\"message_id\":\"")
      case parts {
        [_, rest, ..] -> {
          let id_parts = string.split(rest, "\"")
          case id_parts {
            [message_id, ..] -> Ok(message_id)
            _ -> Error("Failed to parse message_id")
          }
        }
        _ -> Ok("sent")
      }
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Get all direct messages for a user
pub fn get_user_dms(user_id: String) -> Result(Int, String) {
  let assert Ok(req) = request.to(base_url <> "/api/dm/user/" <> user_id)

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 -> {
      // Count messages
      let count =
        string.split(resp.body, "\"message_id\"")
        |> list.length
        |> fn(n) { n - 1 }
      Ok(count)
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}

// Get conversation between two users
pub fn get_conversation(
  user1_id: String,
  user2_id: String,
) -> Result(Int, String) {
  let assert Ok(req) =
    request.to(
      base_url <> "/api/dm/conversation/" <> user1_id <> "/" <> user2_id,
    )

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 -> {
      // Count messages in conversation
      let count =
        string.split(resp.body, "\"message_id\"")
        |> list.length
        |> fn(n) { n - 1 }
      Ok(count)
    }
    Ok(resp) -> Error("HTTP " <> string.inspect(resp.status))
    Error(_) -> Error("Connection failed")
  }
}
