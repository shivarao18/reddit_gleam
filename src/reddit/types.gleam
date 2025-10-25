import gleam/dict.{type Dict}
import gleam/option.{type Option}

// Core ID types for type safety
pub type UserId =
  String

pub type SubredditId =
  String

pub type PostId =
  String

pub type CommentId =
  String

pub type DirectMessageId =
  String

// User-related types
pub type User {
  User(
    id: UserId,
    username: String,
    karma: Int,
    joined_subreddits: List(SubredditId),
    is_online: Bool,
    created_at: Int,
  )
}

// Subreddit types
pub type Subreddit {
  Subreddit(
    id: SubredditId,
    name: String,
    description: String,
    creator_id: UserId,
    members: List(UserId),
    member_count: Int,
    created_at: Int,
  )
}

// Post types
pub type Post {
  Post(
    id: PostId,
    subreddit_id: SubredditId,
    author_id: UserId,
    title: String,
    content: String,
    upvotes: Int,
    downvotes: Int,
    created_at: Int,
  )
}

// Comment types with hierarchical structure
pub type Comment {
  Comment(
    id: CommentId,
    post_id: PostId,
    parent_id: Option(CommentId),
    author_id: UserId,
    content: String,
    upvotes: Int,
    downvotes: Int,
    created_at: Int,
  )
}

// Vote types
pub type VoteType {
  Upvote
  Downvote
}

pub type VoteTarget {
  PostVote(post_id: PostId)
  CommentVote(comment_id: CommentId)
}

// Direct Message types
pub type DirectMessage {
  DirectMessage(
    id: DirectMessageId,
    from_user_id: UserId,
    to_user_id: UserId,
    content: String,
    is_reply: Bool,
    reply_to_id: Option(DirectMessageId),
    created_at: Int,
  )
}

// Feed types
pub type FeedPost {
  FeedPost(
    post: Post,
    subreddit_name: String,
    author_username: String,
    score: Int,
  )
}

// Result types for operations
pub type RegistrationResult {
  RegistrationSuccess(user: User)
  UsernameTaken
  RegistrationError(reason: String)
}

pub type SubredditResult {
  SubredditSuccess(subreddit: Subreddit)
  SubredditNotFound
  SubredditAlreadyExists
  SubredditError(reason: String)
}

pub type PostResult {
  PostSuccess(post: Post)
  PostNotFound
  PostError(reason: String)
}

pub type CommentResult {
  CommentSuccess(comment: Comment)
  CommentNotFound
  CommentError(reason: String)
}

pub type DirectMessageResult {
  DirectMessageSuccess(dm: DirectMessage)
  DirectMessageNotFound
  DirectMessageError(reason: String)
}

pub type UserResult {
  UserSuccess(user: User)
  UserNotFound
  UserError(reason: String)
}

