// Digital signature creation and verification
import gleam/bit_array
import gleam/int
import gleam/string
import reddit/crypto/key_manager
import reddit/crypto/types.{
  type DigitalSignature, type PrivateKey, type PublicKey, DigitalSignature,
  ECDSAP256, RSA2048,
}

// FFI to Erlang crypto signing functions
@external(erlang, "reddit_crypto_ffi", "sign_rsa")
fn sign_rsa_ffi(
  message: BitArray,
  private_key: BitArray,
) -> Result(BitArray, String)

@external(erlang, "reddit_crypto_ffi", "sign_ecdsa")
fn sign_ecdsa_ffi(
  message: BitArray,
  private_key: BitArray,
) -> Result(BitArray, String)

@external(erlang, "reddit_crypto_ffi", "verify_rsa")
fn verify_rsa_ffi(
  message: BitArray,
  signature: BitArray,
  public_key: BitArray,
) -> Bool

@external(erlang, "reddit_crypto_ffi", "verify_ecdsa")
fn verify_ecdsa_ffi(
  message: BitArray,
  signature: BitArray,
  public_key: BitArray,
) -> Bool

// Create a canonical message for post signing
pub fn create_post_message(
  post_id: String,
  author_id: String,
  title: String,
  content: String,
  timestamp: Int,
) -> String {
  // Canonical format: post_id|author_id|title|content|timestamp
  string.join(
    [post_id, author_id, title, content, int.to_string(timestamp)],
    "|",
  )
}

// Sign a message with a private key
pub fn sign_message(
  message: String,
  private_key: PrivateKey,
  timestamp: Int,
) -> Result(DigitalSignature, String) {
  // Decode the private key from Base64
  case key_manager.decode_key(private_key.key_data) {
    Ok(private_der) -> {
      // Convert message to bit array
      let message_bits = bit_array.from_string(message)

      // Sign based on algorithm
      case private_key.algorithm {
        RSA2048 -> {
          case sign_rsa_ffi(message_bits, private_der) {
            Ok(signature_der) -> {
              let signature_b64 = bit_array.base64_encode(signature_der, True)
              Ok(DigitalSignature(
                signature_data: signature_b64,
                algorithm: RSA2048,
                signed_at: timestamp,
              ))
            }
            Error(e) -> Error(e)
          }
        }

        ECDSAP256 -> {
          case sign_ecdsa_ffi(message_bits, private_der) {
            Ok(signature_der) -> {
              let signature_b64 = bit_array.base64_encode(signature_der, True)
              Ok(DigitalSignature(
                signature_data: signature_b64,
                algorithm: ECDSAP256,
                signed_at: timestamp,
              ))
            }
            Error(e) -> Error(e)
          }
        }
      }
    }
    Error(e) -> Error(e)
  }
}

// Verify a signature against a message and public key
pub fn verify_signature(
  message: String,
  signature: DigitalSignature,
  public_key: PublicKey,
) -> Bool {
  // Ensure algorithms match
  case signature.algorithm == public_key.algorithm {
    False -> False
    True -> {
      // Decode keys
      let public_result = key_manager.decode_key(public_key.key_data)
      let signature_result = bit_array.base64_decode(signature.signature_data)

      case public_result, signature_result {
        Ok(public_der), Ok(signature_der) -> {
          let message_bits = bit_array.from_string(message)

          // Verify based on algorithm
          case signature.algorithm {
            RSA2048 -> verify_rsa_ffi(message_bits, signature_der, public_der)

            ECDSAP256 ->
              verify_ecdsa_ffi(message_bits, signature_der, public_der)
          }
        }
        _, _ -> False
      }
    }
  }
}

// Sign a post (convenience wrapper)
pub fn sign_post(
  post_id: String,
  author_id: String,
  title: String,
  content: String,
  timestamp: Int,
  private_key: PrivateKey,
) -> Result(DigitalSignature, String) {
  let message =
    create_post_message(post_id, author_id, title, content, timestamp)
  sign_message(message, private_key, timestamp)
}

// Verify a post signature (convenience wrapper)
pub fn verify_post(
  post_id: String,
  author_id: String,
  title: String,
  content: String,
  timestamp: Int,
  signature: DigitalSignature,
  public_key: PublicKey,
) -> Bool {
  let message =
    create_post_message(post_id, author_id, title, content, timestamp)
  verify_signature(message, signature, public_key)
}
