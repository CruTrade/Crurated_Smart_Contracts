---
name: crurated-contracts-workflow
description: Build, test, review or change the Crurated soulbound ERC-1155 provenance contract (src/Crurated.sol, src/abstracts/CruratedBase.sol), explain its behaviour, or prove which source is deployed. Use only in this repository; deployments, upgrades and role changes belong to crurated-contracts-deploy.
---

# Crurated contracts workflow

Read [AGENTS.md](../../../AGENTS.md) first. Run commands from the repository root. In Claude Code,
also apply the matching `.claude/rules/` file. Keep the user's scope: a review or explanation does
not authorise code changes, and no step here authorises a broadcast.

## 1. Set up

```bash
forge soldeer install    # dependencies/ is git-ignored
forge build
forge test               # expect 44 passing tests on main@af61c74
```

If `forge test` does not report 44 passing tests on an unmodified `main`, stop and report the
output; do not continue on a broken baseline.

## 2. Answer behaviour questions from the source

Use the behaviour, roles and storage tables in `AGENTS.md`, then confirm in the code.
`README.md` describes an older API; do not quote it. Typical answers:

- "Who can mint?" The `admin`, never the owner. Tokens always go to `owner()`.
- "Where is the history?" Only in `ProvenanceUpdated` events; read them from logs or the subgraph.
- "Can a bottle be minted twice?" Yes. The contract has no serial number and no duplicate check.
- "Can a token be transferred?" No. Every transfer and approval reverts `TokenSoulbound()`.

## 3. Change the contract

1. State whether the change targets the existing deployments (an upgrade) or a new deployment.
2. Write the failing test first in `test/` (see `.claude/rules/tests.md`), then change `src/`.
3. Run `forge build` and `forge test`. Report the real counts.
4. For an upgrade, run `forge inspect Crurated storage-layout` and compare it slot by slot with
   `AGENTS.md`. Slots 0–4 must be unchanged.
5. List the consumer impact: blockchain-service (ABI in its config and its mint receipt parsing),
   crurated-subgraph (event signatures), and the integrity scanner through blockchain-service
   (`tokenCount`, per-token checks). A signature,
   event or error change is a cross-repository change.
6. Run the `skeptic` review on the staged diff before committing.

## 4. Prove which source is deployed

1. Read the implementation address from the proxy's EIP-1967 slot
   `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`, and its runtime code, at a
   recorded block.
2. Compile the candidate commit with the `foundry.toml` settings (solc 0.8.30, 200 runs) and take
   `deployedBytecode`.
3. Strip the CBOR metadata trailer from both. Its length is the last two bytes plus two.
4. Replace the three 20-byte occurrences of the implementation's own address in the on-chain code
   with zeros; these are the UUPS `__self` immutable.
5. The rest must be byte-identical. Report the commit, block, both sizes and whether the metadata
   hash matches. `docs/deployments.md` holds the 2026-11-04 result for `af61c74`.

## 5. Report

Lead with the answer. Then give `file:line` evidence, the commands run and their counts, and what
was not checked (chain state, consumers, audit status). Keep verified facts separate from
inferences.
