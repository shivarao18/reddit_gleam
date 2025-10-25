# Troubleshooting Guide

## Common Issues and Solutions

### Build Errors

#### Issue: "Cannot find module 'gleam_otp'"

**Cause:** Dependencies not downloaded

**Solution:**
```bash
gleam deps download
gleam build
```

#### Issue: Type mismatch errors

**Cause:** Often due to incorrect message protocol usage

**Solution:**
1. Check that message types match in `protocol.gleam`
2. Verify the reply channel type matches expected result
3. Run `gleam check` for detailed type errors

Example fix:
```gleam
// Wrong:
actor.call(registry, RegisterUser("alice"), 5000)

// Correct:
actor.call(registry, RegisterUser("alice", _), 5000)
//                                         ↑ reply channel
```

#### Issue: "Unused import" warnings

**Cause:** Imported module not used in file

**Solution:**
Remove the unused import or use the imported item.

### Runtime Errors

#### Issue: Actor timeout errors

**Symptom:**
```
** (exit) {{timeout, ...}, [...]}
```

**Causes:**
1. Actor is overloaded
2. Timeout too short for operation
3. Actor crashed and didn't respond

**Solutions:**

1. **Increase timeout:**
```gleam
// From:
actor.call(subject, Message, 5000)

// To:
actor.call(subject, Message, 30000)  // 30 seconds
```

2. **Check actor is running:**
```gleam
import gleam/io

io.println("About to call actor...")
let result = actor.call(subject, Message, 5000)
io.println("Actor responded")
io.debug(result)
```

3. **Add error handling:**
```gleam
case actor.call(subject, Message, 5000) {
  Ok(result) -> // Handle success
  Error(timeout) -> {
    io.println("Actor timed out!")
    // Handle timeout
  }
}
```

#### Issue: Pattern match failure

**Symptom:**
```
** (MatchError) no match of right hand side value: ...
```

**Cause:** Incomplete pattern matching

**Solution:**
Cover all cases in pattern match:

```gleam
// Wrong:
case result {
  UserSuccess(user) -> // handle
  // Missing cases!
}

// Correct:
case result {
  UserSuccess(user) -> // handle success
  UserNotFound -> // handle not found
  UserError(reason) -> // handle error
}
```

#### Issue: "No function clause matching"

**Cause:** Calling function with wrong types

**Solution:**
Check function signature and provide correct types:
```gleam
// Function expects:
pub fn sample(dist: ZipfDistribution, random: Float) -> Int

// Call with:
zipf.sample(dist, 0.5)  // Not: zipf.sample(0.5, dist)
```

### Performance Issues

#### Issue: Simulation runs very slowly

**Causes:**
1. Too many users
2. Cycle delay too high
3. Timeouts too long

**Solutions:**

1. **Reduce user count:**
```gleam
SimulatorConfig(
  num_users: 20,  // Start small
  ...
)
```

2. **Reduce cycle delay:**
```gleam
SimulatorConfig(
  cycle_delay_ms: 50,  // Faster cycles
  ...
)
```

3. **Optimize actor calls:**
```gleam
// Reduce timeouts for fast operations
actor.call(subject, Message, 1000)  // 1 second
```

#### Issue: Low operations per second

**Causes:**
1. Not enough users
2. Activities not balanced
3. High latency operations

**Solutions:**

1. **Increase users:**
```gleam
SimulatorConfig(
  num_users: 100,
  ...
)
```

2. **Adjust activity mix:**
```gleam
ActivityConfig(
  post_probability: 0.4,      // More posts
  comment_probability: 0.4,   // More comments
  vote_probability: 0.2,      // Fewer votes
  dm_probability: 0.0,        // Disable DMs
)
```

3. **Profile operations:**
```gleam
import gleam/erlang/process

let start = process.system_time()
let result = actor.call(subject, Message, 5000)
let end = process.system_time()
io.println("Operation took: " <> int.to_string(end - start) <> "μs")
```

#### Issue: Memory keeps growing

**Cause:** Metrics collector storing too many latencies

**Solution:**
Already limited to 1000 in code. For longer simulations, reduce:

```gleam
// In metrics_collector.gleam
let trimmed_latencies = list.take(new_latencies, 500)  // Reduced
```

### Logical Errors

#### Issue: Users can't join subreddits

**Debug steps:**

1. Check subreddit exists:
```gleam
let result = actor.call(
  subreddit_manager,
  protocol.GetSubreddit(subreddit_id, _),
  5000
)
io.debug(result)
```

2. Check user exists:
```gleam
let result = actor.call(
  user_registry,
  protocol.GetUser(user_id, _),
  5000
)
io.debug(result)
```

3. Check for error messages:
```gleam
case join_result {
  Ok(_) -> io.println("Joined successfully")
  Error(msg) -> io.println("Failed: " <> msg)
}
```

#### Issue: Feed is empty

**Possible causes:**
1. User hasn't joined any subreddits
2. No posts in joined subreddits
3. Feed limit too low

**Debug:**
```gleam
// Check user's joined subreddits
let user_result = actor.call(user_registry, GetUser(user_id, _), 5000)
case user_result {
  UserSuccess(user) -> {
    io.println("Joined subreddits:")
    io.debug(user.joined_subreddits)
  }
  _ -> Nil
}

// Check posts in subreddit
let posts = actor.call(
  post_manager,
  GetPostsBySubreddit(subreddit_id, _),
  5000
)
io.println("Posts in subreddit:")
io.debug(posts)
```

