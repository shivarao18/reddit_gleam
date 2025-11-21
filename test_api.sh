#!/bin/bash

echo "Testing Reddit Clone REST API"
echo "=============================="
echo ""

echo "1. Health Check"
curl -s http://localhost:8080/health
echo -e "\n"

echo "2. API Info"
curl -s http://localhost:8080/
echo -e "\n"

echo "3. Register User: alice"
curl -s -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice"}'
echo -e "\n"

echo "4. Get User: alice"
curl -s http://localhost:8080/api/auth/user/alice
echo -e "\n"

echo "5. Register User: bob"
curl -s -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"bob"}'
echo -e "\n"

echo "6. Try to register alice again (should fail)"
curl -s -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice"}'
echo -e "\n"

