---
name: crurated-contracts-deploy
description: Deploy the Crurated contract locally, to Avalanche Fuji or to mainnet, verify it on the explorer, upgrade the implementation, rotate the admin or owner, or read live on-chain state (owner, admin, implementation, token count, status types). Real-chain writes need the user's explicit instruction.
---

# Crurated contracts: deploy, verify, upgrade, operate

Read [AGENTS.md](../../../AGENTS.md) and [docs/deployments.md](../../../docs/deployments.md)
first. Every command that sends a transaction to Fuji or mainnet needs the user's explicit
instruction for that network and that action. Local Anvil needs no approval.

## What the repository provides

| Entry point | What it does |
| --- | --- |
| `script/Deploy.s.sol` `runLocal()` | Deploys implementation and `ERC1967Proxy` with the public Anvil account as owner and admin |
| `script/Deploy.s.sol` `runTestnet()` / `runMainnet()` | Reads `PRIVATE_KEY`, `OWNER`, `ADMIN`; deploys `new Crurated(owner, admin)` and `new ERC1967Proxy(impl, initialize(owner, admin))` |
| `script/Deploy.s.sol` `run()` | Same, with `NETWORK` read from the environment |
| `deploy.sh local` | Starts `anvil` in the background on `localhost:8545` if nothing answers there, then runs `runLocal()` with `--broadcast` |
| `deploy.sh testnet` / `mainnet` | Loads `.env`, checks `PRIVATE_KEY` and `OWNER`, runs `runTestnet()` / `runMainnet()` with `--broadcast --verify` |
| `deploy.sh verify` | Broken; see below |

`env.example` lists the variables: `PRIVATE_KEY`, `OWNER`, `ADMIN`, `AVALANCHE_MAINNET_RPC`,
`AVALANCHE_FUJI_RPC`, optional `GAS_LIMIT`, `GAS_PRICE`, `NETWORK`.

Known defects in these scripts, found by reading them:

- `deploy.sh` does not check `ADMIN`; the Solidity script then fails at `vm.envAddress("ADMIN")`.
- `deploy.sh mainnet` asks for no confirmation.
- `foundry.toml` has no `[etherscan]` section, so `--verify` has no Avalanche verifier configured.
  The live implementations are not explorer-verified.
- `deploy.sh verify` passes an address to `--target-contract` (which expects a contract name), and
  `verifyDeployment()` reads the script's own `proxy` and `owner` storage, which are empty in a new
  run. Use the `cast` checks below instead.
- `deploy.sh local` leaves the Anvil process it started running.
- `deploy.sh` exports each `.env` line verbatim, so an inline comment becomes part of the value
  (`NETWORK=testnet  # local, testnet, or mainnet` in `env.example`). Keep comments on their own
  lines.
- `GAS_LIMIT` and `GAS_PRICE` from `env.example` are not read by any script.

## Local deployment

```bash
anvil                                   # separate terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast --sig "runLocal()"
```

Then register the status types (next section) with the Anvil key. Owner and admin are the same
Anvil account, so this does not exercise role separation.

## New Fuji or mainnet deployment

1. Confirm with the user: network, `OWNER` (a Safe with a real threshold, not an EOA), `ADMIN` (the
   signer that will mint, for example a relayer address), and the deployer key that pays gas.
   `OWNER` receives every token. Because the recommended owner is a contract, it must implement the
   ERC-1155 receiver hooks (a Safe needs a fallback handler that does); otherwise every mint reverts.
2. Prepare `.env` from `env.example`. Never commit or print it.
3. `forge build && forge test`; stop on any failure.
4. Dry run without `--broadcast`:
   `forge script script/Deploy.s.sol:Deploy --rpc-url "$AVALANCHE_FUJI_RPC" --sig "runTestnet()"`.
   Check the logged owner and admin.
5. On explicit approval only, broadcast:
   `forge script script/Deploy.s.sol:Deploy --rpc-url "$AVALANCHE_FUJI_RPC" --broadcast --sig "runTestnet()"`
   (mainnet: `$AVALANCHE_MAINNET_RPC` and `runMainnet()`).
