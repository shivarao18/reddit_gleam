// Post Manager - Manages posts and voting
// This actor handles post creation, retrieval, voting (upvotes/downvotes),
// and maintains post scores and comment lists.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject, send}
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import reddit/crypto/types as crypto_types
import reddit/protocol.{type PostManagerMessage, type UserRegistryMessage}
import reddit/types.{
  type Post, type PostId, type PostResult, type SubredditId, type UserId,
  type VoteType, Post as PostType, PostError, PostNotFound, PostSuccess,
}

pub type State {
  State(
    posts: Dict(PostId, Post),
    posts_by_subreddit: Dict(SubredditId, List(PostId)),
    post_votes: Dict(PostId, Dict(UserId, VoteType)),
    next_id: Int,
    user_registry: option.Option(Subject(UserRegistryMessage)),
  )
}

pub fn start() -> actor.StartResult(Subject(PostManagerMessage)) {
  let initial_state =
    State(
      posts: dict.new(),
      posts_by_subreddit: dict.new(),
      post_votes: dict.new(),
      next_id: 1,
      user_registry: option.None,
    )

  let builder =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
  actor.start(builder)
}

pub fn set_user_registry(
  post_manager: Subject(PostManagerMessage),
  user_registry: Subject(UserRegistryMessage),
) -> Nil {
  send(post_manager, protocol.SetPostManagerUserRegistry(user_registry))
}

fn handle_message(
  state: State,
  message: PostManagerMessage,
) -> actor.Next(State, PostManagerMessage) {
  case message {
    protocol.CreatePost(
      subreddit_id,
      author_id,
      title,
      content,
      signature,
      reply,
    ) -> {
      let #(result, new_state) =
        create_post(state, subreddit_id, author_id, title, content, signature)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.CreateRepost(original_post_id, author_id, subreddit_id, reply) -> {
      let #(result, new_state) =
        create_repost(state, original_post_id, author_id, subreddit_id)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.GetPost(post_id, reply) -> {
      let result = get_post(state, post_id)
      send(reply, result)
      actor.continue(state)
    }

    protocol.GetPostsBySubreddit(subreddit_id, reply) -> {
      let posts = get_posts_by_subreddit(state, subreddit_id)
      send(reply, posts)
      actor.continue(state)
    }

    protocol.GetAllPosts(reply) -> {
      let posts = get_all_posts(state)
      send(reply, posts)
      actor.continue(state)
    }

    protocol.VotePost(post_id, user_id, vote_type, reply) -> {
      let #(result, new_state) = vote_post(state, post_id, user_id, vote_type)
      send(reply, result)
      actor.continue(new_state)
    }

    protocol.SetPostManagerUserRegistry(user_registry) -> {
      let new_state = State(..state, user_registry: option.Some(user_registry))
      actor.continue(new_state)
    }
  }
}

fn create_post(
  state: State,
  subreddit_id: SubredditId,
  author_id: UserId,
  title: String,
  content: String,
  signature: option.Option(crypto_types.DigitalSignature),
) -> #(PostResult, State) {
  case string.trim(title) {
    "" -> #(PostError("Post title cannot be empty"), state)
    trimmed_title -> {
      // Create new post
      let post_id = "post_" <> int.to_string(state.next_id)
      let timestamp = get_timestamp()
      let new_post =
        PostType(
          id: post_id,
          subreddit_id: subreddit_id,
          author_id: author_id,
          title: trimmed_title,
          content: content,
          upvotes: 0,
          downvotes: 0,
          created_at: timestamp,
          is_repost: False,
          original_post_id: option.None,
          signature: signature,
        )

      // Update posts dict
      let new_posts = dict.insert(state.posts, post_id, new_post)

      // Update posts_by_subreddit
      let existing_posts =
        dict.get(state.posts_by_subreddit, subreddit_id)
        |> result.unwrap([])
      let updated_subreddit_posts = [post_id, ..existing_posts]
      let new_posts_by_subreddit =
        dict.insert(
          state.posts_by_subreddit,
          subreddit_id,
          updated_subreddit_posts,
        )

      // Initialize empty votes dict for this post
      let new_post_votes = dict.insert(state.post_votes, post_id, dict.new())

      let new_state =
        State(
          posts: new_posts,
          posts_by_subreddit: new_posts_by_subreddit,
          post_votes: new_post_votes,
          next_id: state.next_id + 1,
          user_registry: state.user_registry,
        )

      #(PostSuccess(new_post), new_state)
    }
  }
}

fn get_post(state: State, post_id: PostId) -> PostResult {
  case dict.get(state.posts, post_id) {
    Ok(post) -> PostSuccess(post)
    Error(_) -> PostNotFound
  }
}

fn get_posts_by_subreddit(state: State, subreddit_id: SubredditId) -> List(Post) {
  let post_ids =
    dict.get(state.posts_by_subreddit, subreddit_id)
    |> result.unwrap([])

  list.filter_map(post_ids, fn(post_id) { dict.get(state.posts, post_id) })
}

fn get_all_posts(state: State) -> List(Post) {
  dict.values(state.posts)
}

fn create_repost(
  state: State,
  original_post_id: PostId,
  author_id: UserId,
  subreddit_id: SubredditId,
) -> #(PostResult, State) {
  // Get the original post
  case dict.get(state.posts, original_post_id) {
    Error(_) -> #(PostError("Original post not found"), state)
    Ok(original_post) -> {
      // Create repost
      let post_id = "post_" <> int.to_string(state.next_id)
      let timestamp = get_timestamp()
      let repost =
        PostType(
          id: post_id,
          subreddit_id: subreddit_id,
          author_id: author_id,
          title: original_post.title,
          content: original_post.content,
          upvotes: 0,
          downvotes: 0,
          created_at: timestamp,
          is_repost: True,
          original_post_id: option.Some(original_post_id),
          signature: option.None,
        )

      // Update posts dict
      let new_posts = dict.insert(state.posts, post_id, repost)

      // Update posts_by_subreddit
      let existing_posts =
        dict.get(state.posts_by_subreddit, subreddit_id)
        |> result.unwrap([])
      let updated_subreddit_posts = [post_id, ..existing_posts]
      let new_posts_by_subreddit =
        dict.insert(
          state.posts_by_subreddit,
          subreddit_id,
          updated_subreddit_posts,
        )

      // Initialize empty votes dict for this repost
      let new_post_votes = dict.insert(state.post_votes, post_id, dict.new())

      let new_state =
        State(
          posts: new_posts,
          posts_by_subreddit: new_posts_by_subreddit,
          post_votes: new_post_votes,
          next_id: state.next_id + 1,
          user_registry: state.user_registry,
        )

      #(PostSuccess(repost), new_state)
    }
  }
}

