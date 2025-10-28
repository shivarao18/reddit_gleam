import gleam/erlang/process.{type Subject, send}
import gleam/otp/actor
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
) -> actor.StartResult(Subject(KarmaCalculatorMessage)) {
  let initial_state =
    State(
      post_manager: post_manager,
      comment_manager: comment_manager,
      user_registry: user_registry,
    )
  
  let builder =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
  actor.start(builder)
}

fn handle_message(
  state: State,
  message: KarmaCalculatorMessage,
) -> actor.Next(State, KarmaCalculatorMessage) {
  case message {
    protocol.CalculateKarmaForUser(user_id, reply) -> {
      // For now, we return a placeholder
      // In a full implementation, this would query post and comment managers
      // to calculate total karma from upvotes and downvotes
      send(reply, 0)
      actor.continue(state)
    }

    protocol.RecalculateAllKarma(reply) -> {
      // Placeholder for recalculating all user karma
      send(reply, Ok(Nil))
      actor.continue(state)
    }
  }
}

// Helper to calculate karma from votes
pub fn calculate_karma_score(upvotes: Int, downvotes: Int) -> Int {
  upvotes - downvotes
}

