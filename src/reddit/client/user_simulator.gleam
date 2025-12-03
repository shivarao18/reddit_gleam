// User Simulator - Simulates individual user behavior
// Each user simulator actor represents a single user and performs various activities
// such as creating posts, commenting, voting, joining subreddits, and sending DMs.

import gleam/erlang/process.{type Subject, send}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import reddit/client/activity_coordinator.{
  type ActivityCoordinatorMessage, CastVote, CreateComment, CreatePost,
  CreateRepost, JoinSubreddit, SendDirectMessage,
}
import reddit/client/metrics_collector.{type MetricsMessage}
import reddit/protocol.{
  type CommentManagerMessage, type DirectMessageManagerMessage,
  type PostManagerMessage, type SubredditManagerMessage,
  type UserRegistryMessage,
}
import reddit/types.{type CommentId, type PostId, type SubredditId, type UserId}

pub type UserSimulatorState {
  UserSimulatorState(
    user_id: Option(UserId),
    username: String,
    is_online: Bool,
    joined_subreddits: List(SubredditId),
    my_posts: List(PostId),
    my_comments: List(CommentId),
    user_registry: Subject(UserRegistryMessage),
    subreddit_manager: Subject(SubredditManagerMessage),
    post_manager: Subject(PostManagerMessage),
    comment_manager: Subject(CommentManagerMessage),
    dm_manager: Subject(DirectMessageManagerMessage),
    activity_coordinator: Subject(ActivityCoordinatorMessage),
    metrics: Subject(MetricsMessage),
  )
}

pub type UserSimulatorMessage {
  Initialize
  PerformActivity
  GoOnline
  GoOffline
  Shutdown
}

pub fn start(
  username: String,
  user_registry: Subject(UserRegistryMessage),
  subreddit_manager: Subject(SubredditManagerMessage),
  post_manager: Subject(PostManagerMessage),
  comment_manager: Subject(CommentManagerMessage),
  dm_manager: Subject(DirectMessageManagerMessage),
  activity_coordinator: Subject(ActivityCoordinatorMessage),
  metrics: Subject(MetricsMessage),
) -> actor.StartResult(Subject(UserSimulatorMessage)) {
  let initial_state =
    UserSimulatorState(
      user_id: option.None,
      username: username,
      is_online: False,
      joined_subreddits: [],
      my_posts: [],
      my_comments: [],
      user_registry: user_registry,
      subreddit_manager: subreddit_manager,
      post_manager: post_manager,
      comment_manager: comment_manager,
      dm_manager: dm_manager,
      activity_coordinator: activity_coordinator,
      metrics: metrics,
    )

  let builder =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
  actor.start(builder)
}

fn handle_message(
  state: UserSimulatorState,
  message: UserSimulatorMessage,
) -> actor.Next(UserSimulatorState, UserSimulatorMessage) {
  case message {
    Initialize -> {
      let new_state = initialize_user(state)
      actor.continue(new_state)
    }

    PerformActivity -> {
      let new_state = perform_activity(state)
      actor.continue(new_state)
    }

    GoOnline -> {
      let new_state = go_online(state)
      actor.continue(new_state)
    }

    GoOffline -> {
      let new_state = go_offline(state)
      actor.continue(new_state)
    }

    Shutdown -> {
      actor.stop()
    }
  }
}

fn initialize_user(state: UserSimulatorState) -> UserSimulatorState {
  // Register the user
  let result =
    actor.call(
      state.user_registry,
      waiting: 5000,
      sending: protocol.RegisterUser(state.username, option.None, _),
    )

  case result {
    types.RegistrationSuccess(user) -> {
      send(
        state.metrics,
        metrics_collector.RecordMetric(metrics_collector.UserRegistered),
      )
      UserSimulatorState(
        ..state,
        user_id: option.Some(user.id),
        is_online: True,
      )
    }
    _ -> state
  }
}

fn perform_activity(state: UserSimulatorState) -> UserSimulatorState {
  case state.is_online, state.user_id {
    True, option.Some(user_id) -> {
      // Get activity type from coordinator
      let activity_type =
        actor.call(
          state.activity_coordinator,
          waiting: 5000,
          sending: activity_coordinator.GetActivityType,
        )

      case activity_type {
        CreatePost -> create_post(state, user_id)
        CreateComment -> create_comment(state, user_id)
        CastVote -> cast_vote(state, user_id)
        SendDirectMessage -> send_dm(state, user_id)
        JoinSubreddit -> join_subreddit(state, user_id)
        CreateRepost -> create_repost(state, user_id)
      }
    }
    _, _ -> state
  }
}

