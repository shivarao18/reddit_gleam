import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string

pub type MetricType {
  PostCreated
  CommentCreated
  VoteCast
  SubredditJoined
  DirectMessageSent
  UserRegistered
}

pub type OperationLatency {
  OperationLatency(
    operation: String,
    duration_ms: Int,
  )
}

pub type State {
  State(
    operation_counts: Dict(String, Int),
    total_operations: Int,
    latencies: List(OperationLatency),
    start_time: Int,
    active_users: Int,
  )
}

pub type MetricsMessage {
  RecordMetric(metric_type: MetricType)
  RecordLatency(operation: String, duration_ms: Int)
  SetActiveUsers(count: Int)
  GetReport(reply: actor.Subject(MetricsReport))
  Reset
}

pub type MetricsReport {
  MetricsReport(
    total_operations: Int,
    operation_counts: Dict(String, Int),
    operations_per_second: Float,
    average_latency_ms: Float,
    active_users: Int,
    runtime_seconds: Int,
  )
}

pub fn start() -> Result(actor.StartResult(MetricsMessage), actor.StartError) {
  let timestamp = get_timestamp()
  let initial_state =
    State(
      operation_counts: dict.new(),
      total_operations: 0,
      latencies: [],
      start_time: timestamp,
      active_users: 0,
    )
  actor.start(initial_state, handle_message)
}

fn handle_message(
  message: MetricsMessage,
  state: State,
) -> actor.Next(MetricsMessage, State) {
  case message {
    RecordMetric(metric_type) -> {
      let metric_name = metric_type_to_string(metric_type)
      let current_count =
        dict.get(state.operation_counts, metric_name)
        |> result.unwrap(0)
      let new_counts =
        dict.insert(state.operation_counts, metric_name, current_count + 1)
      let new_state =
        State(
          ..state,
          operation_counts: new_counts,
          total_operations: state.total_operations + 1,
        )
      actor.continue(new_state)
    }

    RecordLatency(operation, duration_ms) -> {
      let latency = OperationLatency(operation, duration_ms)
      let new_latencies = [latency, ..state.latencies]
      // Keep only last 1000 latencies to avoid memory issues
      let trimmed_latencies = list.take(new_latencies, 1000)
      let new_state = State(..state, latencies: trimmed_latencies)
      actor.continue(new_state)
    }

    SetActiveUsers(count) -> {
      let new_state = State(..state, active_users: count)
      actor.continue(new_state)
    }

    GetReport(reply) -> {
      let report = generate_report(state)
      actor.send(reply, report)
      actor.continue(state)
    }

    Reset -> {
      let timestamp = get_timestamp()
      let new_state =
        State(
          operation_counts: dict.new(),
          total_operations: 0,
          latencies: [],
          start_time: timestamp,
          active_users: 0,
        )
      actor.continue(new_state)
    }
  }
}

fn generate_report(state: State) -> MetricsReport {
  let current_time = get_timestamp()
  let runtime_seconds = current_time - state.start_time

  let operations_per_second = case runtime_seconds > 0 {
    True -> int.to_float(state.total_operations) /. int.to_float(runtime_seconds)
    False -> 0.0
  }

  let average_latency = case list.length(state.latencies) {
    0 -> 0.0
    count -> {
      let total_latency =
        list.fold(state.latencies, 0, fn(acc, lat) { acc + lat.duration_ms })
      int.to_float(total_latency) /. int.to_float(count)
    }
  }

  MetricsReport(
    total_operations: state.total_operations,
    operation_counts: state.operation_counts,
    operations_per_second: operations_per_second,
    average_latency_ms: average_latency,
    active_users: state.active_users,
    runtime_seconds: runtime_seconds,
  )
}

pub fn print_report(report: MetricsReport) -> Nil {
  io.println("\n=== Performance Metrics Report ===")
  io.println("Runtime: " <> int.to_string(report.runtime_seconds) <> " seconds")
  io.println("Active Users: " <> int.to_string(report.active_users))
  io.println("Total Operations: " <> int.to_string(report.total_operations))
  io.println("Operations/Second: " <> float.to_string(report.operations_per_second))
  io.println("Average Latency: " <> float.to_string(report.average_latency_ms) <> " ms")
  
  io.println("\nOperation Breakdown:")
  dict.fold(report.operation_counts, Nil, fn(_, operation, count) {
    io.println("  " <> operation <> ": " <> int.to_string(count))
  })
  
  io.println("==================================\n")
}

fn metric_type_to_string(metric_type: MetricType) -> String {
  case metric_type {
    PostCreated -> "posts_created"
    CommentCreated -> "comments_created"
    VoteCast -> "votes_cast"
    SubredditJoined -> "subreddits_joined"
    DirectMessageSent -> "direct_messages_sent"
    UserRegistered -> "users_registered"
  }
}

fn get_timestamp() -> Int {
  process.system_time()
  |> int.divide(1_000_000)
  |> result.unwrap(0)
}

