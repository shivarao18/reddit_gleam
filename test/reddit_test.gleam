// Reddit Clone Tests
// Basic unit tests for core data types and the Zipf distribution.
// Phase 6: Integration tests for cryptographic signatures

import gleam/option
import gleeunit
import reddit/client/zipf
import reddit/crypto/key_manager
import reddit/crypto/signature
import reddit/crypto/types as crypto_types
import reddit/types

// FFI to get current timestamp
@external(erlang, "erlang", "system_time")
fn erlang_system_time() -> Int

fn get_timestamp() -> Int {
  erlang_system_time()
}

pub fn main() -> Nil {
  gleeunit.main()
}

// Test basic types
pub fn user_type_test() {
  let user =
    types.User(
      id: "user_1",
      username: "test_user",
      karma: 0,
      joined_subreddits: [],
      is_online: True,
      created_at: 0,
      public_key: option.None,
      key_algorithm: option.None,
    )

  assert user.username == "test_user"
}

pub fn subreddit_type_test() {
  let subreddit =
    types.Subreddit(
      id: "sub_1",
      name: "test_subreddit",
      description: "A test subreddit",
      creator_id: "user_1",
      members: ["user_1"],
      member_count: 1,
      created_at: 0,
    )

  assert subreddit.name == "test_subreddit"
}

pub fn post_type_test() {
  let post =
    types.Post(
      id: "post_1",
      subreddit_id: "sub_1",
      author_id: "user_1",
      title: "Test Post",
      content: "This is a test post",
      upvotes: 0,
      downvotes: 0,
      created_at: 0,
      is_repost: False,
      original_post_id: option.None,
      signature: option.None,
    )

  assert post.title == "Test Post"
}

// Test Zipf distribution
pub fn zipf_distribution_test() {
  let dist = zipf.new(10, 1.0)

  assert dist.n == 10
}

pub fn zipf_probability_test() {
  let dist = zipf.new(10, 1.0)
  let prob = zipf.probability(dist, 1)

  // First rank should have highest probability
  assert prob >. 0.0
}

pub fn zipf_sample_test() {
  let dist = zipf.new(10, 1.0)
  let sample = zipf.sample(dist, 0.1)

  // Sample should be within valid range
  assert sample >= 1 && sample <= 10
}

// ============================================================================
// Phase 6: Integration Tests for Cryptographic Signatures
// ============================================================================

// Test 1: End-to-End RSA Key Generation and Signature
pub fn rsa_key_generation_and_signing_test() {
  // Generate RSA key pair
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()

  // Verify key pair structure
  assert keypair.public.algorithm == crypto_types.RSA2048
  assert keypair.private.algorithm == crypto_types.RSA2048
  assert keypair.public.key_data != ""
  assert keypair.private.key_data != ""
}

// Test 2: Sign and Verify Message with RSA
pub fn rsa_sign_and_verify_test() {
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()
  let message = "Test message for RSA signature"
  let timestamp = get_timestamp()

  // Sign the message
  let assert Ok(signature) =
    signature.sign_message(message, keypair.private, timestamp)

  // Verify signature with correct public key
  let is_valid = signature.verify_signature(message, signature, keypair.public)
  assert is_valid == True
}

// Test 3: RSA Signature Fails with Wrong Key
pub fn rsa_signature_wrong_key_test() {
  let assert Ok(keypair1) = key_manager.generate_rsa_keypair()
  let assert Ok(keypair2) = key_manager.generate_rsa_keypair()
  let message = "Test message"
  let timestamp = get_timestamp()

  // Sign with keypair1
  let assert Ok(signature) =
    signature.sign_message(message, keypair1.private, timestamp)

  // Try to verify with keypair2's public key (should fail)
  let is_valid = signature.verify_signature(message, signature, keypair2.public)
  assert is_valid == False
}

// Test 4: RSA Signature Fails with Tampered Message
pub fn rsa_signature_tampered_message_test() {
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()
  let original_message = "Original message"
  let tampered_message = "Tampered message"
  let timestamp = get_timestamp()

  // Sign original message
  let assert Ok(signature) =
    signature.sign_message(original_message, keypair.private, timestamp)

  // Try to verify with tampered message (should fail)
  let is_valid =
    signature.verify_signature(tampered_message, signature, keypair.public)
  assert is_valid == False
}

// Test 5: End-to-End ECDSA Key Generation and Signature
pub fn ecdsa_key_generation_and_signing_test() {
  // Generate ECDSA key pair
  let assert Ok(keypair) = key_manager.generate_ecdsa_keypair()

  // Verify key pair structure
  assert keypair.public.algorithm == crypto_types.ECDSAP256
  assert keypair.private.algorithm == crypto_types.ECDSAP256
  assert keypair.public.key_data != ""
  assert keypair.private.key_data != ""
}

// Test 6: Sign and Verify Message with ECDSA
pub fn ecdsa_sign_and_verify_test() {
  let assert Ok(keypair) = key_manager.generate_ecdsa_keypair()
  let message = "Test message for ECDSA signature"
  let timestamp = get_timestamp()

  // Sign the message
  let assert Ok(signature) =
    signature.sign_message(message, keypair.private, timestamp)

  // Verify signature with correct public key
  let is_valid = signature.verify_signature(message, signature, keypair.public)
  assert is_valid == True
}

