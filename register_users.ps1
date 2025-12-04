# PowerShell script to register users with crypto keys
# Run this after starting the server and generating keys

Write-Host "Registering users with cryptographic keys..." -ForegroundColor Cyan
Write-Host ""

# First, run the key generator to get keys
Write-Host "Step 1: Generating cryptographic keys..." -ForegroundColor Yellow
$output = gleam run -m reddit_key_generator | Out-String

# Extract the public keys from the output
$lines = $output -split "`n"
$rsaKey = ""
$ecdsaKey = ""

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "Public Key \(for registration\):") {
        if ($rsaKey -eq "") {
            $rsaKey = $lines[$i + 1].Trim()
        } else {
            $ecdsaKey = $lines[$i + 1].Trim()
        }
    }
}

Write-Host ""
Write-Host "Step 2: Registering Alice with RSA-2048..." -ForegroundColor Yellow

$aliceJson = @{
    username = "alice"
    public_key = $rsaKey
    key_algorithm = "RSA2048"
} | ConvertTo-Json -Compress

$response1 = Invoke-WebRequest -Uri "http://localhost:3000/api/auth/register" `
    -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body $aliceJson

Write-Host "Response:" $response1.Content -ForegroundColor Green
Write-Host ""

Write-Host "Step 3: Registering Bob with ECDSA P-256..." -ForegroundColor Yellow

$bobJson = @{
    username = "bob"
    public_key = $ecdsaKey
    key_algorithm = "ECDSA_P256"
} | ConvertTo-Json -Compress

$response2 = Invoke-WebRequest -Uri "http://localhost:3000/api/auth/register" `
    -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body $bobJson

Write-Host "Response:" $response2.Content -ForegroundColor Green
Write-Host ""

Write-Host "Step 4: Registering Charlie (no crypto)..." -ForegroundColor Yellow

$charlieJson = @{
    username = "charlie"
} | ConvertTo-Json -Compress

$response3 = Invoke-WebRequest -Uri "http://localhost:3000/api/auth/register" `
    -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body $charlieJson

Write-Host "Response:" $response3.Content -ForegroundColor Green
Write-Host ""
Write-Host "✅ All users registered successfully!" -ForegroundColor Cyan
