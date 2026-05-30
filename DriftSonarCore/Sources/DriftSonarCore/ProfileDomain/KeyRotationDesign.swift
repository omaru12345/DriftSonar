// # TASK-038: Key Rotation Design

// ## Problem
// Users may need to rotate their signing/encryption keys due to:
// - Suspected key compromise.
// - Migrating to a new device (see also TASK-039).
// - Periodic rotation as a security hygiene practice.

// ## Key Rotation Announcement Message

// A special `Post` subtype with `content` structured as JSON:
// ```json
// {
//   "type": "key_rotation",
//   "oldPublicKey": "<base64>",
//   "newPublicKey": "<base64>",
//   "timestamp": 1740000000,
//   "signature": "<base64, signed by OLD key>"
// }
// ```

// The announcement must be **signed by the old key** to prove ownership.
// Recipients who have seen the old key in their encounter history should update
// their local mapping and trust future posts from the new key.

// ## Handling Old Posts
// Posts signed with the old key remain valid for their original TTL period.
// After key rotation is announced and propagated, old-key posts should be:
// - Displayed with a "(旧鍵)" badge in the timeline.
// - No longer accepted for relay if `hopCount == 0` and post `timestamp < rotationTimestamp`.

// ## Implementation Steps (deferred)
// 1. Define `KeyRotationPost` struct (or extend `Post` with a `postType` discriminator).
// 2. Add `KeyRotationRepository` to persist known rotations.
// 3. Update `MeshForwardingService.receive()` to detect and route key rotation messages.
// 4. Update `TimelineView` to badge posts from rotated keys.

// ## Status
// Design approved. Implementation deferred to post-MVP. (TASK-038)

// This file is intentionally empty of executable code — it is a design specification document.
