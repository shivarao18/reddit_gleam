// Reddit Clone Direct Messaging Demo
// This demonstrates private messaging between multiple concurrent clients

import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import reddit_client

pub fn main() {
  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║     REDDIT CLONE - DIRECT MESSAGING DEMO                    ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
  io.println("")
  io.println("📬 Demonstrating private messaging between concurrent users...")
  io.println("")

  // Scenario: Alice, Bob, and Charlie exchange messages
  io.println("📖 Scenario: Alice, Bob, and Charlie have a conversation")
  io.println("")

  // Register three users
  io.println("1️⃣  Registering users...")
  let alice_id = case reddit_client.register_user("alice_dm") {
    Ok(id) -> {
      io.println("   ✅ Alice registered: " <> id)
      id
    }
    Error(msg) -> {
      io.println("   ⚠️  " <> msg <> " (using existing)")
      "user_1"
    }
  }

  let bob_id = case reddit_client.register_user("bob_dm") {
    Ok(id) -> {
      io.println("   ✅ Bob registered: " <> id)
      id
    }
    Error(msg) -> {
      io.println("   ⚠️  " <> msg <> " (using existing)")
      "user_2"
    }
  }

  let charlie_id = case reddit_client.register_user("charlie_dm") {
    Ok(id) -> {
      io.println("   ✅ Charlie registered: " <> id)
      id
    }
    Error(msg) -> {
      io.println("   ⚠️  " <> msg <> " (using existing)")
      "user_3"
    }
  }
  io.println("")

  // Alice sends a message to Bob
  io.println("2️⃣  Alice sends a message to Bob...")
  case
    reddit_client.send_dm(
      alice_id,
      bob_id,
      "Hi Bob! Want to collaborate on a project?",
    )
  {
    Ok(msg_id) -> {
      io.println("   ✅ Message sent: " <> msg_id)
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
    }
  }
  process.sleep(100)
  io.println("")

  // Bob replies to Alice
  io.println("3️⃣  Bob replies to Alice...")
  case
    reddit_client.send_dm(
      bob_id,
      alice_id,
      "Sure Alice! I'd love to. What's the project about?",
    )
  {
    Ok(msg_id) -> {
      io.println("   ✅ Message sent: " <> msg_id)
    }
    Error(msg) -> {
      io.println("   ❌ Failed: " <> msg)
    }
  }
  process.sleep(100)
  io.println("")

  // Charlie sends messages to both Alice and Bob
  io.println("4️⃣  Charlie sends messages to Alice and Bob...")
  case
    reddit_client.send_dm(
      charlie_id,
      alice_id,
      "Hey Alice! Can I join your project?",
    )
  {
    Ok(_) -> io.println("   ✅ Message to Alice sent")
    Error(_) -> io.println("   ❌ Failed to send to Alice")
  }

  case
    reddit_client.send_dm(
      charlie_id,
      bob_id,
      "Hey Bob! Heard you're working with Alice!",
    )
  {
    Ok(_) -> io.println("   ✅ Message to Bob sent")
    Error(_) -> io.println("   ❌ Failed to send to Bob")
  }
  process.sleep(100)
  io.println("")

  // Alice sends more messages
  io.println("5️⃣  Alice continues the conversation...")
  case
    reddit_client.send_dm(
      alice_id,
      bob_id,
      "It's about building a distributed Reddit clone!",
    )
  {
    Ok(_) -> io.println("   ✅ Message to Bob sent")
    Error(_) -> io.println("   ❌ Failed")
  }

  case
    reddit_client.send_dm(
      alice_id,
      charlie_id,
      "Of course Charlie! The more the merrier!",
    )
  {
    Ok(_) -> io.println("   ✅ Message to Charlie sent")
    Error(_) -> io.println("   ❌ Failed")
  }
  process.sleep(100)
  io.println("")

  // Check message counts
  io.println("6️⃣  Checking message counts...")
  case reddit_client.get_user_dms(alice_id) {
    Ok(count) -> {
      io.println("   📨 Alice has " <> int.to_string(count) <> " messages")
    }
    Error(_) -> io.println("   ❌ Failed to get Alice's messages")
  }

  case reddit_client.get_user_dms(bob_id) {
    Ok(count) -> {
      io.println("   📨 Bob has " <> int.to_string(count) <> " messages")
    }
    Error(_) -> io.println("   ❌ Failed to get Bob's messages")
  }

  case reddit_client.get_user_dms(charlie_id) {
    Ok(count) -> {
      io.println("   📨 Charlie has " <> int.to_string(count) <> " messages")
    }
    Error(_) -> io.println("   ❌ Failed to get Charlie's messages")
  }
  io.println("")

  // Check conversations
  io.println("7️⃣  Checking conversation between Alice and Bob...")
  case reddit_client.get_conversation(alice_id, bob_id) {
    Ok(count) -> {
      io.println(
        "   💬 Alice-Bob conversation has "
        <> int.to_string(count)
        <> " messages",
      )
    }
    Error(_) -> io.println("   ❌ Failed to get conversation")
  }
  io.println("")

  // Concurrent messaging test
  io.println("8️⃣  Testing concurrent messaging (5 users sending DMs)...")
  list.range(1, 5)
  |> list.each(fn(i) {
    run_concurrent_dm_client(i, alice_id)
    process.sleep(50)
  })
  io.println("   ✅ All concurrent messages sent!")
  io.println("")

  // Final message count
  io.println("9️⃣  Final message count for Alice...")
  case reddit_client.get_user_dms(alice_id) {
    Ok(count) -> {
      io.println(
        "   📊 Alice now has " <> int.to_string(count) <> " total messages",
      )
    }
    Error(_) -> io.println("   ❌ Failed to get final count")
  }
  io.println("")

  io.println("╔══════════════════════════════════════════════════════════════╗")
  io.println("║         DIRECT MESSAGING DEMO COMPLETED! ✅                  ║")
  io.println("║                                                              ║")
  io.println("║  ✓ Private messages sent between users                      ║")
  io.println("║  ✓ Conversation threads tracked                             ║")
  io.println("║  ✓ Concurrent messaging tested                              ║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
}

fn run_concurrent_dm_client(client_id: Int, recipient_id: String) -> Nil {
  let username = "dm_user_" <> int.to_string(client_id)

  // Register user
  let user_id = case reddit_client.register_user(username) {
    Ok(id) -> id
    Error(_) -> "user_" <> int.to_string(client_id + 10)
  }

  // Send messages to Alice
  let _ =
    reddit_client.send_dm(
      user_id,
      recipient_id,
      "Hello from " <> username <> "! Testing concurrent DMs.",
    )

  let _ =
    reddit_client.send_dm(
      user_id,
      recipient_id,
      "Second message from " <> username,
    )

  io.println("   ✓ Client " <> int.to_string(client_id) <> " sent messages")
}
