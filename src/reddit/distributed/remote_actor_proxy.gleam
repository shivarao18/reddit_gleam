// Remote Actor Proxy
// Creates local actor proxies that forward messages to remote actors
// This allows user_simulators to use actor.call() normally

import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import reddit/protocol

// Create a simple local proxy actor that forwards every message it receives
// to the remote actor (Pid wrapped in `Subject`).
// The proxy doesn’t attempt to interpret call semantics – it just relays the
// message and lets the remote actor reply directly to the caller’s `Subject`.
pub fn proxy(remote: Subject(msg)) -> Subject(msg) {
  let builder =
    actor.new(remote)
    |> actor.on_message(fn(state, message) {
      // Forward the message to the remote actor
      process.send(state, message)
      actor.continue(state)
    })

  // Start the local proxy actor and unwrap the returned Subject
  let assert Ok(started) = actor.start(builder)
  started.data
}

/// Create local proxies for all engine actors so client code can use `actor.call/3`
/// transparently.
pub fn create_engine_proxies(
  user_registry_remote: Subject(protocol.UserRegistryMessage),
  subreddit_manager_remote: Subject(protocol.SubredditManagerMessage),
  post_manager_remote: Subject(protocol.PostManagerMessage),
  comment_manager_remote: Subject(protocol.CommentManagerMessage),
  dm_manager_remote: Subject(protocol.DirectMessageManagerMessage),
) -> #(
  Subject(protocol.UserRegistryMessage),
  Subject(protocol.SubredditManagerMessage),
  Subject(protocol.PostManagerMessage),
  Subject(protocol.CommentManagerMessage),
  Subject(protocol.DirectMessageManagerMessage),
) {
  #(
    proxy(user_registry_remote),
    proxy(subreddit_manager_remote),
    proxy(post_manager_remote),
    proxy(comment_manager_remote),
    proxy(dm_manager_remote),
  )
}