// Test 7: ECDSA Signature Fails with Wrong Key
pub fn ecdsa_signature_wrong_key_test() {
  let assert Ok(keypair1) = key_manager.generate_ecdsa_keypair()
  let assert Ok(keypair2) = key_manager.generate_ecdsa_keypair()
  let message = "Test message"
  let timestamp = get_timestamp()

  // Sign with keypair1
  let assert Ok(signature) =
    signature.sign_message(message, keypair1.private, timestamp)

  // Try to verify with keypair2's public key (should fail)
  let is_valid = signature.verify_signature(message, signature, keypair2.public)
  assert is_valid == False
}

// Test 8: Post Signature Creation and Verification
pub fn post_signature_test() {
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()
  let post_id = "post_1"
  let author_id = "user_1"
  let title = "Test Post"
  let content = "This is a test post"
  let timestamp = get_timestamp()

  // Sign the post
  let assert Ok(signature) =
    signature.sign_post(
      post_id,
      author_id,
      title,
      content,
      timestamp,
      keypair.private,
    )

  // Verify post signature
  let is_valid =
    signature.verify_post(
      post_id,
      author_id,
      title,
      content,
      timestamp,
      signature,
      keypair.public,
    )
  assert is_valid == True
}

// Test 9: Post Signature Fails with Modified Content
pub fn post_signature_tampered_content_test() {
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()
  let post_id = "post_1"
  let author_id = "user_1"
  let original_content = "Original content"
  let tampered_content = "Tampered content"
  let timestamp = get_timestamp()

  // Sign with original content
  let assert Ok(signature) =
    signature.sign_post(
      post_id,
      author_id,
      "Title",
      original_content,
      timestamp,
      keypair.private,
    )

  // Try to verify with tampered content (should fail)
  let is_valid =
    signature.verify_post(
      post_id,
      author_id,
      "Title",
      tampered_content,
      timestamp,
      signature,
      keypair.public,
    )
  assert is_valid == False
}

// Test 10: Canonical Post Message Format
pub fn canonical_post_message_test() {
  let post_id = "post_123"
  let author_id = "user_456"
  let title = "My Title"
  let content = "My Content"
  let timestamp = 1_234_567_890

  let message =
    signature.create_post_message(post_id, author_id, title, content, timestamp)

  assert message == "post_123|user_456|My Title|My Content|1234567890"
}

// Test 11: Multi-User Signature Isolation
pub fn multi_user_signature_isolation_test() {
  // Create two users with different keys
  let assert Ok(alice_keypair) = key_manager.generate_rsa_keypair()
  let assert Ok(bob_keypair) = key_manager.generate_rsa_keypair()

  let timestamp = get_timestamp()

  // Alice signs a post
  let assert Ok(alice_signature) =
    signature.sign_post(
      "post_1",
      "alice",
      "Alice's Post",
      "Content by Alice",
      timestamp,
      alice_keypair.private,
    )

  // Bob signs a different post
  let assert Ok(bob_signature) =
    signature.sign_post(
      "post_2",
      "bob",
      "Bob's Post",
      "Content by Bob",
      timestamp,
      bob_keypair.private,
    )

  // Verify Alice's post with Alice's key
  let alice_valid =
    signature.verify_post(
      "post_1",
      "alice",
      "Alice's Post",
      "Content by Alice",
      timestamp,
      alice_signature,
      alice_keypair.public,
    )
  assert alice_valid == True

  // Verify Bob's post with Bob's key
  let bob_valid =
    signature.verify_post(
      "post_2",
      "bob",
      "Bob's Post",
      "Content by Bob",
      timestamp,
      bob_signature,
      bob_keypair.public,
    )
  assert bob_valid == True

  // Cross-verification should fail
  let cross_valid =
    signature.verify_post(
      "post_1",
      "alice",
      "Alice's Post",
      "Content by Alice",
      timestamp,
      alice_signature,
      bob_keypair.public,
    )
  assert cross_valid == False
}

// Test 12: Algorithm Mismatch Detection
pub fn algorithm_mismatch_test() {
  let assert Ok(rsa_keypair) = key_manager.generate_rsa_keypair()
  let assert Ok(ecdsa_keypair) = key_manager.generate_ecdsa_keypair()
  let message = "Test message"
  let timestamp = get_timestamp()

  // Sign with RSA
  let assert Ok(rsa_signature) =
    signature.sign_message(message, rsa_keypair.private, timestamp)

  // Try to verify with ECDSA key (algorithms don't match)
  let is_valid =
    signature.verify_signature(message, rsa_signature, ecdsa_keypair.public)
  assert is_valid == False
}

// Test 13: Base64 Encoding/Decoding
pub fn base64_encoding_test() {
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()

  // Public key should be base64 encoded
  assert keypair.public.key_data != ""

  // Try to decode it (should succeed)
  let assert Ok(_decoded) = key_manager.decode_key(keypair.public.key_data)
}
