---
paths:
  - "src/**"
---

# Contract rules

- `src/Crurated.sol` holds roles, the batch entry points and the soulbound overrides.
  `src/abstracts/CruratedBase.sol` holds storage, events, errors and internal logic. Keep that split.
- The deployed implementations are executable-equal to `main@af61c74` (metadata hash differs; see
  `docs/deployments.md`). Any change to `src/` is a new implementation that only takes effect through
  `upgradeToAndCall` by the owner (mainnet: a Safe; Fuji: an EOA). Say so when proposing it.
- Storage: never reorder, retype or remove `_nextStatusId`, `_tokenIds`, `_cids`, `_statusNames`
  (slots 0–3, `CruratedBase`) or `admin` (slot 4, `Crurated`). Append new variables at the end of
  `Crurated`; adding one to `CruratedBase` shifts `admin`. Check with
  `forge inspect Crurated storage-layout`.
- Do not change function signatures, event signatures, error selectors, status ID semantics or the
  "mint to `owner()` in submission order" rule without coordinating the consumers listed in
  `AGENTS.md`. Off-chain code maps IDs to CIDs from the mint event: `TransferSingle` for one CID,
  `TransferBatch` (IDs in submitted CID order) for several.
- Keep the soulbound overrides `pure` and reverting `TokenSoulbound()`.
- Every new state-changing entry point needs an explicit role (`onlyAdmin` or `onlyOwner`) and a
  deliberate choice about `whenNotPaused`.
- Do not add `renounceOwnership` calls, external calls or payable functions.
- Keep the `require` strings that tests and consumers match (`"Caller is not admin"`,
  `"Admin cannot be zero address"`, `"Owner cannot be zero address"`); use custom errors for new
  checks.