fn vote_post(
  state: State,
  post_id: PostId,
  user_id: UserId,
  vote_type: VoteType,
) -> #(Result(Nil, String), State) {
  case dict.get(state.posts, post_id) {
    Error(_) -> #(Error("Post not found"), state)
    Ok(post) -> {
      let votes =
        dict.get(state.post_votes, post_id)
        |> result.unwrap(dict.new())

      // Get previous vote if any
      let previous_vote = dict.get(votes, user_id)

      // Calculate vote changes
      let #(upvote_delta, downvote_delta) = case previous_vote, vote_type {
        Ok(types.Upvote), types.Upvote -> #(0, 0)
        Ok(types.Downvote), types.Downvote -> #(0, 0)
        Ok(types.Upvote), types.Downvote -> #(-1, 1)
        Ok(types.Downvote), types.Upvote -> #(1, -1)
        Error(_), types.Upvote -> #(1, 0)
        Error(_), types.Downvote -> #(0, 1)
      }

      // Update post
      let updated_post =
        PostType(
          ..post,
          upvotes: post.upvotes + upvote_delta,
          downvotes: post.downvotes + downvote_delta,
        )
      let new_posts = dict.insert(state.posts, post_id, updated_post)

      // Update votes
      let new_votes = dict.insert(votes, user_id, vote_type)
      let new_post_votes = dict.insert(state.post_votes, post_id, new_votes)

      // Update post author's karma
      let karma_delta = upvote_delta - downvote_delta
      case state.user_registry, karma_delta {
        option.Some(user_reg), delta if delta != 0 -> {
          // Send karma update (fire and forget)
          send(user_reg, protocol.UpdateUserKarmaAsync(post.author_id, delta))
        }
        _, _ -> Nil
      }

      let new_state =
        State(..state, posts: new_posts, post_votes: new_post_votes)

      #(Ok(Nil), new_state)
    }
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
