# AGENTS.md

Foundry project for **Crurated**, an upgradeable, soulbound ERC-1155 that records wine-bottle
provenance on Avalanche. One token is one collectible (normally one bottle). Its metadata lives on
IPFS; its provenance history lives only in `ProvenanceUpdated` events. Every token is minted to the
contract `owner()` (the custodian) and can never be transferred.

The code is small: `src/Crurated.sol` (roles, batch entry points, soulbound overrides) on top of
`src/abstracts/CruratedBase.sol` (storage, events, errors, internal logic). Dated deployment facts
are in [docs/deployments.md](docs/deployments.md); the deployment runbook is the
[`crurated-contracts-deploy` skill](.agents/skills/crurated-contracts-deploy/SKILL.md).

**`README.md` is out of date.** It documents `migrate(Data[])`, `updateCurrentStatus`,
`updateHistoricalStatus`, `uint40` timestamps and "only owner can mint". None of these exist. The
source and this file are authoritative.

## Toolchain

| Item | Value | Source |
| --- | --- | --- |
| Solidity | `0.8.30`, optimizer on, 200 runs, no `via_ir` | `foundry.toml` |
| EVM version | not pinned (Foundry default) | `foundry.toml` |
| Dependencies | OpenZeppelin contracts and contracts-upgradeable `5.0.1`, forge-std `1.9.7`, via Soldeer | `soldeer.lock`, `remappings.txt` |
| Dependency folder | `dependencies/`, git-ignored; run `forge soldeer install` | `.gitignore` |
| CI | GitHub Actions: Foundry **nightly**, `forge soldeer install`, `forge build`, `forge test` | `.github/workflows/ci.yml` |

```bash
forge soldeer install   # fetch pinned dependencies into dependencies/
forge build
forge test              # 44 tests in test/Crurated.t.sol
forge test --match-test testMigration -vvvv
forge inspect Crurated storage-layout
```

CI uses Foundry nightly, so a CI pass is not a reproducible toolchain statement. The slither,
coverage, snapshot and `forge fmt --check` steps are commented out in CI. Do not run `forge fmt`
over the repository as part of an unrelated change.

## Contract behaviour

| Area | Behaviour | Code |
| --- | --- | --- |
| Name, symbol | `"Crurated"`, `"CRURATED"`, constants | `CruratedBase.sol:29-32` |
| Token IDs | Sequential from 1; `tokenCount()` is the last ID | `CruratedBase.sol:218-226` |
| Metadata | `uri(id) = "ipfs://" + cid`; reverts `TokenNotExists` for unknown IDs | `CruratedBase.sol:171-173` |
| Mint | `mint(cids, amounts)`: one new ID per CID, `amount > 0`, all minted to `owner()` via `_mintBatch`: one `TransferSingle` for a single CID, otherwise one `TransferBatch` | `Crurated.sol` `mint` |
| Migrate | `migrate(cids, amounts, statuses[][])`: mint plus historical statuses in one transaction | `Crurated.sol` `migrate` |
| Provenance | `update(tokenIds, statuses[][])` emits `ProvenanceUpdated(tokenId, statusId, timestamp, reason)` per entry; nothing is stored | `CruratedBase.sol:262-269` |
| Timestamps | Caller supplied and unchecked (past, future or zero are accepted) | `CruratedBase.sol:262-269` |
| Status types | `addStatus(name)` assigns IDs 1, 2, …; `statusName(id)`; `nextStatusId()` returns the *next* ID | `CruratedBase.sol:197-207`, `:245-253` |
| CID changes | `setCIDs(tokenIds, cids)` overwrites CIDs and emits `MetadataUpdated` | `CruratedBase.sol:233-238` |
| Soulbound | `safeTransferFrom`, `safeBatchTransferFrom`, `setApprovalForAll` always revert `TokenSoulbound()` (`0x892ea3df`) | `Crurated.sol` soulbound overrides |
| Pause | Blocks `mint`, `migrate`, `update`, `setCIDs`; does **not** block `addStatus` or owner functions | `Crurated.sol` |

Mint and migrate do **not** emit `MetadataUpdated` or `URI`. Off-chain consumers map new IDs to CIDs
through the mint event: `TransferSingle` (`id`) for one CID, `TransferBatch` (`ids`, in submitted
CID order) for several. Receipt parsing must handle both.

There is no serial number, SKU or other bottle identifier on chain, and no duplicate protection.
Uniqueness is entirely an off-chain responsibility of the caller.

### Roles

| Role | Holder type | Can call |
| --- | --- | --- |
| `owner` (OpenZeppelin `Ownable`) | Set at `initialize` | `pause`, `unpause`, `setAdmin`, `upgradeToAndCall`, `transferOwnership`, `renounceOwnership` |
| `admin` (single address, `Crurated.sol`) | Set at `initialize`, changed by `setAdmin` | `mint`, `migrate`, `update`, `setCIDs`, `addStatus` |

The owner cannot call admin functions and the admin cannot call owner functions. Tests cover the
owner side for all five admin functions (`testOnlyAdminCan*`). The admin side is tested for
`setAdmin`, `pause` and `unpause` only, not for `upgradeToAndCall`, `transferOwnership` or
`renounceOwnership`.
`onlyAdmin` reverts with the string `"Caller is not admin"`; owner checks revert with
`OwnableUnauthorizedAccount(address)`. `setAdmin` emits `AdminChanged(previous, new)`.

