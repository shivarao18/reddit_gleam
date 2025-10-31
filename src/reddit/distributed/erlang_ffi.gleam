// Erlang Distributed Node FFI Bindings
// This module provides Gleam bindings to Erlang's distributed node functionality

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid, type Subject}

// Node management

/// Start distributed mode with a short node name
/// Example: start_node("engine", "longlist") -> engine@hostname
@external(erlang, "net_kernel", "start")
pub fn start_node_ffi(name_list: List(Atom)) -> Result(Pid, Atom)

pub fn start_node(name: String, node_type: String) -> Result(Pid, String) {
  let name_atom = unsafe_string_to_atom(name)
  let type_atom = unsafe_string_to_atom(node_type)
  
  case start_node_ffi([name_atom, type_atom]) {
    Ok(pid) -> Ok(pid)
    Error(err) -> Error(atom.to_string(err))
  }
}

@external(erlang, "erlang", "binary_to_atom")
fn unsafe_string_to_atom(s: String) -> Atom

/// Set the Erlang cookie for authentication
@external(erlang, "erlang", "set_cookie")
pub fn set_cookie_ffi(node: Atom, cookie: Atom) -> Bool

pub fn set_cookie(cookie: String) -> Bool {
  let cookie_atom = unsafe_string_to_atom(cookie)
  set_cookie_ffi(unsafe_string_to_atom(""), cookie_atom)
}

/// Get current node name
@external(erlang, "erlang", "node")
pub fn current_node() -> Atom

pub fn get_current_node_name() -> String {
  current_node() |> atom.to_string()
}

// Node connectivity

/// Connect to another node (ping it)
@external(erlang, "net_adm", "ping")
pub fn ping_node_ffi(node: Atom) -> Atom

pub fn connect_to_node(node_name: String) -> Result(Nil, String) {
  let node_atom = unsafe_string_to_atom(node_name)
  let result = ping_node_ffi(node_atom)
  
  case atom.to_string(result) {
    "pong" -> Ok(Nil)
    _ -> Error("Failed to connect to node: " <> node_name)
  }
}

/// Get list of connected nodes
@external(erlang, "erlang", "nodes")
pub fn connected_nodes() -> List(Atom)

pub fn get_connected_nodes() -> List(String) {
  connected_nodes()
  |> list_atoms_to_strings()
}

// Global process registry

/// Register a process globally across all connected nodes
@external(erlang, "global", "register_name")
pub fn register_global_ffi(name: Atom, pid: Pid) -> Atom

pub fn register_global_pid(name: String, pid: Pid) -> Result(Nil, String) {
  let name_atom = unsafe_string_to_atom(name)
  let result = register_global_ffi(name_atom, pid)
  
  case atom.to_string(result) {
    "yes" -> Ok(Nil)
    "no" -> Error("Name already registered: " <> name)
    _ -> Error("Failed to register: " <> name)
  }
}

/// Look up a globally registered process
@external(erlang, "global", "whereis_name")
pub fn whereis_global_ffi(name: Atom) -> Dynamic

pub fn whereis_global(name: String) -> Result(Pid, String) {
  let name_atom = unsafe_string_to_atom(name)
  let result = whereis_global_ffi(name_atom)
  
  case dynamic.classify(result) {
    "Atom" -> Error("Process not found: " <> name)
    "Pid" -> Ok(unsafe_dynamic_to_pid(result))
    _ -> Error("Unexpected result for: " <> name)
  }
}

@external(erlang, "erlang", "list_to_pid")
fn unsafe_dynamic_to_pid(dynamic: Dynamic) -> Pid

/// Unregister a globally registered process
@external(erlang, "global", "unregister_name")
pub fn unregister_global_ffi(name: Atom) -> Atom

pub fn unregister_global(name: String) -> Nil {
  let name_atom = unsafe_string_to_atom(name)
  let _result = unregister_global_ffi(name_atom)
  Nil
}

// Helper to convert Subject to Pid (for registration)
@external(erlang, "gleam_erlang_ffi", "subject_owner")
pub fn subject_to_pid(subject: Subject(a)) -> Pid

// Helper functions

fn list_atoms_to_strings(atoms: List(Atom)) -> List(String) {
  case atoms {
    [] -> []
    [head, ..tail] -> [atom.to_string(head), ..list_atoms_to_strings(tail)]
  }
}

