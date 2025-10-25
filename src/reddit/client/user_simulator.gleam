// import gleam/erlang/process
// import gleam/int
// import gleam/list
// import gleam/otp/actor.{type Subject}
// import gleam/option
// import gleam/result
// import gleam/string
// import reddit/client/activity_coordinator.{
//   type ActivityCoordinatorMessage, type ActivityType,
// }
// import reddit/client/metrics_collector.{type MetricsMessage}
// import reddit/protocol.{
//   type CommentManagerMessage, type DirectMessageManagerMessage,
//   type PostManagerMessage, type SubredditManagerMessage, type UserRegistryMessage,
// }
// import reddit/types.{
//   type CommentId, type PostId, type SubredditId, type UserId,
// }

// pub type UserSimulatorState {
//   UserSimulatorState(
//     user_id: Option(UserId),
//     username: String,
//     is_online: Bool,
//     joined_subreddits: List(SubredditId),
//     my_posts: List(PostId),
//     my_comments: List(CommentId),
//     user_registry: Subject(UserRegistryMessage),
//     subreddit_manager: Subject(SubredditManagerMessage),
//     post_manager: Subject(PostManagerMessage),
//     comment_manager: Subject(CommentManagerMessage),
//     dm_manager: Subject(DirectMessageManagerMessage),
//     activity_coordinator: Subject(ActivityCoordinatorMessage),
//     metrics: Subject(MetricsMessage),
//   )
// }

// pub type UserSimulatorMessage {
//   Initialize
//   PerformActivity
//   GoOnline
//   GoOffline
//   Shutdown
// }

// pub fn start(
//   username: String,
//   user_registry: Subject(UserRegistryMessage),
//   subreddit_manager: Subject(SubredditManagerMessage),
//   post_manager: Subject(PostManagerMessage),
//   comment_manager: Subject(CommentManagerMessage),
//   dm_manager: Subject(DirectMessageManagerMessage),
//   activity_coordinator: Subject(ActivityCoordinatorMessage),
//   metrics: Subject(MetricsMessage),
// ) -> Result(actor.StartResult(UserSimulatorMessage), actor.StartError) {
//   let initial_state =
//     UserSimulatorState(
//       user_id: option.None,
//       username: username,
//       is_online: False,
//       joined_subreddits: [],
//       my_posts: [],
//       my_comments: [],
//       user_registry: user_registry,
//       subreddit_manager: subreddit_manager,
//       post_manager: post_manager,
//       comment_manager: comment_manager,
//       dm_manager: dm_manager,
//       activity_coordinator: activity_coordinator,
//       metrics: metrics,
//     )
//   actor.start(initial_state, handle_message)
// }

// fn handle_message(
//   message: UserSimulatorMessage,
//   state: UserSimulatorState,
// ) -> actor.Next(UserSimulatorMessage, UserSimulatorState) {
//   case message {
//     Initialize -> {
//       let new_state = initialize_user(state)
//       actor.continue(new_state)
//     }

//     PerformActivity -> {
//       let new_state = perform_activity(state)
//       actor.continue(new_state)
//     }

//     GoOnline -> {
//       let new_state = go_online(state)
//       actor.continue(new_state)
//     }

//     GoOffline -> {
//       let new_state = go_offline(state)
//       actor.continue(new_state)
//     }

//     Shutdown -> {
//       actor.Stop(process.Normal)
//     }
//   }
// }

// fn initialize_user(state: UserSimulatorState) -> UserSimulatorState {
//   // Register the user
//   let result =
//     actor.call(
//       state.user_registry,
//       protocol.RegisterUser(state.username, _),
//       5000,
//     )

//   case result {
//     types.RegistrationSuccess(user) -> {
//       actor.send(state.metrics, metrics_collector.RecordMetric(metrics_collector.UserRegistered))
//       UserSimulatorState(
//         ..state,
//         user_id: option.Some(user.id),
//         is_online: True,
//       )
//     }
//     _ -> state
//   }
// }

// fn perform_activity(state: UserSimulatorState) -> UserSimulatorState {
//   case state.is_online, state.user_id {
//     True, option.Some(user_id) -> {
//       // Get activity type from coordinator
//       let activity_type =
//         actor.call(
//           state.activity_coordinator,
//           activity_coordinator.GetActivityType,
//           5000,
//         )

//       case activity_type {
//         activity_coordinator.CreatePost -> create_post(state, user_id)
//         activity_coordinator.CreateComment -> create_comment(state, user_id)
//         activity_coordinator.CastVote -> cast_vote(state, user_id)
//         activity_coordinator.SendDirectMessage -> send_dm(state, user_id)
//         activity_coordinator.JoinSubreddit -> join_subreddit(state, user_id)
//       }
//     }
//     _, _ -> state
//   }
// }