Minting depends on the owner address, because every token is minted to `owner()`:

- `_mintBatch` reverts `ERC1155InvalidReceiver` for the zero address, so `renounceOwnership()`
  (still exposed) would permanently break `mint` and `migrate` as well as pause, admin rotation and
  upgrades. Never call it.
- When the owner is a contract, OpenZeppelin calls `onERC1155Received` /
  `onERC1155BatchReceived` on it. An owner contract without those hooks (for example a Safe without
  a fallback handler that implements them) makes every mint revert. The test owner is a plain
  address, so tests do not cover this.

### Storage layout and upgrades

OpenZeppelin 5 upgradeable parents use ERC-7201 namespaced storage, so the contract's own variables
start at slot 0. Verified on the mainnet proxy on 2026-11-04 (see `docs/deployments.md`):

| Slot | Variable | Declared in |
| --- | --- | --- |
| 0 | `_nextStatusId` (`uint256`) | `CruratedBase` |
| 1 | `_tokenIds` (`uint256`) | `CruratedBase` |
| 2 | `_cids` (`mapping(uint256 => string)`) | `CruratedBase` |
| 3 | `_statusNames` (`mapping(uint256 => string)`) | `CruratedBase` |
| 4 | `admin` (`address`) | `Crurated` |

Upgrades are UUPS: the owner calls `upgradeToAndCall` on the proxy (`_authorizeUpgrade` is
`onlyOwner`). A new implementation must keep slots 0–4 in place and only append. There is no
storage gap and no automated layout check; compare `forge inspect Crurated storage-layout` before and
after. Because `CruratedBase` variables come before `admin`, adding a variable to `CruratedBase`
shifts `admin` and corrupts it. The implementation constructor takes `(owner, admin)` and requires
both to be non-zero; the value it writes to `admin` lands in the implementation's own storage and has
no effect on the proxy.

## Deployments

| Network | Proxy | Implementation | Since |
| --- | --- | --- | --- |
| Avalanche C-Chain (43114) | `0x0cBbb0F48821Dd87441B49E556e08A191B0A485E` | `0x168bb1c941f37983f41ff733c8d6123c5511a886` | block 65145111, 2025-07-08 |
| Avalanche Fuji (43113) | `0x9eF6d7de627DB2d885Cb3263B387b9979964825c` | `0xd2c9A004e1271a8C2c0Ba08677112c85f6581df4` | block 42937311, 2025-07-03 |

Neither proxy has ever been upgraded or paused. Both implementations are executable-equal to
`main@af61c74` and share one metadata hash; only the proxy source is explorer-verified. Owners,
admins, status registrations and the evidence behind these claims are in `docs/deployments.md`.

`broadcast/Deploy.s.sol/43113/` contains only earlier Fuji test runs. None of them created the live
Fuji proxy, and no mainnet broadcast is committed. The same deployer EOA was used on both chains, so
the same address can be a proxy on one chain and an implementation on the other (for example
`0x168bb1c9…` is the mainnet implementation but a Fuji test proxy). Always state the chain with an
address.

## Known limitations

These follow from the code. Report them; do not "fix" a deployed behaviour without an explicit
upgrade decision.

- No on-chain duplicate protection: retrying a mint creates a second token.
- One admin key can mint, rewrite history and rewrite metadata (`setCIDs`) for every token.
- History is event-only, with caller-chosen timestamps; the contract cannot answer "what is the
  history of token X".
- `amount` is any positive number; nothing enforces one unit per bottle.
- `nextStatusId()` returns the next free ID, not the last one.
- `deploy.sh verify` does not work (see the deploy skill).

## Consumers

The ABI and event shapes are consumed outside this repository: the CruTrade `blockchain-service`
(mints, migrates, updates and repairs CIDs through the admin key), the `crurated-subgraph` indexer
(all events except `AdminChanged`, mainnet start block 65145111) and, indirectly through
blockchain-service, an NFT integrity scanner (token count from `tokenCount()`, per-token checks). Any change to a function signature, event, error, status ID or
the token-to-CID mapping breaks them. Coordinate such a change with those repositories first.

## Safety boundaries

- `forge script … --broadcast`, `./deploy.sh testnet|mainnet`, `cast send` and any Safe transaction
  act on real chains. Run them only on the user's explicit, specific instruction. A dry run is
  `forge script` without `--broadcast`.
- Read-only on-chain checks (`cast call`, `eth_getStorageAt`, explorer APIs) are allowed for
  diagnosis. Record the block number and UTC time.
- Never commit `.env` or print `PRIVATE_KEY`. The Anvil key in `script/Deploy.s.sol` is the public
  Anvil default and is only for local chains.
- Commits, pushes, tags and pull requests happen only when the user asks, and each needs a
  `skeptic` review first.

## Conventions

- English for code, comments, docs and commit messages; Conventional Commits.
- Custom errors in `CruratedBase.sol`; existing `require` strings stay (tests and consumers match
  them).
- New tests go in `test/` with `forge-std`; follow the existing `setUp` (implementation plus
  `ERC1967Proxy`, statuses registered by the admin).