6. Verify the state with `cast` (next section): implementation slot, `owner()`, `admin()`,
   `tokenCount() == 0`, `paused() == false`.
7. As the admin, register the 14 status types in this exact order, because consumers depend on the
   IDs: `1`, `2`, `3`, `4`, `5`, `6`, `3.1`, `3.2`, `3.3`, `3.4`, `4.1`, `4.2`, `5.1`, `5.2`
   (`cast send <proxy> "addStatus(string)" "3.1" …`). Confirm with `statusName(1..14)` and
   `nextStatusId() == 15`.
8. Explorer verification (Routescan's documented form; not executed in this repository):

   ```bash
   forge verify-contract <implementation> src/Crurated.sol:Crurated \
     --verifier etherscan \
     --verifier-url "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan" \
     --etherscan-api-key verifyContract --compiler-version 0.8.30 --num-of-optimizations 200 \
     --constructor-args "$(cast abi-encode 'constructor(address,address)' "$OWNER" "$ADMIN")"
   ```

   Mainnet uses `network/mainnet/evm/43114`. Verify the proxy the same way with
   `ERC1967Proxy` and its constructor arguments.
9. Commit `broadcast/Deploy.s.sol/<chainId>/run-*.json`, then update `docs/deployments.md` with the
   addresses, block, transaction hashes, owner, admin and the date.

## Read live state

```bash
P=0x0cBbb0F48821Dd87441B49E556e08A191B0A485E      # mainnet proxy; Fuji: 0x9eF6d7de627DB2d885Cb3263B387b9979964825c
cast storage $P 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url "$RPC"   # implementation
cast call $P "owner()(address)"       --rpc-url "$RPC"
cast call $P "admin()(address)"       --rpc-url "$RPC"
cast call $P "paused()(bool)"         --rpc-url "$RPC"
cast call $P "tokenCount()(uint256)"  --rpc-url "$RPC"
cast call $P "nextStatusId()(uint256)" --rpc-url "$RPC"
cast call $P "uri(uint256)(string)" 121327 --rpc-url "$RPC"   # a mainnet token ID; use an ID <= tokenCount() on Fuji
```

Pin `--block <n>` and record it with the UTC time in any report. Event history (upgrades, admin
changes, status types) comes from `cast logs` or the explorer's logs API filtered by address and
topic.

## Upgrade the implementation

There is no upgrade script. Upgrades change live state for every consumer: explicit approval only.

1. Implement and test per the `crurated-contracts-workflow` skill, including the storage-layout
   comparison and an upgrade test that preserves state.
2. Deploy the new implementation: `new Crurated(owner, admin)` with non-zero arguments (the values
   do not affect the proxy).
3. Build the owner transaction `upgradeToAndCall(newImplementation, 0x)` on the proxy and submit it
   through the owner Safe. Simulate it first against the current block.
4. Afterwards confirm the `Upgraded` event, the new implementation slot, unchanged `owner`, `admin`,
   `tokenCount`, a sample `uri`, and `statusName(1..14)`.

## Rotate the admin or the owner

- Admin: the owner calls `setAdmin(newAdmin)`; check `AdminChanged` and `admin()`. The indexer does
  not index `AdminChanged`, so record the change in `docs/deployments.md`.
- Owner: `transferOwnership(newOwner)` is single-step (no `acceptOwnership`). A wrong address is
  unrecoverable; confirm the target can sign and can receive ERC-1155 (see `AGENTS.md`, Roles)
  first, because every later mint goes to it. Never call `renounceOwnership()`: it also breaks
  minting.
- Pause: the owner calls `pause()` / `unpause()`. Pause stops `mint`, `migrate`, `update` and
  `setCIDs`, not `addStatus`.

## Report

Lead with what changed on which chain. Give the transaction hashes, block numbers, UTC times,
addresses and post-checks, and state anything not verified (explorer verification, Safe signers,
consumers updated).
