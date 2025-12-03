// Crypto Demo - Demonstrates digital signature features
import gleam/bool
import gleam/int
import gleam/io
import reddit/crypto/key_manager
import reddit/crypto/signature
import reddit/crypto/types as crypto_types

pub fn main() {
  io.println("╔══════════════════════════════════════════════╗")
  io.println("║   CRYPTOGRAPHIC SIGNATURES DEMO              ║")
  io.println("╚══════════════════════════════════════════════╝")
  io.println("")

  // Demo 1: RSA signing
  demo_rsa()
  io.println("")

  // Demo 2: ECDSA signing
  demo_ecdsa()
  io.println("")

  // Demo 3: Signature verification
  demo_verification()
  io.println("")

  io.println("✅ All cryptographic demos completed successfully!")
}

fn demo_rsa() {
  io.println("DEMO 1: RSA-2048 Digital Signatures")
  io.println("────────────────────────────────────")

  io.println("1. Generating RSA-2048 keypair...")
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()
  io.println(
    "   ✓ Generated (public key size: "
    <> int.to_string(get_string_length(keypair.public.key_data))
    <> " chars)",
  )
  io.println("   ✓ Algorithm: RSA2048")

  io.println("2. Signing message...")
  let message = "Hello from RSA!"
  let timestamp = get_timestamp()
  let assert Ok(sig) =
    signature.sign_message(message, keypair.private, timestamp)
  io.println(
    "   ✓ Signature created (size: "
    <> int.to_string(get_string_length(sig.signature_data))
    <> " chars)",
  )

  io.println("3. Verifying signature...")
  let is_valid = signature.verify_signature(message, sig, keypair.public)
  io.println("   ✓ Verification result: " <> bool.to_string(is_valid))
}

fn demo_ecdsa() {
  io.println("DEMO 2: ECDSA P-256 Digital Signatures")
  io.println("───────────────────────────────────────")

  io.println("1. Generating ECDSA P-256 keypair...")
  let assert Ok(keypair) = key_manager.generate_ecdsa_keypair()
  io.println(
    "   ✓ Generated (public key size: "
    <> int.to_string(get_string_length(keypair.public.key_data))
    <> " chars)",
  )
  io.println("   ✓ Algorithm: ECDSAP256")

  io.println("2. Signing message...")
  let message = "Hello from ECDSA!"
  let timestamp = get_timestamp()
  let assert Ok(sig) =
    signature.sign_message(message, keypair.private, timestamp)
  io.println(
    "   ✓ Signature created (size: "
    <> int.to_string(get_string_length(sig.signature_data))
    <> " chars)",
  )

  io.println("3. Verifying signature...")
  let is_valid = signature.verify_signature(message, sig, keypair.public)
  io.println("   ✓ Verification result: " <> bool.to_string(is_valid))
}

fn demo_verification() {
  io.println("DEMO 3: Signature Verification & Tampering Detection")
  io.println("─────────────────────────────────────────────────────")

  io.println("1. Creating signed post...")
  let assert Ok(keypair) = key_manager.generate_rsa_keypair()
  let post_id = "post_demo_1"
  let author_id = "user_demo_1"
  let title = "Demo Post"
  let content = "This is a demo post with digital signature"
  let timestamp = get_timestamp()

  let assert Ok(sig) =
    signature.sign_post(
      post_id,
      author_id,
      title,
      content,
      timestamp,
      keypair.private,
    )
  io.println("   ✓ Post signed successfully")

  io.println("2. Verifying original post...")
  let is_valid =
    signature.verify_post(
      post_id,
      author_id,
      title,
      content,
      timestamp,
      sig,
      keypair.public,
    )
  io.println("   ✓ Original post verification: " <> bool.to_string(is_valid))

  io.println("3. Testing with tampered content...")
  let tampered_content = "This content has been TAMPERED WITH!"
  let is_valid_tampered =
    signature.verify_post(
      post_id,
      author_id,
      title,
      tampered_content,
      timestamp,
      sig,
      keypair.public,
    )
  io.println(
    "   ✓ Tampered post verification: " <> bool.to_string(is_valid_tampered),
  )
  io.println("   ✓ Tampering detected! (verification failed)")
}

// FFI to get current timestamp
@external(erlang, "erlang", "system_time")
fn erlang_system_time() -> Int

fn get_timestamp() -> Int {
  erlang_system_time()
}

// Helper to get string length
@external(erlang, "string", "length")
fn get_string_length(s: String) -> Int