// fn create_post(
//   state: UserSimulatorState,
//   user_id: UserId,
// ) -> UserSimulatorState {
//   // Get a subreddit to post in
//   let subreddit_id =
//     actor.call(
//       state.activity_coordinator,
//       activity_coordinator.GetSubredditForActivity,
//       5000,
//     )

//   let title = "Post by " <> state.username <> " at " <> int.to_string(get_timestamp())
//   let content = "This is a simulated post content."

//   let result =
//     actor.call(
//       state.post_manager,
//       protocol.CreatePost(subreddit_id, user_id, title, content, _),
//       5000,
//     )

//   case result {
//     types.PostSuccess(post) -> {
//       actor.send(state.metrics, metrics_collector.RecordMetric(metrics_collector.PostCreated))
//       UserSimulatorState(..state, my_posts: [post.id, ..state.my_posts])
//     }
//     _ -> state
//   }
// }

// fn create_comment(
//   state: UserSimulatorState,
//   user_id: UserId,
// ) -> UserSimulatorState {
//   // Try to comment on one of our posts or a random post
//   case list.first(state.my_posts) {
//     Ok(post_id) -> {
//       let content = "Comment by " <> state.username
//       let result =
//         actor.call(
//           state.comment_manager,
//           protocol.CreateComment(post_id, user_id, content, option.None, _),
//           5000,
//         )

//       case result {
//         types.CommentSuccess(comment) -> {
//           actor.send(state.metrics, metrics_collector.RecordMetric(metrics_collector.CommentCreated))
//           UserSimulatorState(..state, my_comments: [comment.id, ..state.my_comments])
//         }
//         _ -> state
//       }
//     }
//     Error(_) -> state
//   }
// }

// fn cast_vote(state: UserSimulatorState, user_id: UserId) -> UserSimulatorState {
//   // Vote on one of our posts
//   case list.first(state.my_posts) {
//     Ok(post_id) -> {
//       let _ =
//         actor.call(
//           state.post_manager,
//           protocol.VotePost(post_id, user_id, types.Upvote, _),
//           5000,
//         )
//       actor.send(state.metrics, metrics_collector.RecordMetric(metrics_collector.VoteCast))
//       state
//     }
//     Error(_) -> state
//   }
// }

// fn send_dm(state: UserSimulatorState, user_id: UserId) -> UserSimulatorState {
//   // For now, skip DM sending as we'd need another user
//   state
// }

// fn join_subreddit(
//   state: UserSimulatorState,
//   user_id: UserId,
// ) -> UserSimulatorState {
//   // Get a subreddit to join
//   let subreddit_id =
//     actor.call(
//       state.activity_coordinator,
//       activity_coordinator.GetSubredditForActivity,
//       5000,
//     )

//   // Check if already joined
//   case list.contains(state.joined_subreddits, subreddit_id) {
//     True -> state
//     False -> {
//       let _ =
//         actor.call(
//           state.subreddit_manager,
//           protocol.JoinSubreddit(subreddit_id, user_id, _),
//           5000,
//         )
//       let _ =
//         actor.call(
//           state.user_registry,
//           protocol.AddSubredditToUser(user_id, subreddit_id, _),
//           5000,
//         )
      
//       actor.send(state.metrics, metrics_collector.RecordMetric(metrics_collector.SubredditJoined))
//       UserSimulatorState(
//         ..state,
//         joined_subreddits: [subreddit_id, ..state.joined_subreddits],
//       )
//     }
//   }
// }

// fn go_online(state: UserSimulatorState) -> UserSimulatorState {
//   case state.user_id {
//     option.Some(user_id) -> {
//       let _ =
//         actor.call(
//           state.user_registry,
//           protocol.UpdateUserOnlineStatus(user_id, True, _),
//           5000,
//         )
//       UserSimulatorState(..state, is_online: True)
//     }
//     option.None -> state
//   }
// }

// fn go_offline(state: UserSimulatorState) -> UserSimulatorState {
//   case state.user_id {
//     option.Some(user_id) -> {
//       let _ =
//         actor.call(
//           state.user_registry,
//           protocol.UpdateUserOnlineStatus(user_id, False, _),
//           5000,
//         )
//       UserSimulatorState(..state, is_online: False)
//     }
//     option.None -> state
//   }
// }

// fn get_timestamp() -> Int {
//   process.system_time()
//   |> int.divide(1_000_000)
//   |> result.unwrap(0)
// }

