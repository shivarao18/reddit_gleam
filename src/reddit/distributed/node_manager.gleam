// Node Manager - High-level distributed node management
// Provides easy-to-use functions for setting up distributed Erlang nodes

import gleam/erlang/atom
import gleam/erlang/process.{type Pid, type Subject}
import gleam/int
import gleam/io
import gleam/result
import reddit/distributed/erlang_ffi

pub type NodeType {
  EngineNode
  ClientNode(client_id: Int)
}

pub type ConnectionError {
  NodeStartFailed(reason: String)
  NodeConnectionFailed(reason: String)
  RegistrationFailed(reason: String)
  LookupFailed(reason: String)
}

const cookie = "reddit_distributed_secret_2024"

/// Initialize this node for distributed communication
pub fn init_node(node_type: NodeType) -> Result(String, ConnectionError) {
  // Check if node is already started (via erl -name flag)
  let current = erlang_ffi.get_current_node_name()
  
  case current {
    // Already distributed (started with erl -name)
    name if name != "nonode@nohost" -> {
      io.println("✓ Using existing distributed node: " <> name)
      Ok(name)
    }
    // Not distributed, need to start
    _ -> {
      let node_name = case node_type {
        EngineNode -> "engine"
        ClientNode(id) -> "client" <> int.to_string(id)
      }
      
      case erlang_ffi.start_node(node_name, "shortnames") {
        Ok(_pid) -> {
          // Set cookie AFTER node is started
          let _cookie_set = erlang_ffi.set_cookie(cookie)
          
          let full_name = erlang_ffi.get_current_node_name()
          io.println("✓ Started distributed node: " <> full_name)
          Ok(full_name)
        }
        Error(reason) -> {
          io.println("❌ Failed to start node: " <> reason)
          Error(NodeStartFailed(reason))
        }
      }
    }
  }
}

/// Connect to the engine node
pub fn connect_to_engine() -> Result(Nil, ConnectionError) {
  // Use 127.0.0.1 to match the erl -name flags
  let engine_node = "engine@127.0.0.1"
  
  io.println("Connecting to engine node: " <> engine_node)
  
  case erlang_ffi.connect_to_node(engine_node) {
    Ok(_) -> {
      io.println("✓ Connected to engine node")
      Ok(Nil)
    }
    Error(reason) -> {
      io.println("❌ Failed to connect to engine: " <> reason)
      Error(NodeConnectionFailed(reason))
    }
  }
}

/// Check if engine node is reachable
pub fn is_engine_alive() -> Bool {
  // Use 127.0.0.1 to match the erl -name flags
  let engine_node = "engine@127.0.0.1"
  
  case erlang_ffi.connect_to_node(engine_node) {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Register a subject globally
pub fn register_global(
  name: String,
  subject: Subject(a),
) -> Result(Nil, ConnectionError) {
  let pid = erlang_ffi.subject_to_pid(subject)
  
  case erlang_ffi.register_global_pid(name, pid) {
    Ok(_) -> {
      io.println("✓ Registered globally: " <> name)
      Ok(Nil)
    }
    Error(reason) -> {
      io.println("❌ Failed to register: " <> reason)
      Error(RegistrationFailed(reason))
    }
  }
}

/// Look up a globally registered subject
pub fn lookup_global(name: String) -> Result(Subject(a), ConnectionError) {
  case erlang_ffi.whereis_global(name) {
    Ok(pid) -> {
      // Convert Pid back to Subject
      let subject = pid_to_subject(pid)
      Ok(subject)
    }
    Error(reason) -> {
      Error(LookupFailed(reason))
    }
  }
}

/// Retry lookup with multiple attempts
pub fn lookup_global_with_retry(
  name: String,
  max_attempts: Int,
) -> Result(Subject(a), ConnectionError) {
  lookup_global_retry_loop(name, max_attempts, 0)
}

fn lookup_global_retry_loop(
  name: String,
  max_attempts: Int,
  current_attempt: Int,
) -> Result(Subject(a), ConnectionError) {
  case current_attempt >= max_attempts {
    True -> Error(LookupFailed("Max retry attempts reached for: " <> name))
    False -> {
      case lookup_global(name) {
        Ok(subject) -> Ok(subject)
        Error(_) -> {
          // Wait a bit before retrying
          process.sleep(500)
          lookup_global_retry_loop(name, max_attempts, current_attempt + 1)
        }
      }
    }
  }
}

/// Get list of connected nodes
pub fn get_connected_nodes() -> List(String) {
  erlang_ffi.get_connected_nodes()
}

/// Unregister a global name (cleanup)
pub fn unregister_global(name: String) -> Nil {
  erlang_ffi.unregister_global(name)
}

// Helper: Convert Pid to Subject
@external(erlang, "gleam_erlang_ffi", "new_selector")
fn create_selector() -> process.Selector(a)

fn pid_to_subject(pid: Pid) -> Subject(a) {
  // This is a workaround - in production you'd want proper FFI
  // For now, we create a subject that wraps the pid
  unsafe_pid_to_subject(pid)
}

@external(erlang, "reddit_distributed_ffi", "pid_to_subject")
fn unsafe_pid_to_subject(pid: Pid) -> Subject(a)

// Helper: Get hostname
@external(erlang, "inet", "gethostname")
fn get_hostname_tuple() -> #(atom.Atom, String)

fn get_hostname() -> String {
  let #(_ok, hostname) = get_hostname_tuple()
  hostname
}

