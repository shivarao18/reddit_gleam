// Reddit Clone Tests
// Basic unit tests for core data types and the Zipf distribution.

import gleeunit
import reddit/types
import reddit/client/zipf

pub fn main() -> Nil {
  gleeunit.main()
}

// Test basic types
pub fn user_type_test() {
  let user = types.User(
    id: "user_1",
    username: "test_user",
    karma: 0,
    joined_subreddits: [],
    is_online: True,
    created_at: 0,
  )
  
  assert user.username == "test_user"
}

pub fn subreddit_type_test() {
  let subreddit = types.Subreddit(
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
  let post = types.Post(
    id: "post_1",
    subreddit_id: "sub_1",
    author_id: "user_1",
    title: "Test Post",
    content: "This is a test post",
    upvotes: 0,
    downvotes: 0,
    created_at: 0,
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
