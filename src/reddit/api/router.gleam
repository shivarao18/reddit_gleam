// API Router - Routes HTTP requests to appropriate handlers
// This module provides the main routing logic for the REST API

import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import mist
import reddit/api/handlers/auth
import reddit/api/types
import reddit/server_context.{type ServerContext}

/// Main request handler - routes requests to appropriate handlers
pub fn handle_request(
  req: Request(mist.Connection),
  ctx: ServerContext,
) -> Response(mist.ResponseData) {
  // Log the request
  io.println(
    "Request: "
    <> http.method_to_string(req.method)
    <> " "
    <> req.path,
  )

  // Parse path segments
  let path_segments =
    req.path
    |> string.split("/")
    |> list.filter(fn(seg) { seg != "" })

  // Route based on path and method
  case path_segments {
    // Health check
    ["health"] -> health_check(req)

    // API info
    [] -> api_info(req)

    // Authentication endpoints
    ["api", "auth", "register"] -> auth.register(req, ctx)
    ["api", "auth", "user", username] -> auth.get_user(req, ctx, username)

    // 404 for unknown routes
    _ -> not_found()
  }
}

/// Health check endpoint
fn health_check(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
  case req.method {
    http.Get -> {
      types.success_response(
        json.object([
          #("status", json.string("healthy")),
          #("message", json.string("Reddit Clone API Server is running")),
        ]),
      )
    }
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

/// API info endpoint
fn api_info(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
  case req.method {
    http.Get -> {
      types.success_response(
        json.object([
          #("name", json.string("Reddit Clone REST API")),
          #("version", json.string("2.0")),
          #("description", json.string("Part II - REST API Server")),
          #(
            "endpoints",
            json.object([
              #("health", json.string("GET /health")),
              #("info", json.string("GET /")),
              #("register", json.string("POST /api/auth/register")),
              #("get_user", json.string("GET /api/auth/user/:username")),
            ]),
          ),
          #(
            "status",
            json.string("Phase 2 Complete - Authentication endpoints ready"),
          ),
        ]),
      )
    }
    _ -> types.error_response("MethodNotAllowed", "Only GET allowed", 405)
  }
}

/// 404 Not Found response
fn not_found() -> Response(mist.ResponseData) {
  types.not_found("The requested endpoint does not exist")
}

