#!/bin/bash

echo "================================="
echo "Reddit Clone - Phase 3 API Tests"
echo "================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:8080"

echo -e "${BLUE}=== 1. Create Users ===${NC}"
echo "Creating alice..."
curl -s -X POST $BASE_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice"}'
echo ""

echo "Creating bob..."
curl -s -X POST $BASE_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"bob"}'
echo ""

echo "Creating charlie..."
curl -s -X POST $BASE_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"charlie"}'
echo ""

# Get user IDs (assume user_1, user_2, user_3 for simplicity)
ALICE_ID="user_1"
BOB_ID="user_2"
CHARLIE_ID="user_3"

echo -e "${BLUE}=== 2. Create Subreddits ===${NC}"
echo "Alice creates r/programming..."
curl -s -X POST $BASE_URL/api/subreddits/create \
  -H "Content-Type: application/json" \
  -d '{"name":"programming","description":"All about programming","creator_id":"'$ALICE_ID'"}'
echo ""

echo "Bob creates r/gleam..."
curl -s -X POST $BASE_URL/api/subreddits/create \
  -H "Content-Type: application/json" \
  -d '{"name":"gleam","description":"Gleam programming language","creator_id":"'$BOB_ID'"}'
echo ""

# Get subreddit IDs (assume sub_1, sub_2)
PROG_SUB_ID="sub_1"
GLEAM_SUB_ID="sub_2"

echo -e "${BLUE}=== 3. List All Subreddits ===${NC}"
curl -s $BASE_URL/api/subreddits
echo ""

echo -e "${BLUE}=== 4. Join Subreddits ===${NC}"
echo "Alice joins r/gleam..."
curl -s -X POST $BASE_URL/api/subreddits/$GLEAM_SUB_ID/join \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$ALICE_ID'"}'
echo ""

echo "Bob joins r/programming..."
curl -s -X POST $BASE_URL/api/subreddits/$PROG_SUB_ID/join \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$BOB_ID'"}'
echo ""

echo "Charlie joins both..."
curl -s -X POST $BASE_URL/api/subreddits/$PROG_SUB_ID/join \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$CHARLIE_ID'"}'
curl -s -X POST $BASE_URL/api/subreddits/$GLEAM_SUB_ID/join \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$CHARLIE_ID'"}'
echo ""

echo -e "${BLUE}=== 5. Create Posts ===${NC}"
echo "Alice posts in r/programming..."
curl -s -X POST $BASE_URL/api/posts/create \
  -H "Content-Type: application/json" \
  -d '{"subreddit_id":"'$PROG_SUB_ID'","author_id":"'$ALICE_ID'","title":"Hello World in Gleam","content":"Just wrote my first Gleam program!"}'
echo ""

echo "Bob posts in r/gleam..."
curl -s -X POST $BASE_URL/api/posts/create \
  -H "Content-Type: application/json" \
  -d '{"subreddit_id":"'$GLEAM_SUB_ID'","author_id":"'$BOB_ID'","title":"Gleam is awesome","content":"I love the type system"}'
echo ""

# Assume post IDs
POST1_ID="post_1"
POST2_ID="post_2"

echo -e "${BLUE}=== 6. Get Individual Posts ===${NC}"
echo "Getting post 1..."
curl -s $BASE_URL/api/posts/$POST1_ID
echo ""

echo -e "${BLUE}=== 7. Vote on Posts ===${NC}"
echo "Bob upvotes Alice's post..."
curl -s -X POST $BASE_URL/api/posts/$POST1_ID/vote \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$BOB_ID'","vote_type":"upvote"}'
echo ""

echo "Charlie upvotes both posts..."
curl -s -X POST $BASE_URL/api/posts/$POST1_ID/vote \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$CHARLIE_ID'","vote_type":"upvote"}'
curl -s -X POST $BASE_URL/api/posts/$POST2_ID/vote \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$CHARLIE_ID'","vote_type":"upvote"}'
echo ""

echo -e "${BLUE}=== 8. Create Comments ===${NC}"
echo "Bob comments on post 1..."
curl -s -X POST $BASE_URL/api/comments/create \
  -H "Content-Type: application/json" \
  -d '{"post_id":"'$POST1_ID'","author_id":"'$BOB_ID'","content":"Great post! Welcome to Gleam!","parent_id":""}'
echo ""

echo "Charlie comments on post 1..."
curl -s -X POST $BASE_URL/api/comments/create \
  -H "Content-Type: application/json" \
  -d '{"post_id":"'$POST1_ID'","author_id":"'$CHARLIE_ID'","content":"I agree, Gleam rocks!","parent_id":""}'
echo ""

# Assume comment IDs
COMMENT1_ID="comment_1"

echo -e "${BLUE}=== 9. Get Comments for Post ===${NC}"
curl -s $BASE_URL/api/posts/$POST1_ID/comments
echo ""

echo -e "${BLUE}=== 10. Vote on Comments ===${NC}"
echo "Alice upvotes Bob's comment..."
curl -s -X POST $BASE_URL/api/comments/$COMMENT1_ID/vote \
  -H "Content-Type: application/json" \
  -d '{"user_id":"'$ALICE_ID'","vote_type":"upvote"}'
echo ""

echo -e "${BLUE}=== 11. Create Repost ===${NC}"
echo "Charlie reposts Alice's post to r/gleam..."
curl -s -X POST $BASE_URL/api/posts/$POST1_ID/repost \
  -H "Content-Type: application/json" \
  -d '{"author_id":"'$CHARLIE_ID'","subreddit_id":"'$GLEAM_SUB_ID'"}'
echo ""

echo -e "${BLUE}=== 12. Get Personalized Feeds ===${NC}"
echo "Alice's feed..."
curl -s $BASE_URL/api/feed/$ALICE_ID
echo ""

echo "Bob's feed..."
curl -s $BASE_URL/api/feed/$BOB_ID
echo ""

echo "Charlie's feed..."
curl -s $BASE_URL/api/feed/$CHARLIE_ID
echo ""

echo -e "${GREEN}=== All Phase 3 Tests Complete! ===${NC}"

