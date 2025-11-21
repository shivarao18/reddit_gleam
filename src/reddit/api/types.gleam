// API Types - Request/Response types and helper functions
// This module provides common types and utilities for the REST API

import gleam/bytes_tree
import gleam/dynamic.{type Dynamic}
import gleam/http/response.{type Response}
import gleam/json.{type Json}
import gleam/list
import gleam/result
import gleam/string
import mist

/// Standard API response with success flag and data
pub type ApiResponse(data) {
  ApiResponse(success: Bool, data: data)
}

/// Error response structure
pub type ErrorResponse {
  ErrorResponse(error: String, message: String)
}

/// Helper to create a JSON response
pub fn json_response(
  body: json.Json,
  status: Int,
) -> Response(mist.ResponseData) {
  response.new(status)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(json.to_string(body))))
  |> response.prepend_header("content-type", "application/json")
}

/// Helper to create a success response
pub fn success_response(data: json.Json) -> Response(mist.ResponseData) {
  let body =
    json.object([#("success", json.bool(True)), #("data", data)])
  
  json_response(body, 200)
}

/// Helper to create an error response
pub fn error_response(
  error: String,
  message: String,
  status: Int,
) -> Response(mist.ResponseData) {
  let body =
    json.object([
      #("success", json.bool(False)),
      #("error", json.string(error)),
      #("message", json.string(message)),
    ])
  
  json_response(body, status)
}

/// Helper to create a 400 Bad Request response
pub fn bad_request(message: String) -> Response(mist.ResponseData) {
  error_response("BadRequest", message, 400)
}

/// Helper to create a 404 Not Found response
pub fn not_found(message: String) -> Response(mist.ResponseData) {
  error_response("NotFound", message, 404)
}

/// Helper to create a 409 Conflict response
pub fn conflict(message: String) -> Response(mist.ResponseData) {
  error_response("Conflict", message, 409)
}

/// Helper to create a 500 Internal Server Error response
pub fn internal_error(message: String) -> Response(mist.ResponseData) {
  error_response("InternalError", message, 500)
}

/// Helper to create a 201 Created response
pub fn created(data: json.Json) -> Response(mist.ResponseData) {
  let body =
    json.object([#("success", json.bool(True)), #("data", data)])
  
  json_response(body, 201)
}

/// Extract a string field from JSON string using simple parsing
/// This is a simple JSON field extractor for basic use cases
pub fn extract_json_string_field(
  json_string: String,
  field: String,
) -> Result(String, String) {
  // Look for "field": "value" pattern
  let pattern = "\"" <> field <> "\":" 
  
  case string.split(json_string, pattern) {
    [_, rest, ..] -> {
      // Find the value after the colon
      let trimmed = string.trim(rest)
      case string.starts_with(trimmed, "\"") {
        True -> {
          // Extract string value between quotes
          let without_first_quote = string.drop_start(trimmed, 1)
          case string.split(without_first_quote, "\"") {
            [value, ..] -> Ok(value)
            _ -> Error("Could not parse field value: " <> field)
          }
        }
        False -> Error("Field is not a string: " <> field)
      }
    }
    _ -> Error("Field not found: " <> field)
  }
}

