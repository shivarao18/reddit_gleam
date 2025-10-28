import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import reddit/types.{
  type Comment, type CommentId, type CommentResult, type DirectMessage,
  type DirectMessageId, type DirectMessageResult, type FeedPost, type Post,
  type PostId, type PostResult, type RegistrationResult, type Subreddit,
  type SubredditId, type SubredditResult, type UserId, type UserResult,
  type VoteType,
}

// User Registry Messages
pub type UserRegistryMessage {
  RegisterUser(
    username: String,
    reply: Subject(RegistrationResult),
  )
  GetUser(
    user_id: UserId,
    reply: Subject(UserResult),
  )
  GetUserByUsername(
    username: String,
    reply: Subject(UserResult),
  )
  UpdateUserOnlineStatus(
    user_id: UserId,
    is_online: Bool,
    reply: Subject(Result(Nil, String)),
  )
  AddSubredditToUser(
    user_id: UserId,
    subreddit_id: SubredditId,
    reply: Subject(Result(Nil, String)),
  )
  RemoveSubredditFromUser(
    user_id: UserId,
    subreddit_id: SubredditId,
    reply: Subject(Result(Nil, String)),
  )
  UpdateUserKarma(
    user_id: UserId,
    karma_delta: Int,
    reply: Subject(Result(Nil, String)),
  )
}

// Subreddit Manager Messages
pub type SubredditManagerMessage {
  CreateSubreddit(
    name: String,
    description: String,
    creator_id: UserId,
    reply: Subject(SubredditResult),
  )
  GetSubreddit(
    subreddit_id: SubredditId,
    reply: Subject(SubredditResult),
  )
  GetSubredditByName(
    name: String,
    reply: Subject(SubredditResult),
  )
  JoinSubreddit(
    subreddit_id: SubredditId,
    user_id: UserId,
    reply: Subject(Result(Nil, String)),
  )
  LeaveSubreddit(
    subreddit_id: SubredditId,
    user_id: UserId,
    reply: Subject(Result(Nil, String)),
  )
  ListAllSubreddits(
    reply: Subject(List(Subreddit)),
  )
}

// Post Manager Messages
pub type PostManagerMessage {
  CreatePost(
    subreddit_id: SubredditId,
    author_id: UserId,
    title: String,
    content: String,
    reply: Subject(PostResult),
  )
  GetPost(
    post_id: PostId,
    reply: Subject(PostResult),
  )
  GetPostsBySubreddit(
    subreddit_id: SubredditId,
    reply: Subject(List(Post)),
  )
  VotePost(
    post_id: PostId,
    user_id: UserId,
    vote_type: VoteType,
    reply: Subject(Result(Nil, String)),
  )
}

// Comment Manager Messages
pub type CommentManagerMessage {
  CreateComment(
    post_id: PostId,
    author_id: UserId,
    content: String,
    parent_id: Option(CommentId),
    reply: Subject(CommentResult),
  )
  GetComment(
    comment_id: CommentId,
    reply: Subject(CommentResult),
  )
  GetCommentsByPost(
    post_id: PostId,
    reply: Subject(List(Comment)),
  )
  VoteComment(
    comment_id: CommentId,
    user_id: UserId,
    vote_type: VoteType,
    reply: Subject(Result(Nil, String)),
  )
}

// Direct Message Manager Messages
pub type DirectMessageManagerMessage {
  SendDirectMessage(
    from_user_id: UserId,
    to_user_id: UserId,
    content: String,
    reply_to_id: Option(DirectMessageId),
    reply: Subject(DirectMessageResult),
  )
  GetDirectMessages(
    user_id: UserId,
    reply: Subject(List(DirectMessage)),
  )
  GetConversation(
    user1_id: UserId,
    user2_id: UserId,
    reply: Subject(List(DirectMessage)),
  )
}

// Feed Generator Messages
pub type FeedGeneratorMessage {
  GetFeed(
    user_id: UserId,
    limit: Int,
    reply: Subject(List(FeedPost)),
  )
}

// Karma Calculator Messages
pub type KarmaCalculatorMessage {
  CalculateKarmaForUser(
    user_id: UserId,
    reply: Subject(Int),
  )
  RecalculateAllKarma(
    reply: Subject(Result(Nil, String)),
  )
}