fn create_post(state: UserSimulatorState, user_id: UserId) -> UserSimulatorState {
  // Get a subreddit to post in
  let subreddit_id =
    actor.call(
      state.activity_coordinator,
      waiting: 5000,
      sending: activity_coordinator.GetSubredditForActivity,
    )

  let title =
    "Post by " <> state.username <> " at " <> int.to_string(get_timestamp())
  let content = "This is a simulated post content."

  let result =
    actor.call(state.post_manager, waiting: 5000, sending: protocol.CreatePost(
      subreddit_id,
      user_id,
      title,
      content,
      option.None,
      _,
    ))

  case result {
    types.PostSuccess(post) -> {
      send(
        state.metrics,
        metrics_collector.RecordMetric(metrics_collector.PostCreated),
      )
      UserSimulatorState(..state, my_posts: [post.id, ..state.my_posts])
    }
    _ -> state
  }
}

fn create_comment(
  state: UserSimulatorState,
  user_id: UserId,
) -> UserSimulatorState {
  // Get all posts to potentially comment on
  let all_posts =
    actor.call(state.post_manager, waiting: 5000, sending: protocol.GetAllPosts)

  case list.length(all_posts) {
    0 -> state
    len -> {
      // Pick a random post to comment on
      let random_index = erlang_uniform(len) - 1
      case list.drop(all_posts, random_index) |> list.first() {
        Ok(post) -> {
          // 40% chance to reply to an existing comment (nested), 60% chance to comment on post
          let should_nest = erlang_uniform(10) <= 4

          let parent_comment_id = case should_nest {
            True -> {
              // Try to get comments on this post to reply to
              let post_comments =
                actor.call(
                  state.comment_manager,
                  waiting: 5000,
                  sending: protocol.GetCommentsByPost(post.id, _),
                )

              case list.length(post_comments) {
                0 -> option.None
                comment_len -> {
                  let comment_index = erlang_uniform(comment_len) - 1
                  case list.drop(post_comments, comment_index) |> list.first() {
                    Ok(parent_comment) -> option.Some(parent_comment.id)
                    Error(_) -> option.None
                  }
                }
              }
            }
            False -> option.None
          }

          let content = case parent_comment_id {
            option.Some(_) -> "Reply by " <> state.username
            option.None -> "Comment by " <> state.username
          }

          let result =
            actor.call(
              state.comment_manager,
              waiting: 5000,
              sending: protocol.CreateComment(
                post.id,
                user_id,
                content,
                parent_comment_id,
                _,
              ),
            )

          case result {
            types.CommentSuccess(comment) -> {
              send(
                state.metrics,
                metrics_collector.RecordMetric(metrics_collector.CommentCreated),
              )
              UserSimulatorState(..state, my_comments: [
                comment.id,
                ..state.my_comments
              ])
            }
            _ -> state
          }
        }
        Error(_) -> state
      }
    }
  }
}

fn cast_vote(state: UserSimulatorState, user_id: UserId) -> UserSimulatorState {
  // Randomly choose upvote or downvote (70% upvote, 30% downvote for realistic Reddit)
  let vote_type = case erlang_uniform(10) {
    n if n <= 7 -> types.Upvote
    _ -> types.Downvote
  }

  // 50% chance to vote on a post, 50% chance to vote on a comment
  let vote_on_post = erlang_uniform(2) == 1

  case vote_on_post {
    True -> {
      // Vote on a post
      let all_posts =
        actor.call(
          state.post_manager,
          waiting: 5000,
          sending: protocol.GetAllPosts,
        )

      case list.length(all_posts) {
        0 -> state
        len -> {
          let random_index = erlang_uniform(len) - 1
          case list.drop(all_posts, random_index) |> list.first() {
            Ok(post) -> {
              let _ =
                actor.call(
                  state.post_manager,
                  waiting: 5000,
                  sending: protocol.VotePost(post.id, user_id, vote_type, _),
                )
              send(
                state.metrics,
                metrics_collector.RecordMetric(metrics_collector.VoteCast),
              )
              state
            }
            Error(_) -> state
          }
        }
      }
    }
    False -> {
      // Vote on a comment
      // Get all posts to find their comments
      let all_posts =
        actor.call(
          state.post_manager,
          waiting: 5000,
          sending: protocol.GetAllPosts,
        )

      case list.length(all_posts) {
        0 -> state
        len -> {
          let random_index = erlang_uniform(len) - 1
          case list.drop(all_posts, random_index) |> list.first() {
            Ok(post) -> {
              // Get comments on this post
              let post_comments =
                actor.call(
                  state.comment_manager,
                  waiting: 5000,
                  sending: protocol.GetCommentsByPost(post.id, _),
                )

              case list.length(post_comments) {
                0 -> state
                comment_len -> {
                  let comment_index = erlang_uniform(comment_len) - 1
                  case list.drop(post_comments, comment_index) |> list.first() {
                    Ok(comment) -> {
                      let _ =
                        actor.call(
                          state.comment_manager,
                          waiting: 5000,
                          sending: protocol.VoteComment(
                            comment.id,
                            user_id,
                            vote_type,
                            _,
                          ),
                        )
                      send(
                        state.metrics,
                        metrics_collector.RecordMetric(
                          metrics_collector.VoteCast,
                        ),
                      )
                      state
                    }
                    Error(_) -> state
                  }
                }
              }
            }
            Error(_) -> state
          }
        }
      }
    }
  }
}

