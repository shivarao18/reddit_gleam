// Activity Coordinator - Manages activity scheduling and coordination
// This actor coordinates user activities using a Zipf distribution for realistic
// subreddit selection patterns, ensuring popular subreddits get more activity.

import gleam/dict.{type Dict}
import gleam/erlang/process
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
    repost_probability: Float,
    join_probability: Float,
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
  GetSubredditForActivity(process.Subject(SubredditId))
  GetActivityType(process.Subject(ActivityType))
  RecordActivity(subreddit_id: SubredditId)
  GetStats(process.Subject(ActivityStats))
}

pub type ActivityType {
  CreatePost
  CreateComment
  CastVote
  SendDirectMessage
  JoinSubreddit
  CreateRepost
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
    post_probability: 0.20,
    comment_probability: 0.20,
    vote_probability: 0.20,
    dm_probability: 0.10,
    repost_probability: 0.15,
    join_probability: 0.15,
  )
  // Total: 1.0 (all activities explicitly weighted)
}

pub fn start(config: ActivityConfig, subreddits: List(SubredditId)) -> actor.StartResult(process.Subject(ActivityCoordinatorMessage)) {
  let zipf_dist = zipf.new(config.num_subreddits, config.zipf_exponent)
  let initial_state =
    State(
      config: config,
      zipf_dist: zipf_dist,
      popular_subreddits: subreddits,
      subreddit_activity: dict.new(),
    )

  let builder =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
  actor.start(builder)
}

fn handle_message(
  state: State,
  message: ActivityCoordinatorMessage,
) -> actor.Next(State, ActivityCoordinatorMessage) {
  case message {
    GetSubredditForActivity(reply) -> {
      let subreddit = select_subreddit(state)
      process.send(reply, subreddit)
      actor.continue(state)
    }

    GetActivityType(reply) -> {
      let activity = select_activity_type(state.config)
      process.send(reply, activity)
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
      process.send(reply, stats)
      actor.continue(state)
    }
  }
}

fn select_subreddit(state: State) -> SubredditId {
  let random = generate_random()
  let rank = zipf.sample(state.zipf_dist, random)
  let after_drop = list.drop(state.popular_subreddits, rank - 1)
  case list.first(after_drop) {
    Ok(subreddit) -> subreddit
    Error(_) -> case list.first(state.popular_subreddits) {
      Ok(sub) -> sub
      Error(_) -> "default_subreddit"
    }
  }
}

fn select_activity_type(config: ActivityConfig) -> ActivityType {
  let random = generate_random()
  
  // Build cumulative thresholds (no normalization - all probabilities must sum to 1.0)
  let post_threshold = config.post_probability
  let comment_threshold = post_threshold +. config.comment_probability
  let vote_threshold = comment_threshold +. config.vote_probability
  let dm_threshold = vote_threshold +. config.dm_probability
  let repost_threshold = dm_threshold +. config.repost_probability
  let join_threshold = repost_threshold +. config.join_probability
  
  case random {
    r if r <. post_threshold -> CreatePost
    r if r <. comment_threshold -> CreateComment
    r if r <. vote_threshold -> CastVote
    r if r <. dm_threshold -> SendDirectMessage
    r if r <. repost_threshold -> CreateRepost
    r if r <. join_threshold -> JoinSubreddit
    _ -> JoinSubreddit  // Fallback (should not reach if probabilities sum to 1.0)
  }
}

// Simple random number generator using erlang's random
@external(erlang, "rand", "uniform")
fn generate_random() -> Float

