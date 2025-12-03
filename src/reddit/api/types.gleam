// API Types - Request/Response types and helper functions
// This module provides common types and utilities for the REST API

import gleam/bytes_tree
import gleam/dynamic.{type Dynamic}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mist
import reddit/crypto/types as crypto_types

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
  let body = json.object([#("success", json.bool(True)), #("data", data)])

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
  let body = json.object([#("success", json.bool(True)), #("data", data)])

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

// ===== Crypto JSON Encoding/Decoding Functions =====

/// Convert KeyAlgorithm to JSON string
pub fn key_algorithm_to_string(alg: crypto_types.KeyAlgorithm) -> String {
  case alg {
    crypto_types.RSA2048 -> "RSA2048"
    crypto_types.ECDSAP256 -> "ECDSAP256"
  }
}

/// Parse KeyAlgorithm from string
pub fn string_to_key_algorithm(
  s: String,
) -> Result(crypto_types.KeyAlgorithm, String) {
  case s {
    "RSA2048" -> Ok(crypto_types.RSA2048)
    "ECDSAP256" -> Ok(crypto_types.ECDSAP256)
    _ ->
      Error("Invalid key algorithm: " <> s <> ". Must be RSA2048 or ECDSAP256")
  }
}

/// Encode PublicKey to JSON object
pub fn public_key_to_json(pk: crypto_types.PublicKey) -> json.Json {
  json.object([
    #("algorithm", json.string(key_algorithm_to_string(pk.algorithm))),
    #("key_data", json.string(pk.key_data)),
  ])
}

/// Encode optional PublicKey to JSON (None becomes null)
pub fn optional_public_key_to_json(
  pk: option.Option(crypto_types.PublicKey),
) -> json.Json {
  case pk {
    option.Some(key) -> public_key_to_json(key)
    option.None -> json.null()
  }
}

/// Encode DigitalSignature to JSON object
pub fn signature_to_json(sig: crypto_types.DigitalSignature) -> json.Json {
  json.object([
    #("signature_data", json.string(sig.signature_data)),
    #("algorithm", json.string(key_algorithm_to_string(sig.algorithm))),
    #("signed_at", json.int(sig.signed_at)),
  ])
}

/// Encode optional DigitalSignature to JSON
pub fn optional_signature_to_json(
  sig: option.Option(crypto_types.DigitalSignature),
) -> json.Json {
  case sig {
    option.Some(s) -> signature_to_json(s)
    option.None -> json.null()
  }
}

/// Parse optional public key from JSON string fields
/// Expects: "public_key" and "key_algorithm" fields in JSON
pub fn parse_optional_public_key_from_json(
  json_string: String,
) -> option.Option(crypto_types.PublicKey) {
  case extract_json_string_field(json_string, "public_key") {
    Error(_) -> option.None
    Ok(key_data) -> {
      case extract_json_string_field(json_string, "key_algorithm") {
        Error(_) -> option.None
        Ok(alg_str) -> {
          case string_to_key_algorithm(alg_str) {
            Error(_) -> option.None
            Ok(algorithm) -> {
              option.Some(crypto_types.PublicKey(
                algorithm: algorithm,
                key_data: key_data,
              ))
            }
          }
        }
      }
    }
  }
}

/// Parse optional signature from JSON string fields
/// Expects: "signature_data", "signature_algorithm", and "signature_timestamp" fields
pub fn parse_optional_signature_from_json(
  json_string: String,
) -> option.Option(crypto_types.DigitalSignature) {
  case extract_json_string_field(json_string, "signature_data") {
    Error(_) -> option.None
    Ok(sig_data) -> {
      case extract_json_string_field(json_string, "signature_algorithm") {
        Error(_) -> option.None
        Ok(alg_str) -> {
          case string_to_key_algorithm(alg_str) {
            Error(_) -> option.None
            Ok(algorithm) -> {
              // Timestamp is optional, default to current time if not provided
              let signed_at = case
                extract_json_string_field(json_string, "signature_timestamp")
              {
                Ok(ts) -> result.unwrap(int.parse(ts), 0)
                Error(_) -> 0
              }

              option.Some(crypto_types.DigitalSignature(
                signature_data: sig_data,
                algorithm: algorithm,
                signed_at: signed_at,
              ))
            }
          }
        }
      }
    }
  }
}
