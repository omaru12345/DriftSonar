// # TASK-034: Proof-of-Work Design (Spam Prevention)

// ## Motivation
// Any node can inject posts into the mesh. Without a cost mechanism, a single device
// could flood the network with thousands of posts per second, exhausting peer caches
// and bandwidth. Proof-of-Work (PoW) imposes a computational cost per post.

// ## Chosen Algorithm: Hashcash-style leading-zero SHA-256

// Post ID (UUID) + a `nonce: UInt64` field is hashed. Valid posts must satisfy:
// ```
// SHA256(postId.uuidString + String(nonce)).leadingZeroBits >= difficulty
// ```

// ### Wire Format Addition
// Add `nonce: UInt64` (8 bytes) to the `Post` struct and `PostSerializer`.
// The difficulty constant lives in `DriftSonarConstants`:
// ```swift
// public static let powDifficulty: Int = 16  // 16 leading zero bits ≈ 65536 iterations avg
// ```

// ### Battery Impact Estimate (iPhone 14, A15 Bionic)
// - SHA-256 throughput: ~400 MH/s (hardware-accelerated CryptoKit)
// - Expected iterations for difficulty 16: 2^16 ≈ 65,536
// - Expected time: < 0.2 ms — negligible battery impact.
// - Max safe difficulty for < 1 s on old devices (iPhone X, A11): ~difficulty 22 (~4M iter)

// ### Validation
// In `MeshForwardingService.receive(payload:)`, after signature verification:
// ```swift
// if config.requirePoW {
//     guard ProofOfWorkService.verify(post: post, difficulty: config.powDifficulty) else {
//         return false
//     }
// }
// ```

// ### Recommendation
// - Default difficulty: **18** (≈262K iterations, < 1 ms on A15, < 50 ms on A11)
// - Require PoW for anonymous posts (TASK-030) — prevents throwaway spam identities.
// - Do **not** require PoW for regular posts in MVP to keep UX smooth; introduce as a
//   rate-limiting fallback if abuse is observed.

// ### Status
// Design approved. Implementation deferred to post-MVP. (TASK-034)

// This file is intentionally empty of executable code — it is a design specification document.
