// # TASK-039: Multi-Device Support Design

// ## Problem
// A user running DriftSonar on an iPad and iPhone should be able to share the same
// cryptographic identity so their posts appear under one fingerprint.

// ## Option A: iCloud Keychain Sync (recommended for MVP+1)

// Store both private keys (`agreement` and `signing`) in iCloud Keychain with
// `kSecAttrSynchronizable: true`. The OS automatically syncs to all devices signed
// in to the same Apple ID.

// ```swift
// var query: [String: Any] = [
//     kSecClass as String:            kSecClassKey,
//     kSecAttrAccount as String:      KeychainService.signingPrivateKeyAccount,
//     kSecAttrSynchronizable as String: true,   // ← enable iCloud sync
//     kSecValueData as String:        privateKeyData,
// ]
// SecItemAdd(query as CFDictionary, nil)
// ```

// ### Pros
// - Zero infrastructure required.
// - End-to-end encrypted by Apple (keys never leave the Secure Enclave on each device).

// ### Cons
// - Requires iCloud sign-in — not universally available.
// - `kSecAttrSynchronizable` is incompatible with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
//   Protection level must be weakened to `.whenUnlocked` (still strong, but cloud-synced).

// ## Option B: Manual QR Export

// Export the private key as an encrypted QR code (AES-256-GCM, key derived from a
// user-chosen PIN via Argon2id). The receiving device scans and imports.

// ### Pros
// - No iCloud dependency.
// - User has explicit control over key transfer.

// ### Cons
// - UX friction: user must be near both devices simultaneously.
// - PIN brute-force risk if QR is leaked (mitigated by Argon2id cost).

// ## Decision
// - **Phase 1 (MVP+1)**: implement iCloud Keychain sync with a user toggle.
// - **Phase 2**: add QR export as a fallback for users without iCloud.

// ## Status
// Design approved. Implementation deferred to post-MVP. (TASK-039)

// This file is intentionally empty of executable code — it is a design specification document.
