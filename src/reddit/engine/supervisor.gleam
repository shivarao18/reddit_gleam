import gleam/otp/supervisor.{type Children, type Supervisor}
import gleam/io
import reddit/engine/user_registry
import reddit/engine/subreddit_manager
import reddit/engine/post_manager
import reddit/engine/comment_manager
import reddit/engine/dm_manager
import reddit/engine/karma_calculator
import reddit/engine/feed_generator

pub fn start() -> Result(Supervisor, supervisor.StartError) {
  io.println("Starting Reddit Engine Supervisor...")
  
  supervisor.start(fn(children) {
    children
    |> supervisor.add(supervisor.worker(user_registry.start))
    |> supervisor.add(supervisor.worker(subreddit_manager.start))
    |> supervisor.add(supervisor.worker(post_manager.start))
    |> supervisor.add(supervisor.worker(comment_manager.start))
    |> supervisor.add(supervisor.worker(dm_manager.start))
    // Note: karma_calculator and feed_generator need references to other actors
    // They will be started after we can get the subjects
  })
}

pub fn start_linked() -> Result(Supervisor, supervisor.StartError) {
  start()
}