#### Issue: Votes not affecting karma

**Cause:** Karma calculator not fully implemented (placeholder)

**Note:** In the current implementation, karma calculation is a placeholder. For full implementation, the karma calculator would need to:

1. Query all posts by user
2. Query all comments by user
3. Sum upvotes - downvotes
4. Update user karma

This can be added in future enhancement.

### Testing Issues

#### Issue: Tests fail

**Symptom:**
```bash
gleam test
# Some tests fail
```

**Solutions:**

1. **Check test file:**
```bash
gleam test --target erlang
```

2. **Run specific test:**
```gleam
// In test file, comment out failing tests temporarily
// pub fn failing_test() { ... }
```

3. **Add debug output:**
```gleam
pub fn my_test() {
  let result = some_function()
  io.debug(result)  // See what's happening
  assert result == expected
}
```

### Configuration Issues

#### Issue: Zipf distribution not working as expected

**Debug:**
```gleam
let dist = zipf.new(10, 1.0)
io.println("Testing Zipf distribution:")

// Test probability for each rank
list.each(list.range(1, 10), fn(rank) {
  let prob = zipf.probability(dist, rank)
  io.println("Rank " <> int.to_string(rank) <> ": " <> float.to_string(prob))
})

// Test sampling
let samples = list.map(list.range(1, 100), fn(_) {
  zipf.sample(dist, generate_random())
})
io.println("Sample distribution:")
io.debug(samples)
```

**Expected output:**
- Rank 1 should have highest probability
- Probabilities should decrease as rank increases
- Most samples should be low ranks

#### Issue: Activities not distributed correctly

**Debug:**
```gleam
// In activity_coordinator.gleam, add logging:
fn select_activity_type(config: ActivityConfig) -> ActivityType {
  let random = generate_random()
  io.println("Random: " <> float.to_string(random))
  
  // ... rest of function
}
```

### Development Tips

#### Enable verbose logging

Add throughout your code:
```gleam
import gleam/io

// At function entry
io.println("==> Entering function_name")

// At decision points
io.println("  Condition: " <> string_value)
io.debug(complex_value)

// At function exit
io.println("<== Leaving function_name")
```

#### Check actor state

Add a debug message to your actor:
```gleam
pub type MyMessage {
  // ... existing messages
  DebugState(reply: Subject(State))
}

// In handle_message:
case message {
  // ... existing cases
  DebugState(reply) -> {
    actor.send(reply, state)
    actor.continue(state)
  }
}
```

Usage:
```gleam
let state = actor.call(my_actor, DebugState, 5000)
io.debug(state)
```

#### Monitor message queue length

```gleam
// Check if actor is overwhelmed
// (This is theoretical - actual implementation depends on Gleam/OTP APIs)
```

### When to Ask for Help

If you've tried the above and still have issues:

1. **Minimal reproduction:**
   - Create smallest code that shows problem
   - Remove unrelated code

2. **Error messages:**
   - Copy full error message
   - Note where it occurs (file, line)

3. **Context:**
   - What were you trying to do?
   - What did you expect?
   - What actually happened?

4. **Environment:**
   - Gleam version: `gleam --version`
   - Erlang version: `erl -version`
   - OS: `uname -a` (Linux/Mac) or `ver` (Windows)

## Quick Fixes Checklist

- [ ] Dependencies downloaded? (`gleam deps download`)
- [ ] Project builds? (`gleam build`)
- [ ] Tests pass? (`gleam test`)
- [ ] Timeouts sufficient? (5000ms minimum)
- [ ] All pattern matches complete?
- [ ] Actor started before calling?
- [ ] Reply channel provided (`_`)?
- [ ] Error cases handled?

## Performance Tuning Checklist

- [ ] User count appropriate for testing?
- [ ] Cycle delay optimized?
- [ ] Activity probabilities balanced?
- [ ] Zipf exponent set correctly?
- [ ] Metrics collection not too verbose?
- [ ] Timeout values reasonable?

## Common Anti-Patterns

### ❌ Don't: Block actor with sleep
```gleam
fn handle_message(msg, state) {
  process.sleep(1000)  // BAD! Blocks actor
  // ...
}
```

### ✅ Do: Use message scheduling
```gleam
// Schedule a message for later
process.send_after(subject, Message, 1000)
```

### ❌ Don't: Store large data in actor state
```gleam
State(
  all_historical_data: huge_list,  // Memory issue!
)
```

### ✅ Do: Keep state bounded
```gleam
State(
  recent_items: list.take(items, 1000),  // Limited
)
```

### ❌ Don't: Catch-all error handling
```gleam
case result {
  _ -> io.println("Something happened")  // Hides errors!
}
```

### ✅ Do: Handle each case explicitly
```gleam
case result {
  Ok(value) -> handle_success(value)
  Error(NotFound) -> handle_not_found()
  Error(other) -> handle_other_error(other)
}
```

## Still Stuck?

1. **Read the code:** The implementation is well-commented
2. **Check types:** Gleam's type system guides you
3. **Add logging:** See what's actually happening
4. **Simplify:** Remove complexity until it works
5. **Test parts:** Isolate the problem

Remember: The BEAM VM and OTP are battle-tested. If something isn't working, it's usually the application logic, not the platform.

