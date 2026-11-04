---
paths:
  - "test/**"
---

# Test rules

- `test/Crurated.t.sol` has 44 tests. `setUp` deploys the implementation with `(owner, admin)`,
  wraps it in an `ERC1967Proxy` with `initialize(owner, admin)` and registers four statuses as the
  admin. New tests use the same proxy path; never test the bare implementation as if it were the
  deployed contract.
- Assert exact revert data: `bytes("Caller is not admin")` for admin checks,
  `OwnableUnauthorizedAccount(address)` for owner checks, `TokenSoulbound()`, `EnforcedPause()`,
  `InvalidBatchInput()`, `ZeroMintAmount()`, `TokenNotExists(uint256)`, `StatusNotExists(uint256)`.
- A behaviour change needs a test that fails before it and passes after it. Do not weaken or delete
  an existing assertion to make a change pass.
- An upgrade change needs a test that writes state through the old implementation, upgrades through
  the proxy, and reads the same state (token count, CIDs, status names, admin) afterwards.
- There are no fuzz or invariant tests yet. Prefer adding fuzz tests for batch length checks and ID
  sequencing over hand-written examples when touching that logic.
- Run `forge test` (and `-vvvv` on the failing test) before reporting a result, and report the pass
  and fail counts you actually saw.
