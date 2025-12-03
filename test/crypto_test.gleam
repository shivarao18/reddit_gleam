// Tests for crypto functionality
import gleeunit
import gleeunit/should
import reddit/crypto/key_manager
import reddit/crypto/signature
import reddit/crypto/types.{ECDSAP256, RSA2048}

pub fn main() {
  gleeunit.main()
}

// Test RSA-2048 key generation
pub fn rsa_keygen_test() {
  let result = key_manager.generate_rsa_keypair()
  result
  |> should.be_ok()

  case result {
    Ok(keypair) -> {
      keypair.public.algorithm |> should.equal(RSA2048)
      keypair.private.algorithm |> should.equal(RSA2048)
      // Keys should be non-empty Base64 strings
      keypair.public.key_data |> should.not_equal("")
      keypair.private.key_data |> should.not_equal("")
    }
    Error(_) -> panic as "Should not fail"
  }
}

// Test ECDSA P-256 key generation
pub fn ecdsa_keygen_test() {
  let result = key_manager.generate_ecdsa_keypair()
  result
  |> should.be_ok()

  case result {
    Ok(keypair) -> {
      keypair.public.algorithm |> should.equal(ECDSAP256)
      keypair.private.algorithm |> should.equal(ECDSAP256)
      keypair.public.key_data |> should.not_equal("")
      keypair.private.key_data |> should.not_equal("")
    }
    Error(_) -> panic as "Should not fail"
  }
}

// Test RSA signing and verification
pub fn rsa_sign_verify_test() {
  // Generate key pair
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()

  // Create test message
  let message = "Hello, World!"
  let timestamp = 1_700_000_000

  // Sign message
  let sign_result = signature.sign_message(message, keypair.private, timestamp)
  sign_result |> should.be_ok()

  case sign_result {
    Ok(sig) -> {
      // Verify signature
      let verified = signature.verify_signature(message, sig, keypair.public)
      verified |> should.be_true()

      // Verify with wrong message should fail
      let wrong_verified =
        signature.verify_signature("Wrong message", sig, keypair.public)
      wrong_verified |> should.be_false()
    }
    Error(_) -> panic as "Signing should succeed"
  }
}

// Test ECDSA signing and verification
pub fn ecdsa_sign_verify_test() {
  // Generate key pair
  let assert Ok(keypair) = key_manager.generate_ecdsa_keypair()

  // Create test message
  let message = "Test ECDSA signature"
  let timestamp = 1_700_000_100

  // Sign message
  let sign_result = signature.sign_message(message, keypair.private, timestamp)
  sign_result |> should.be_ok()

  case sign_result {
    Ok(sig) -> {
      // Verify signature
      let verified = signature.verify_signature(message, sig, keypair.public)
      verified |> should.be_true()

      // Verify with wrong message should fail
      let wrong_verified =
        signature.verify_signature("Tampered message", sig, keypair.public)
      wrong_verified |> should.be_false()
    }
    Error(_) -> panic as "Signing should succeed"
  }
}

// Test post signing and verification
pub fn post_sign_verify_test() {
  // Generate key pair
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()

  // Post data
  let post_id = "post_123"
  let author_id = "user_456"
  let title = "Test Post"
  let content = "This is a test post content"
  let timestamp = 1_700_000_200

  // Sign post
  let sign_result =
    signature.sign_post(
      post_id,
      author_id,
      title,
      content,
      timestamp,
      keypair.private,
    )
  sign_result |> should.be_ok()

  case sign_result {
    Ok(sig) -> {
      // Verify post signature
      let verified =
        signature.verify_post(
          post_id,
          author_id,
          title,
          content,
          timestamp,
          sig,
          keypair.public,
        )
      verified |> should.be_true()

      // Verify with tampered title should fail
      let tampered_verified =
        signature.verify_post(
          post_id,
          author_id,
          "Tampered Title",
          content,
          timestamp,
          sig,
          keypair.public,
        )
      tampered_verified |> should.be_false()

      // Verify with tampered content should fail
      let tampered_content_verified =
        signature.verify_post(
          post_id,
          author_id,
          title,
          "Tampered content",
          timestamp,
          sig,
          keypair.public,
        )
      tampered_content_verified |> should.be_false()
    }
    Error(_) -> panic as "Post signing should succeed"
  }
}

// Test algorithm mismatch rejection
pub fn algorithm_mismatch_test() {
  // Generate RSA and ECDSA key pairs
  let assert Ok(rsa_keypair) = key_manager.generate_rsa_keypair()
  let assert Ok(ecdsa_keypair) = key_manager.generate_ecdsa_keypair()

  let message = "Test message"
  let timestamp = 1_700_000_300

  // Sign with RSA
  let assert Ok(rsa_sig) =
    signature.sign_message(message, rsa_keypair.private, timestamp)

  // Try to verify with ECDSA public key (should fail)
  let mismatched_verify =
    signature.verify_signature(message, rsa_sig, ecdsa_keypair.public)
  mismatched_verify |> should.be_false()
}

// Test key validation
pub fn key_validation_test() {
  // Valid key
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()
  let valid_result = key_manager.validate_public_key(keypair.public)
  valid_result |> should.be_ok()

  // Invalid key (bad Base64)
  let invalid_key =
    types.PublicKey(algorithm: RSA2048, key_data: "not-base64!@#")
  let invalid_result = key_manager.validate_public_key(invalid_key)
  invalid_result |> should.be_error()
}
