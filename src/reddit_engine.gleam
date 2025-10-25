// import gleam/erlang/process
// import gleam/io
// import gleam/otp/supervisor
// import reddit/engine/supervisor as engine_supervisor

// pub fn main() {
//   io.println("=== Reddit Clone Engine ===")
//   io.println("Starting engine...")

//   case engine_supervisor.start() {
//     Ok(supervisor) -> {
//       io.println("✓ Engine started successfully!")
//       io.println("Engine is running. Press Ctrl+C to stop.")
      
//       // Keep the main process alive
//       process.sleep_forever()
//     }
//     Error(error) -> {
//       io.println("✗ Failed to start engine:")
//       io.debug(error)
//       process.exit(1)
//     }
//   }
// }

