import gleam/otp/actor.{type Subject}
import gleam/erlang/process
import reddit/protocol.{
  type KarmaCalculatorMessage, type PostManagerMessage, type CommentManagerMessage,
  type UserRegistryMessage,
}
import reddit/types.{type UserId}

pub type State {
  State(
    post_manager: Subject(PostManagerMessage),
    comment_manager: Subject(CommentManagerMessage),
    user_registry: Subject(UserRegistryMessage),
  )
}

pub fn start(
  post_manager: Subject(PostManagerMessage),
  comment_manager: Subject(CommentManagerMessage),
  user_registry: Subject(UserRegistryMessage),
) -> Result(actor.StartResult(KarmaCalculatorMessage), actor.StartError) {
  let initial_state =
    State(
      post_manager: post_manager,
      comment_manager: comment_manager,
      user_registry: user_registry,
    )
  actor.start(initial_state, handle_message)
}

fn handle_message(
  message: KarmaCalculatorMessage,
  state: State,
) -> actor.Next(KarmaCalculatorMessage, State) {
  case message {
    protocol.CalculateKarmaForUser(user_id, reply) -> {
      // For now, we return a placeholder
      // In a full implementation, this would query post and comment managers
      // to calculate total karma from upvotes and downvotes
      actor.send(reply, 0)
      actor.continue(state)
    }

    protocol.RecalculateAllKarma(reply) -> {
      // Placeholder for recalculating all user karma
      actor.send(reply, Ok(Nil))
      actor.continue(state)
    }
  }
}

// Helper to calculate karma from votes
pub fn calculate_karma_score(upvotes: Int, downvotes: Int) -> Int {
  upvotes - downvotes
}

