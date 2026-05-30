// # TASK-030: Anonymous Posting Design

// ## Overview
// DriftSonar allows users to post under a persistent identity (their Ed25519 signing key).
// An anonymous option would let users post without linkability to their main identity.

// ## Design

// ### Ephemeral Key Pair
// For each anonymous post, generate a fresh `Curve25519.Signing.PrivateKey`:
// ```swift
// let ephemeralSigning = Curve25519.Signing.PrivateKey()
// let post = Post(
//     id: UUID(),
//     content: content,
//     authorPublicKey: ephemeralSigning.publicKey.rawRepresentation,
//     ...
// )
// ```
// The ephemeral private key is **never persisted** — it is used once, then discarded.

// ### Separation Guarantee
// - The ephemeral public key (32 bytes) has no cryptographic link to the user's main key.
// - Relaying nodes cannot distinguish anonymous posts from regular posts.
// - The user cannot reclaim or continue an anonymous identity after the key is discarded.

// ### UI Flow
// - `ComposeView` gains a toggle: "匿名で投稿する"
// - `CreatePostUseCase` accepts `authorPrivateKey: Data?` — `nil` triggers ephemeral generation.
// - Anonymous posts show "匿名" fingerprint in TimelineView instead of the real fingerprint.

// ### Risks
// - A malicious node could track post content across multiple "anonymous" posts if the user
//   posts unique phrases. Content anonymity is the user's responsibility.
// - PoW (TASK-034) should be considered mandatory for anonymous posts to prevent spam.

// ### Status
// This design is approved. Implementation deferred to post-MVP. (TASK-030)

// This file is intentionally empty of executable code — it is a design specification document.
