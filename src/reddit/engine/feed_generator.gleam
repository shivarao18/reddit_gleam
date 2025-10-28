import gleam/erlang/process.{type Subject, send}
import gleam/list
import gleam/otp/actor
import gleam/result
import reddit/protocol.{
  type FeedGeneratorMessage, type PostManagerMessage, type SubredditManagerMessage,
  type UserRegistryMessage,
}
import reddit/types.{
  type FeedPost, type Post, type Subreddit, type User, FeedPost as FeedPostType,
  PostSuccess, SubredditSuccess, UserSuccess,
}

pub type State {
  State(
    post_manager: Subject(PostManagerMessage),
    subreddit_manager: Subject(SubredditManagerMessage),
    user_registry: Subject(UserRegistryMessage),
  )
}

pub fn start(
  post_manager: Subject(PostManagerMessage),
  subreddit_manager: Subject(SubredditManagerMessage),
  user_registry: Subject(UserRegistryMessage),
) -> actor.StartResult(Subject(FeedGeneratorMessage)) {
  let initial_state =
    State(
      post_manager: post_manager,
      subreddit_manager: subreddit_manager,
      user_registry: user_registry,
    )
  
  let builder =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
  actor.start(builder)
}

fn handle_message(
  state: State,
  message: FeedGeneratorMessage,
) -> actor.Next(State, FeedGeneratorMessage) {
  case message {
    protocol.GetFeed(user_id, limit, reply) -> {
      let feed = generate_feed(state, user_id, limit)
      send(reply, feed)
      actor.continue(state)
    }
  }
}

fn generate_feed(
  state: State,
  user_id: String,
  limit: Int,
) -> List(FeedPost) {
  // Get user's joined subreddits
  let user_result = actor.call(state.user_registry, waiting: 5000, sending: protocol.GetUser(user_id, _))
  
  case user_result {
    UserSuccess(user) -> {
      // Get posts from all joined subreddits
      let all_posts =
        list.flat_map(user.joined_subreddits, fn(subreddit_id) {
          let posts =
            actor.call(
              state.post_manager,
              waiting: 5000,
              sending: protocol.GetPostsBySubreddit(subreddit_id, _),
            )
          
          // Enrich posts with subreddit and author info
          list.filter_map(posts, fn(post) {
            enrich_post(state, post)
          })
        })

      // Sort by score (upvotes - downvotes) and recency
      let sorted_posts =
        list.sort(all_posts, fn(a, b) {
          // First sort by score
          case compare_int(b.score, a.score) {
            0 -> {
              // If scores are equal, sort by created_at (newer first)
              compare_int(b.post.created_at, a.post.created_at)
            }
            other -> other
          }
        })

      // Take only the requested limit
      list.take(sorted_posts, limit)
    }
    _ -> []
  }
}

fn enrich_post(state: State, post: Post) -> Result(FeedPost, Nil) {
  // Get subreddit name
  let subreddit_result =
    actor.call(
      state.subreddit_manager,
      waiting: 5000,
      sending: protocol.GetSubreddit(post.subreddit_id, _),
    )

  // Get author username
  let author_result =
    actor.call(state.user_registry, waiting: 5000, sending: protocol.GetUser(post.author_id, _))

  case subreddit_result, author_result {
    SubredditSuccess(subreddit), UserSuccess(author) -> {
      let score = post.upvotes - post.downvotes
      Ok(FeedPostType(
        post: post,
        subreddit_name: subreddit.name,
        author_username: author.username,
        score: score,
      ))
    }
    _, _ -> Error(Nil)
  }
}

fn compare_int(a: Int, b: Int) -> Int {
  case a > b {
    True -> 1
    False ->
      case a < b {
        True -> -1
        False -> 0
      }
  }
}

