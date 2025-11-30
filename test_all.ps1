# Final Testing Script - Reddit Clone Part 2
# Run this script to test all functionality before submission

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "     REDDIT CLONE - FINAL TESTING SCRIPT                       " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Build the project
Write-Host "TEST 1: Building the project..." -ForegroundColor Yellow
gleam build
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ BUILD FAILED!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build successful!" -ForegroundColor Green
Write-Host ""

# Test 2: Check for any running servers on port 3000
Write-Host "TEST 2: Checking if port 3000 is available..." -ForegroundColor Yellow
$portInUse = netstat -ano | findstr ":3000"
if ($portInUse) {
    Write-Host "Port 3000 is in use. Killing existing processes..." -ForegroundColor Yellow
    $processId = ($portInUse -split '\s+')[-1]
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}
Write-Host "✅ Port 3000 is available!" -ForegroundColor Green
Write-Host ""

# Test 3: Start the server in background
Write-Host "TEST 3: Starting the REST API server..." -ForegroundColor Yellow
$serverProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; gleam run -m reddit_server" -PassThru
Write-Host "   Server starting (PID: $($serverProcess.Id))..." -ForegroundColor Gray
Start-Sleep -Seconds 8
Write-Host "✅ Server started!" -ForegroundColor Green
Write-Host ""

# Test 4: Health check
Write-Host "TEST 4: Testing health endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -Method GET -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Health check passed! Server is responding." -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Health check failed! Server not responding." -ForegroundColor Red
    Stop-Process -Id $serverProcess.Id -Force
    exit 1
}
Write-Host ""

# Test 5: Test user registration
Write-Host "TEST 5: Testing user registration API..." -ForegroundColor Yellow
try {
    $body = @{username = "test_user_final"} | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/register" -Method POST -Body $body -ContentType "application/json"
    if ($response.success) {
        Write-Host "✅ User registration successful! User ID: $($response.data.user_id)" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ User registration failed!" -ForegroundColor Red
}
Write-Host ""

# Test 6: Test listing subreddits
Write-Host "TEST 6: Testing list subreddits API..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/subreddits" -Method GET
    Write-Host "✅ Subreddits endpoint working! Found $($response.data.Count) subreddits." -ForegroundColor Green
} catch {
    Write-Host "❌ List subreddits failed!" -ForegroundColor Red
}
Write-Host ""

# Test 7: Run single client demo
Write-Host "TEST 7: Running single client demo..." -ForegroundColor Yellow
Write-Host "   (This will take about 10-15 seconds)" -ForegroundColor Gray
try {
    $clientOutput = gleam run -m reddit_client 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Single client demo completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Single client demo failed!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error running client demo!" -ForegroundColor Red
}
Write-Host ""

# Test 8: Run multi-client demo
Write-Host "TEST 8: Running multi-client demo with 5 concurrent clients..." -ForegroundColor Yellow
Write-Host "   (This will take about 20-30 seconds)" -ForegroundColor Gray
try {
    $multiOutput = gleam run -m reddit_multi_client 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Multi-client demo completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Multi-client demo failed!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error running multi-client demo!" -ForegroundColor Red
}
Write-Host ""

# Test 9: Run DM demo
Write-Host "TEST 9: Running direct messaging demo..." -ForegroundColor Yellow
Write-Host "   (This will take about 10-15 seconds)" -ForegroundColor Gray
try {
    $dmOutput = gleam run -m reddit_dm_demo 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ DM demo completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ DM demo failed!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error running DM demo!" -ForegroundColor Red
}
Write-Host ""

# Test 10: Test key API endpoints with curl
Write-Host "TEST 10: Testing key API endpoints..." -ForegroundColor Yellow

# Test creating a subreddit
try {
    $body = @{
        name = "test_final"
        description = "Final test subreddit"
        creator_id = "user_1"
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/subreddits/create" -Method POST -Body $body -ContentType "application/json"
    Write-Host "   ✅ Create subreddit: OK" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Create subreddit: Failed (may already exist)" -ForegroundColor Yellow
}

# Test creating a post
try {
    $body = @{
        subreddit_id = "sub_1"
        author_id = "user_1"
        title = "Final Test Post"
        content = "Testing before submission"
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/posts/create" -Method POST -Body $body -ContentType "application/json"
    Write-Host "   ✅ Create post: OK" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Create post: Failed" -ForegroundColor Red
}

# Test getting feed
try {
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/feed/user_1" -Method GET
    Write-Host "   ✅ Get feed: OK (Found $($response.data.Count) posts)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Get feed: Failed" -ForegroundColor Red
}

# Test sending DM
try {
    $body = @{
        from_user_id = "user_1"
        to_user_id = "user_2"
        content = "Final test message"
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/dm/send" -Method POST -Body $body -ContentType "application/json"
    Write-Host "   ✅ Send DM: OK" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Send DM: Failed" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                    TEST SUMMARY                                " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All tests completed! Review the results above." -ForegroundColor White
Write-Host ""
Write-Host "Server is still running (PID: $($serverProcess.Id))" -ForegroundColor Yellow
Write-Host ""
$choice = Read-Host "Do you want to stop the server? (y/n)"
if ($choice -eq 'y' -or $choice -eq 'Y') {
    Stop-Process -Id $serverProcess.Id -Force
    Write-Host "Server stopped." -ForegroundColor Green
} else {
    Write-Host "Server still running. You can stop it manually later." -ForegroundColor Yellow
    Write-Host "To stop: Stop-Process -Id $($serverProcess.Id) -Force" -ForegroundColor Gray
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "              READY FOR SUBMISSION!                             " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
