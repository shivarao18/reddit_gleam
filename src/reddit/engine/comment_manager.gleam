// import gleam/dict.{type Dict}
// import gleam/erlang/process
// import gleam/int
// import gleam/list
// import gleam/option.{type Option}
// import gleam/otp/actor
// import gleam/result
// import gleam/string
// import reddit/protocol.{type CommentManagerMessage}
// import reddit/types.{
//   type Comment, type CommentId, type CommentResult, type PostId, type UserId,
//   type VoteType, Comment as CommentType, CommentError, CommentNotFound,
//   CommentSuccess,
// }

// pub type State {
//   State(
//     comments: Dict(CommentId, Comment),
//     comments_by_post: Dict(PostId, List(CommentId)),
//     comment_votes: Dict(CommentId, Dict(UserId, VoteType)),
//     next_id: Int,
//   )
// }

// pub fn start() -> Result(actor.StartResult(CommentManagerMessage), actor.StartError) {
//   let initial_state =
//     State(
//       comments: dict.new(),
//       comments_by_post: dict.new(),
//       comment_votes: dict.new(),
//       next_id: 1,
//     )
//   actor.start(initial_state, handle_message)
// }

// fn handle_message(
//   message: CommentManagerMessage,
//   state: State,
// ) -> actor.Next(CommentManagerMessage, State) {
//   case message {
//     protocol.CreateComment(post_id, author_id, content, parent_id, reply) -> {
//       let #(result, new_state) = create_comment(state, post_id, author_id, content, parent_id)
//       actor.send(reply, result)
//       actor.continue(new_state)
//     }

//     protocol.GetComment(comment_id, reply) -> {
//       let result = get_comment(state, comment_id)
//       actor.send(reply, result)
//       actor.continue(state)
//     }

//     protocol.GetCommentsByPost(post_id, reply) -> {
//       let comments = get_comments_by_post(state, post_id)
//       actor.send(reply, comments)
//       actor.continue(state)
//     }

//     protocol.VoteComment(comment_id, user_id, vote_type, reply) -> {
//       let #(result, new_state) = vote_comment(state, comment_id, user_id, vote_type)
//       actor.send(reply, result)
//       actor.continue(new_state)
//     }
//   }
// }

// fn create_comment(
//   state: State,
//   post_id: PostId,
//   author_id: UserId,
//   content: String,
//   parent_id: Option(CommentId),
// ) -> #(CommentResult, State) {
//   case string.trim(content) {
//     "" -> #(CommentError("Comment content cannot be empty"), state)
//     trimmed_content -> {
//       // If parent_id is provided, verify it exists
//       let parent_valid = case parent_id {
//         option.None -> Ok(Nil)
//         option.Some(pid) ->
//           case dict.get(state.comments, pid) {
//             Ok(_) -> Ok(Nil)
//             Error(_) -> Error("Parent comment not found")
//           }
//       }

//       case parent_valid {
//         Error(err) -> #(CommentError(err), state)
//         Ok(_) -> {
//           // Create new comment
//           let comment_id = "comment_" <> int.to_string(state.next_id)
//           let timestamp = get_timestamp()
//           let new_comment =
//             CommentType(
//               id: comment_id,
//               post_id: post_id,
//               parent_id: parent_id,
//               author_id: author_id,
//               content: trimmed_content,
//               upvotes: 0,
//               downvotes: 0,
//               created_at: timestamp,
//             )

//           // Update comments dict
//           let new_comments = dict.insert(state.comments, comment_id, new_comment)

//           // Update comments_by_post
//           let existing_comments =
//             dict.get(state.comments_by_post, post_id)
//             |> result.unwrap([])
//           let updated_post_comments = [comment_id, ..existing_comments]
//           let new_comments_by_post =
//             dict.insert(state.comments_by_post, post_id, updated_post_comments)

//           // Initialize empty votes dict for this comment
//           let new_comment_votes = dict.insert(state.comment_votes, comment_id, dict.new())

//           let new_state =
//             State(
//               comments: new_comments,
//               comments_by_post: new_comments_by_post,
//               comment_votes: new_comment_votes,
//               next_id: state.next_id + 1,
//             )

//           #(CommentSuccess(new_comment), new_state)
//         }
//       }
//     }
//   }
// }

// fn get_comment(state: State, comment_id: CommentId) -> CommentResult {
//   case dict.get(state.comments, comment_id) {
//     Ok(comment) -> CommentSuccess(comment)
//     Error(_) -> CommentNotFound
//   }
// }

// fn get_comments_by_post(state: State, post_id: PostId) -> List(Comment) {
//   let comment_ids =
//     dict.get(state.comments_by_post, post_id)
//     |> result.unwrap([])

//   list.filter_map(comment_ids, fn(comment_id) {
//     dict.get(state.comments, comment_id)
//   })
// }

// fn vote_comment(
//   state: State,
//   comment_id: CommentId,
//   user_id: UserId,
//   vote_type: VoteType,
// ) -> #(Result(Nil, String), State) {
//   case dict.get(state.comments, comment_id) {
//     Error(_) -> #(Error("Comment not found"), state)
//     Ok(comment) -> {
//       let votes =
//         dict.get(state.comment_votes, comment_id)
//         |> result.unwrap(dict.new())

//       // Get previous vote if any
//       let previous_vote = dict.get(votes, user_id)

//       // Calculate vote changes
//       let #(upvote_delta, downvote_delta) = case previous_vote, vote_type {
//         Ok(types.Upvote), types.Upvote -> #(0, 0)
//         Ok(types.Downvote), types.Downvote -> #(0, 0)
//         Ok(types.Upvote), types.Downvote -> #(-1, 1)
//         Ok(types.Downvote), types.Upvote -> #(1, -1)
//         Error(_), types.Upvote -> #(1, 0)
//         Error(_), types.Downvote -> #(0, 1)
//       }

//       // Update comment
//       let updated_comment =
//         CommentType(
//           ..comment,
//           upvotes: comment.upvotes + upvote_delta,
//           downvotes: comment.downvotes + downvote_delta,
//         )
//       let new_comments = dict.insert(state.comments, comment_id, updated_comment)

//       // Update votes
//       let new_votes = dict.insert(votes, user_id, vote_type)
//       let new_comment_votes = dict.insert(state.comment_votes, comment_id, new_votes)

//       let new_state =
//         State(
//           ..state,
//           comments: new_comments,
//           comment_votes: new_comment_votes,
//         )

//       #(Ok(Nil), new_state)
//     }
//   }
// }

// // Helper functions
// fn get_timestamp() -> Int {
//   process.system_time()
//   |> int.divide(1_000_000)
//   |> result.unwrap(0)
// }

