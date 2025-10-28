import gleam/int
import gleam/list
import gleam/float

// Zipf distribution implementation for simulating subreddit popularity
// In a Zipf distribution, the frequency of an item is inversely proportional to its rank

pub type ZipfDistribution {
  ZipfDistribution(
    n: Int,           // Number of elements
    s: Float,         // Exponent parameter (typically ~1.0)
    norm: Float,      // Normalization constant
  )
}

// Create a new Zipf distribution
pub fn new(n: Int, s: Float) -> ZipfDistribution {
  let norm = calculate_norm(n, s)
  ZipfDistribution(n: n, s: s, norm: norm)
}

// Calculate the normalization constant (Harmonic number of order n of s)
fn calculate_norm(n: Int, s: Float) -> Float {
  calculate_norm_helper(n, s, 1, 0.0)
}

fn calculate_norm_helper(n: Int, s: Float, current: Int, acc: Float) -> Float {
  case current > n {
    True -> acc
    False -> {
      let term = 1.0 /. float_power(int.to_float(current), s)
      calculate_norm_helper(n, s, current + 1, acc +. term)
    }
  }
}

// Get probability for a given rank (1-indexed)
pub fn probability(dist: ZipfDistribution, rank: Int) -> Float {
  case rank < 1 || rank > dist.n {
    True -> 0.0
    False -> {
      let rank_float = int.to_float(rank)
      1.0 /. { float_power(rank_float, dist.s) *. dist.norm }
    }
  }
}

// Sample from the distribution given a random float [0.0, 1.0)
// Returns the rank (1-indexed)
pub fn sample(dist: ZipfDistribution, random: Float) -> Int {
  sample_helper(dist, random, 1, 0.0)
}

fn sample_helper(dist: ZipfDistribution, random: Float, rank: Int, cumulative: Float) -> Int {
  case rank > dist.n {
    True -> dist.n  // Shouldn't happen, but safety net
    False -> {
      let prob = probability(dist, rank)
      let new_cumulative = cumulative +. prob
      case random <. new_cumulative {
        True -> rank
        False -> sample_helper(dist, random, rank + 1, new_cumulative)
      }
    }
  }
}

// Get the top k items by rank
pub fn top_k(dist: ZipfDistribution, k: Int) -> List(Int) {
  let actual_k = int.min(k, dist.n)
  list.range(1, actual_k)
}

// Helper: Simple float power function
fn float_power(base: Float, exp: Float) -> Float {
  case exp {
    0.0 -> 1.0
    1.0 -> base
    _ -> {
      // For positive integer exponents
      let int_exp = float.truncate(exp)
      case int_exp == 0 {
        True -> 1.0
        False -> float_power_int(base, int_exp)
      }
    }
  }
}

fn float_power_int(base: Float, exp: Int) -> Float {
  case exp {
    0 -> 1.0
    1 -> base
    _ ->
      case exp < 0 {
        True -> 1.0 /. float_power_int(base, -exp)
        False -> {
          case exp % 2 == 0 {
            True -> {
              let half = float_power_int(base, exp / 2)
              half *. half
            }
            False -> base *. float_power_int(base, exp - 1)
          }
        }
      }
  }
}

// Calculate expected frequency for a rank as a percentage
pub fn rank_frequency(dist: ZipfDistribution, rank: Int) -> Float {
  probability(dist, rank) *. 100.0
}

