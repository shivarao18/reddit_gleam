// Key Generator - Generates valid RSA and ECDSA keys for manual testing
import gleam/io
import reddit/crypto/key_manager

pub fn main() {
  io.println("╔══════════════════════════════════════════════╗")
  io.println("║   CRYPTOGRAPHIC KEY GENERATOR                ║")
  io.println("╚══════════════════════════════════════════════╝")
  io.println("")

  io.println("🔐 RSA-2048 Keypair")
  io.println("═══════════════════════════════════════════════")
  let assert Ok(rsa_keypair) = key_manager.generate_rsa_keypair()
  io.println("Public Key (for registration):")
  io.println(rsa_keypair.public.key_data)
  io.println("")
  io.println("Private Key (keep secret - for signing):")
  io.println(rsa_keypair.private.key_data)
  io.println("")
  io.println("")

  io.println("🔐 ECDSA P-256 Keypair")
  io.println("═══════════════════════════════════════════════")
  let assert Ok(ecdsa_keypair) = key_manager.generate_ecdsa_keypair()
  io.println("Public Key (for registration):")
  io.println(ecdsa_keypair.public.key_data)
  io.println("")
  io.println("Private Key (keep secret - for signing):")
  io.println(ecdsa_keypair.private.key_data)
  io.println("")
  io.println("")

  io.println("📋 CURL COMMANDS FOR DEMO")
  io.println("═══════════════════════════════════════════════")
  io.println("")

  io.println("PowerShell - Use these commands:")
  io.println("")
  io.println("# Register Alice with RSA-2048:")
  io.println(
    "curl -X POST http://localhost:3000/api/auth/register -H \"Content-Type: application/json\" -d '{\"username\":\"alice\",\"public_key\":\""
    <> rsa_keypair.public.key_data
    <> "\",\"key_algorithm\":\"RSA2048\"}'",
  )
  io.println("")

  io.println("# Register Bob with ECDSA P-256:")
  io.println(
    "curl -X POST http://localhost:3000/api/auth/register -H \"Content-Type: application/json\" -d '{\"username\":\"bob\",\"public_key\":\""
    <> ecdsa_keypair.public.key_data
    <> "\",\"key_algorithm\":\"ECDSA_P256\"}'",
  )
  io.println("")

  io.println(
    "NOTE: If the above doesn't work in PowerShell, save keys to files:",
  )
  io.println("")
  io.println("RSA Public Key: " <> rsa_keypair.public.key_data)
  io.println("")
  io.println("ECDSA Public Key: " <> ecdsa_keypair.public.key_data)
  io.println("")

  io.println("✅ Keys generated successfully!")
  io.println("💡 Copy the curl commands above for your demo")
}
