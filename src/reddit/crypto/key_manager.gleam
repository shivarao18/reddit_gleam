// Key generation and management for digital signatures
import gleam/bit_array
import reddit/crypto/types.{
  type KeyAlgorithm, type KeyPair, type PrivateKey, type PublicKey, ECDSAP256,
  KeyPair, PrivateKey, PublicKey, RSA2048,
}

// FFI helper for RSA key generation
@external(erlang, "reddit_crypto_ffi", "generate_rsa_keypair")
fn generate_rsa_keys_ffi(bits: Int) -> Result(#(BitArray, BitArray), String)

// FFI helper for ECDSA key generation
@external(erlang, "reddit_crypto_ffi", "generate_ecdsa_keypair")
fn generate_ecdsa_keys_ffi() -> Result(#(BitArray, BitArray), String)

// Generate RSA-2048 key pair
pub fn generate_rsa_keypair() -> Result(KeyPair, String) {
  case generate_rsa_keys_ffi(2048) {
    Ok(#(public_der, private_der)) -> {
      // Encode to Base64 for storage/transmission
      let public_b64 = bit_array.base64_encode(public_der, True)
      let private_b64 = bit_array.base64_encode(private_der, True)

      Ok(KeyPair(
        public: PublicKey(algorithm: RSA2048, key_data: public_b64),
        private: PrivateKey(algorithm: RSA2048, key_data: private_b64),
      ))
    }
    Error(e) -> Error(e)
  }
}

// Generate ECDSA P-256 key pair
pub fn generate_ecdsa_keypair() -> Result(KeyPair, String) {
  case generate_ecdsa_keys_ffi() {
    Ok(#(public_der, private_der)) -> {
      // Encode to Base64
      let public_b64 = bit_array.base64_encode(public_der, True)
      let private_b64 = bit_array.base64_encode(private_der, True)

      Ok(KeyPair(
        public: PublicKey(algorithm: ECDSAP256, key_data: public_b64),
        private: PrivateKey(algorithm: ECDSAP256, key_data: private_b64),
      ))
    }
    Error(e) -> Error(e)
  }
}

// Generate key pair based on algorithm choice
pub fn generate_keypair(algorithm: KeyAlgorithm) -> Result(KeyPair, String) {
  case algorithm {
    RSA2048 -> generate_rsa_keypair()
    ECDSAP256 -> generate_ecdsa_keypair()
  }
}

// Decode Base64 key to binary
pub fn decode_key(key_b64: String) -> Result(BitArray, String) {
  case bit_array.base64_decode(key_b64) {
    Ok(key_der) -> Ok(key_der)
    Error(_) -> Error("Failed to decode Base64 key")
  }
}

// Validate public key format
pub fn validate_public_key(public_key: PublicKey) -> Result(Nil, String) {
  // Try to decode the Base64 data
  case decode_key(public_key.key_data) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error("Invalid public key: " <> e)
  }
}
