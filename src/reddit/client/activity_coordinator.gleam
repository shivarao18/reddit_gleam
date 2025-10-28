import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/result
import reddit/client/zipf
import reddit/types.{type SubredditId}

pub type ActivityConfig {
  ActivityConfig(
    num_subreddits: Int,
    zipf_exponent: Float,
    post_probability: Float,
    comment_probability: Float,
    vote_probability: Float,
    dm_probability: Float,
  )
}

pub type State {
  State(
    config: ActivityConfig,
    zipf_dist: zipf.ZipfDistribution,
    popular_subreddits: List(SubredditId),
    subreddit_activity: Dict(SubredditId, Int),
  )
}

pub type ActivityCoordinatorMessage {
  GetSubredditForActivity(reply: actor.Subject(SubredditId))
  GetActivityType(reply: actor.Subject(ActivityType))
  RecordActivity(subreddit_id: SubredditId)
  GetStats(reply: actor.Subject(ActivityStats))
}

pub type ActivityType {
  CreatePost
  CreateComment
  CastVote
  SendDirectMessage
  JoinSubreddit
}

pub type ActivityStats {
  ActivityStats(
    total_activities: Int,
    subreddit_activity: Dict(SubredditId, Int),
  )
}

pub fn default_config() -> ActivityConfig {
  ActivityConfig(
    num_subreddits: 20,
    zipf_exponent: 1.0,
    post_probability: 0.3,
    comment_probability: 0.3,
    vote_probability: 0.3,
    dm_probability: 0.1,
  )
}

pub fn start(config: ActivityConfig, subreddits: List(SubredditId)) -> Result(
  actor.StartResult(ActivityCoordinatorMessage),
  actor.StartError,
) {
  let zipf_dist = zipf.new(config.num_subreddits, config.zipf_exponent)
  let initial_state =
    State(
      config: config,
      zipf_dist: zipf_dist,
      popular_subreddits: subreddits,
      subreddit_activity: dict.new(),
    )
  actor.start(initial_state, handle_message)
}

fn handle_message(
  message: ActivityCoordinatorMessage,
  state: State,
) -> actor.Next(ActivityCoordinatorMessage, State) {
  case message {
    GetSubredditForActivity(reply) -> {
      let subreddit = select_subreddit(state)
      actor.send(reply, subreddit)
      actor.continue(state)
    }

    GetActivityType(reply) -> {
      let activity = select_activity_type(state.config)
      actor.send(reply, activity)
      actor.continue(state)
    }

    RecordActivity(subreddit_id) -> {
      let current_count =
        dict.get(state.subreddit_activity, subreddit_id)
        |> result.unwrap(0)
      let new_activity =
        dict.insert(state.subreddit_activity, subreddit_id, current_count + 1)
      let new_state = State(..state, subreddit_activity: new_activity)
      actor.continue(new_state)
    }

    GetStats(reply) -> {
      let total =
        dict.fold(state.subreddit_activity, 0, fn(acc, _, count) {
          acc + count
        })
      let stats =
        ActivityStats(
          total_activities: total,
          subreddit_activity: state.subreddit_activity,
        )
      actor.send(reply, stats)
      actor.continue(state)
    }
  }
}

fn select_subreddit(state: State) -> SubredditId {
  // Use Zipf distribution to select a subreddit
  let random = generate_random()
  let rank = zipf.sample(state.zipf_dist, random)
  
  // Get subreddit at this rank (1-indexed)
  case list.at(state.popular_subreddits, rank - 1) {
    Ok(subreddit) -> subreddit
    Error(_) -> {
      // Fallback to first subreddit
      case list.first(state.popular_subreddits) {
        Ok(sub) -> sub
        Error(_) -> "default_subreddit"
      }
    }
  }
}

fn select_activity_type(config: ActivityConfig) -> ActivityType {
  let random = generate_random()
  
  // Normalize probabilities
  let total =
    config.post_probability
    +. config.comment_probability
    +. config.vote_probability
    +. config.dm_probability
  
  let post_threshold = config.post_probability /. total
  let comment_threshold = post_threshold +. config.comment_probability /. total
  let vote_threshold = comment_threshold +. config.vote_probability /. total
  
  case random {
    r if r <. post_threshold -> CreatePost
    r if r <. comment_threshold -> CreateComment
    r if r <. vote_threshold -> CastVote
    _ -> SendDirectMessage
  }
}

// Simple random number generator using erlang's random
@external(erlang, "rand", "uniform")
fn generate_random() -> Float

