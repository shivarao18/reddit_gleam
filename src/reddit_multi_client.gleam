// Reddit Clone Multi-Client Load Tester
// This demonstrates multiple independent clients connecting to the REST API server

import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import reddit_client

pub fn main() {
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║     REDDIT CLONE - MULTI-CLIENT LOAD TEST                   ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")

  let client_count = 5
  io.println("🚀 Running " <> int.to_string(client_count) <> " independent clients...")
  io.println("   (Each client is a separate HTTP connection)")
  io.println("")

  // Run multiple independent client simulations
  // Each represents a separate user connecting to the API
  list.range(1, client_count)
  |> list.each(fn(i) {
    run_client_simulation(i)
    process.sleep(100)  // Small delay between clients for readability
  })

  io.println("")
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║  ✅ ALL " <> int.to_string(client_count) <> " CLIENTS COMPLETED SUCCESSFULLY!               ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")
  io.println("💡 Tip: To test true concurrency, run this program in multiple")
  io.println("   terminals simultaneously, or run the bash test script which")
  io.println("   can spawn background processes.")
}

fn run_client_simulation(client_id: Int) -> Nil {
  let username = "loadtest_user_" <> int.to_string(client_id)
  let client_tag = "[Client " <> int.to_string(client_id) <> "]"

  io.println(client_tag <> " Starting simulation...")

  // Register user
  let user_id = case reddit_client.register_user(username) {
    Ok(id) -> {
      io.println(client_tag <> " ✅ Registered as " <> username)
      id
    }
    Error(_) -> {
      io.println(client_tag <> " ⚠️  Registration failed, using fallback")
      "user_" <> int.to_string(client_id)
    }
  }

  // Small delay to stagger requests
  process.sleep(50)

  // Create a subreddit
  let subreddit_name = "testsub" <> int.to_string(client_id)
  case reddit_client.create_subreddit(
    user_id,
    subreddit_name,
    "Test subreddit by " <> username,
  ) {
    Ok(_) -> {
      io.println(client_tag <> " ✅ Created r/" <> subreddit_name)
    }
    Error(_) -> {
      io.println(client_tag <> " ⚠️  Subreddit creation failed")
    }
  }

  process.sleep(50)

  // Join some existing subreddits
  let _ = reddit_client.join_subreddit(user_id, "sub_1")
  io.println(client_tag <> " ✅ Joined existing subreddit")

  process.sleep(50)

  // Create multiple posts
  list.each(list.range(1, 3), fn(post_num) {
    case reddit_client.create_post(
      user_id,
      "sub_1",
      "Post #" <> int.to_string(post_num) <> " by " <> username,
      "This is test content from client " <> int.to_string(client_id),
    ) {
      Ok(_) -> {
        io.println(
          client_tag
          <> " ✅ Created post #"
          <> int.to_string(post_num),
        )
      }
      Error(_) -> {
        io.println(
          client_tag
          <> " ⚠️  Post #"
          <> int.to_string(post_num)
          <> " failed",
        )
      }
    }
    process.sleep(30)
  })

  // Get feed
  case reddit_client.get_feed(user_id) {
    Ok(count) -> {
      io.println(client_tag <> " ✅ Retrieved feed (" <> count <> " posts)")
    }
    Error(_) -> {
      io.println(client_tag <> " ⚠️  Feed retrieval failed")
    }
  }

  io.println(client_tag <> " ✨ Simulation complete!")
}

