//! Compatibility adapter; canonical implementation lives in zkp-core.
pub use zkp_core::field::*;

// Application-level fault injection stays with the legacy verifier tests.
#[cfg(test)]
pub(crate) mod verifier_hardening_tests;
