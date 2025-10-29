// Reddit Clone - Entry point
// This is the main entry point for the application that starts the Reddit simulator.

import gleam/io
import reddit_simulator

pub fn main() -> Nil {
  io.println("=== Reddit Clone - Part I ===")
  io.println("")
  io.println("By default, running the integrated simulator...")
  io.println("(The engine actors are started within the simulator)")
  io.println("")
  
  reddit_simulator.main()
}
