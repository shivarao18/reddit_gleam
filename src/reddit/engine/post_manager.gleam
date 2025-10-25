import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import reddit/protocol.{type PostManagerMessage}
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
  )
}

pub fn start() -> Result(actor.StartResult(PostManagerMessage), actor.StartError) {
  let initial_state =
    State(
      posts: dict.new(),
      posts_by_subreddit: dict.new(),
      post_votes: dict.new(),
      next_id: 1,
    )
  actor.start(initial_state, handle_message)
}

fn handle_message(
  message: PostManagerMessage,
  state: State,
) -> actor.Next(PostManagerMessage, State) {
  case message {
    protocol.CreatePost(subreddit_id, author_id, title, content, reply) -> {
      let #(result, new_state) = create_post(state, subreddit_id, author_id, title, content)
      actor.send(reply, result)
      actor.continue(new_state)
    }

    protocol.GetPost(post_id, reply) -> {
      let result = get_post(state, post_id)
      actor.send(reply, result)
      actor.continue(state)
    }

    protocol.GetPostsBySubreddit(subreddit_id, reply) -> {
      let posts = get_posts_by_subreddit(state, subreddit_id)
      actor.send(reply, posts)
      actor.continue(state)
    }

    protocol.VotePost(post_id, user_id, vote_type, reply) -> {
      let #(result, new_state) = vote_post(state, post_id, user_id, vote_type)
      actor.send(reply, result)
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
        )

      // Update posts dict
      let new_posts = dict.insert(state.posts, post_id, new_post)

      // Update posts_by_subreddit
      let existing_posts =
        dict.get(state.posts_by_subreddit, subreddit_id)
        |> result.unwrap([])
      let updated_subreddit_posts = [post_id, ..existing_posts]
      let new_posts_by_subreddit =
        dict.insert(state.posts_by_subreddit, subreddit_id, updated_subreddit_posts)

      // Initialize empty votes dict for this post
      let new_post_votes = dict.insert(state.post_votes, post_id, dict.new())

      let new_state =
        State(
          posts: new_posts,
          posts_by_subreddit: new_posts_by_subreddit,
          post_votes: new_post_votes,
          next_id: state.next_id + 1,
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

  list.filter_map(post_ids, fn(post_id) {
    dict.get(state.posts, post_id)
  })
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

      let new_state =
        State(
          ..state,
          posts: new_posts,
          post_votes: new_post_votes,
        )

      #(Ok(Nil), new_state)
    }
  }
}

// Helper functions
fn get_timestamp() -> Int {
  process.system_time()
  |> int.divide(1_000_000)
  |> result.unwrap(0)
}