fn create_repost(
  state: UserSimulatorState,
  user_id: UserId,
) -> UserSimulatorState {
  // Get all posts to choose from
  let all_posts =
    actor.call(state.post_manager, waiting: 5000, sending: protocol.GetAllPosts)

  // Pick first post that's not ours
  case list.first(all_posts) {
    Ok(original_post) -> {
      // Get a subreddit to repost in
      let subreddit_id =
        actor.call(
          state.activity_coordinator,
          waiting: 5000,
          sending: activity_coordinator.GetSubredditForActivity,
        )

      let result =
        actor.call(
          state.post_manager,
          waiting: 5000,
          sending: protocol.CreateRepost(
            original_post.id,
            user_id,
            subreddit_id,
            _,
          ),
        )

      case result {
        types.PostSuccess(repost) -> {
          send(
            state.metrics,
            metrics_collector.RecordMetric(metrics_collector.RepostCreated),
          )
          UserSimulatorState(..state, my_posts: [repost.id, ..state.my_posts])
        }
        _ -> state
      }
    }
    Error(_) -> state
  }
}

fn send_dm(state: UserSimulatorState, user_id: UserId) -> UserSimulatorState {
  // Generate a random recipient user ID (simulate sending to another user)
  // In a real implementation, we'd query for actual user IDs
  // For simulation, we'll create a message to a simulated recipient
  let recipient_id = "user_" <> int.to_string(get_random_user_id())

  // Don't send to ourselves
  case recipient_id == user_id {
    True -> state
    False -> {
      let content = "Direct message from " <> state.username

      let result =
        actor.call(
          state.dm_manager,
          waiting: 5000,
          sending: protocol.SendDirectMessage(
            user_id,
            recipient_id,
            content,
            option.None,
            _,
          ),
        )

      case result {
        types.DirectMessageSuccess(_dm) -> {
          send(
            state.metrics,
            metrics_collector.RecordMetric(metrics_collector.DirectMessageSent),
          )
          state
        }
        _ -> state
      }
    }
  }
}

// Generate a random user ID between 1 and 100
@external(erlang, "rand", "uniform")
fn erlang_uniform(n: Int) -> Int

fn get_random_user_id() -> Int {
  erlang_uniform(100)
}

fn join_subreddit(
  state: UserSimulatorState,
  user_id: UserId,
) -> UserSimulatorState {
  // Get a subreddit to join
  let subreddit_id =
    actor.call(
      state.activity_coordinator,
      waiting: 5000,
      sending: activity_coordinator.GetSubredditForActivity,
    )

  // Check if already joined
  case list.contains(state.joined_subreddits, subreddit_id) {
    True -> state
    False -> {
      let _ =
        actor.call(
          state.subreddit_manager,
          waiting: 5000,
          sending: protocol.JoinSubreddit(subreddit_id, user_id, _),
        )
      let _ =
        actor.call(
          state.user_registry,
          waiting: 5000,
          sending: protocol.AddSubredditToUser(user_id, subreddit_id, _),
        )

      send(
        state.metrics,
        metrics_collector.RecordMetric(metrics_collector.SubredditJoined),
      )
      UserSimulatorState(..state, joined_subreddits: [
        subreddit_id,
        ..state.joined_subreddits
      ])
    }
  }
}

fn go_online(state: UserSimulatorState) -> UserSimulatorState {
  case state.user_id {
    option.Some(user_id) -> {
      let _ =
        actor.call(
          state.user_registry,
          waiting: 5000,
          sending: protocol.UpdateUserOnlineStatus(user_id, True, _),
        )
      UserSimulatorState(..state, is_online: True)
    }
    option.None -> state
  }
}

fn go_offline(state: UserSimulatorState) -> UserSimulatorState {
  case state.user_id {
    option.Some(user_id) -> {
      let _ =
        actor.call(
          state.user_registry,
          waiting: 5000,
          sending: protocol.UpdateUserOnlineStatus(user_id, False, _),
        )
      UserSimulatorState(..state, is_online: False)
    }
    option.None -> state
  }
}

@external(erlang, "erlang", "system_time")
fn erlang_system_time() -> Int

fn get_timestamp() -> Int {
  erlang_system_time()
  |> int.divide(1_000_000)
  |> result.unwrap(0)
}
