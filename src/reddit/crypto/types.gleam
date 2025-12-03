// Crypto-specific types for digital signatures

pub type KeyAlgorithm {
  RSA2048
  ECDSAP256
}

pub type PublicKey {
  PublicKey(algorithm: KeyAlgorithm, key_data: String)
}

pub type PrivateKey {
  PrivateKey(algorithm: KeyAlgorithm, key_data: String)
}

pub type KeyPair {
  KeyPair(public: PublicKey, private: PrivateKey)
}

pub type DigitalSignature {
  DigitalSignature(
    signature_data: String,
    algorithm: KeyAlgorithm,
    signed_at: Int,
  )
}

// Convert KeyAlgorithm to string for JSON/display
pub fn algorithm_to_string(algo: KeyAlgorithm) -> String {
  case algo {
    RSA2048 -> "RSA-2048"
    ECDSAP256 -> "ECDSA-P256"
  }
}

// Parse KeyAlgorithm from string
pub fn string_to_algorithm(s: String) -> Result(KeyAlgorithm, String) {
  case s {
    "RSA-2048" -> Ok(RSA2048)
    "ECDSA-P256" -> Ok(ECDSAP256)
    _ -> Error("Unsupported algorithm: " <> s)
  }
}
