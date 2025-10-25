// import gleam/dict.{type Dict}
// import gleam/erlang/process
// import gleam/int
// import gleam/list
// import gleam/otp/actor
// import gleam/result
// import gleam/string
// import reddit/protocol.{type SubredditManagerMessage}
// import reddit/types.{
//   type Subreddit, type SubredditId, type SubredditResult, type UserId,
//   Subreddit as SubredditType, SubredditAlreadyExists, SubredditError,
//   SubredditNotFound, SubredditSuccess,
// }

// pub type State {
//   State(
//     subreddits: Dict(SubredditId, Subreddit),
//     name_to_id: Dict(String, SubredditId),
//     next_id: Int,
//   )
// }

// pub fn start() -> Result(actor.StartResult(SubredditManagerMessage), actor.StartError) {
//   let initial_state = State(subreddits: dict.new(), name_to_id: dict.new(), next_id: 1)
//   actor.start(initial_state, handle_message)
// }

// fn handle_message(
//   message: SubredditManagerMessage,
//   state: State,
// ) -> actor.Next(SubredditManagerMessage, State) {
//   case message {
//     protocol.CreateSubreddit(name, description, creator_id, reply) -> {
//       let #(result, new_state) = create_subreddit(state, name, description, creator_id)
//       actor.send(reply, result)
//       actor.continue(new_state)
//     }

//     protocol.GetSubreddit(subreddit_id, reply) -> {
//       let result = get_subreddit(state, subreddit_id)
//       actor.send(reply, result)
//       actor.continue(state)
//     }

//     protocol.GetSubredditByName(name, reply) -> {
//       let result = get_subreddit_by_name(state, name)
//       actor.send(reply, result)
//       actor.continue(state)
//     }

//     protocol.JoinSubreddit(subreddit_id, user_id, reply) -> {
//       let #(result, new_state) = join_subreddit(state, subreddit_id, user_id)
//       actor.send(reply, result)
//       actor.continue(new_state)
//     }

//     protocol.LeaveSubreddit(subreddit_id, user_id, reply) -> {
//       let #(result, new_state) = leave_subreddit(state, subreddit_id, user_id)
//       actor.send(reply, result)
//       actor.continue(new_state)
//     }

//     protocol.ListAllSubreddits(reply) -> {
//       let all_subreddits = list_all_subreddits(state)
//       actor.send(reply, all_subreddits)
//       actor.continue(state)
//     }
//   }
// }

// fn create_subreddit(
//   state: State,
//   name: String,
//   description: String,
//   creator_id: UserId,
// ) -> #(SubredditResult, State) {
//   // Validate name
//   case string.trim(name) {
//     "" -> #(SubredditError("Subreddit name cannot be empty"), state)
//     trimmed_name -> {
//       // Check if subreddit name already exists
//       case dict.get(state.name_to_id, trimmed_name) {
//         Ok(_) -> #(SubredditAlreadyExists, state)
//         Error(_) -> {
//           // Create new subreddit
//           let subreddit_id = "sub_" <> int.to_string(state.next_id)
//           let timestamp = get_timestamp()
//           let new_subreddit =
//             SubredditType(
//               id: subreddit_id,
//               name: trimmed_name,
//               description: description,
//               creator_id: creator_id,
//               members: [creator_id],
//               member_count: 1,
//               created_at: timestamp,
//             )

//           // Update state
//           let new_subreddits =
//             dict.insert(state.subreddits, subreddit_id, new_subreddit)
//           let new_name_map =
//             dict.insert(state.name_to_id, trimmed_name, subreddit_id)
//           let new_state =
//             State(
//               subreddits: new_subreddits,
//               name_to_id: new_name_map,
//               next_id: state.next_id + 1,
//             )

//           #(SubredditSuccess(new_subreddit), new_state)
//         }
//       }
//     }
//   }
// }

// fn get_subreddit(state: State, subreddit_id: SubredditId) -> SubredditResult {
//   case dict.get(state.subreddits, subreddit_id) {
//     Ok(subreddit) -> SubredditSuccess(subreddit)
//     Error(_) -> SubredditNotFound
//   }
// }

// fn get_subreddit_by_name(state: State, name: String) -> SubredditResult {
//   case dict.get(state.name_to_id, name) {
//     Ok(subreddit_id) -> get_subreddit(state, subreddit_id)
//     Error(_) -> SubredditNotFound
//   }
// }

// fn join_subreddit(
//   state: State,
//   subreddit_id: SubredditId,
//   user_id: UserId,
// ) -> #(Result(Nil, String), State) {
//   case dict.get(state.subreddits, subreddit_id) {
//     Ok(subreddit) -> {
//       // Check if user is already a member
//       case list.contains(subreddit.members, user_id) {
//         True -> #(Error("User is already a member of this subreddit"), state)
//         False -> {
//           let updated_members = [user_id, ..subreddit.members]
//           let updated_subreddit =
//             SubredditType(
//               ..subreddit,
//               members: updated_members,
//               member_count: subreddit.member_count + 1,
//             )
//           let new_subreddits =
//             dict.insert(state.subreddits, subreddit_id, updated_subreddit)
//           let new_state = State(..state, subreddits: new_subreddits)
//           #(Ok(Nil), new_state)
//         }
//       }
//     }
//     Error(_) -> #(Error("Subreddit not found"), state)
//   }
// }

// fn leave_subreddit(
//   state: State,
//   subreddit_id: SubredditId,
//   user_id: UserId,
// ) -> #(Result(Nil, String), State) {
//   case dict.get(state.subreddits, subreddit_id) {
//     Ok(subreddit) -> {
//       // Check if user is a member
//       case list.contains(subreddit.members, user_id) {
//         False -> #(Error("User is not a member of this subreddit"), state)
//         True -> {
//           let updated_members = list.filter(subreddit.members, fn(id) { id != user_id })
//           let updated_subreddit =
//             SubredditType(
//               ..subreddit,
//               members: updated_members,
//               member_count: subreddit.member_count - 1,
//             )
//           let new_subreddits =
//             dict.insert(state.subreddits, subreddit_id, updated_subreddit)
//           let new_state = State(..state, subreddits: new_subreddits)
//           #(Ok(Nil), new_state)
//         }
//       }
//     }
//     Error(_) -> #(Error("Subreddit not found"), state)
//   }
// }

// fn list_all_subreddits(state: State) -> List(Subreddit) {
//   dict.values(state.subreddits)
// }

// // Helper functions
// fn get_timestamp() -> Int {
//   process.system_time()
//   |> int.divide(1_000_000)
//   |> result.unwrap(0)
// }

