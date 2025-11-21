// Server Context - Shared type for server configuration
// This module defines the ServerContext type to avoid import cycles

import gleam/erlang/process
import reddit/protocol

/// Server context holds references to all engine actors
pub type ServerContext {
  ServerContext(
    user_registry: process.Subject(protocol.UserRegistryMessage),
    subreddit_manager: process.Subject(protocol.SubredditManagerMessage),
    post_manager: process.Subject(protocol.PostManagerMessage),
    comment_manager: process.Subject(protocol.CommentManagerMessage),
    dm_manager: process.Subject(protocol.DirectMessageManagerMessage),
    feed_generator: process.Subject(protocol.FeedGeneratorMessage),
  )
}

