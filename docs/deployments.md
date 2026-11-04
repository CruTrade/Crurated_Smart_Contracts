# Deployments

Read-only verification on **2026-11-04 (15:37–16:55 UTC)** against Avalanche public RPC
(`api.avax.network`, `api.avax-test.network`) and the Routescan explorer API. Mainnet reads were made
at blocks 99415445–99416014. Re-check before relying on any of this; owners and admins can change.

## Source equivalence

`main@af61c74` was compiled with solc-js 0.8.30, optimizer 200 runs, OpenZeppelin 5.0.1 (EVM
`cancun` and `prague` give the same runtime). The runtime bytecode of both live implementations
(11,436 bytes) is identical to that build after masking the UUPS `__self` immutable (the
implementation's own 20-byte address, inlined at three places). Only the CBOR metadata hash differs from the local build. Both
live implementations carry the **same** metadata hash, so they come from one build.

Routescan has verified source only for the proxies (`ERC1967Proxy`, solc 0.8.30). The
implementations are not explorer-verified.

## Avalanche C-Chain (43114)

| Item | Value |
| --- | --- |
| Proxy | `0x0cBbb0F48821Dd87441B49E556e08A191B0A485E` |
| Implementation | `0x168bb1c941f37983f41ff733c8d6123c5511a886` (only one; one `Upgraded` event) |
| Deployer (EOA) | `0x45a0744065e5455caac18aacb99bbb64154f8cfb` |
| Implementation tx | `0x84a66abc4854b5dbd8709415245dc5ca53c6f96a7142cd82f5b323e3408defa6` |
| Proxy tx (with `initialize`) | `0x890258abb3acb51e033b8a80e32355e9bef9c6cb9db3f27d3b50c9e7d993371f` |
| Block / time | 65145111, 2025-07-08 18:40:11 UTC |
| Owner | `0xE8c2E3Fb20810b5b65361A54e51b8B3F30e545E9`, a Safe 1.4.1 with threshold **1** and one signer `0x9bA452E7B0303893870ed30580B04d6B1a35D5E8` |
| Admin | `0xA09f81c331b61991C3E08b54447a47C1d7CBd4fD` (EOA) since block 94944973 (2026-09-10); previously `0x00e6De87a795f43fc920eDAD04103bF339B8D9d9` (EOA) |
| Paused | never (no `Paused` event) |
| Tokens | 471,445 (`tokenCount`, slot 1) |
| Status types | 14, registered at blocks 65149254–65149320 on 2025-07-08 |

Storage slots read directly: slot 0 = 14 (`_nextStatusId`), slot 1 = 471445 (`_tokenIds`), slot 4 =
the admin address. This matches the layout table in `AGENTS.md`.

## Avalanche Fuji (43113)

| Item | Value |
| --- | --- |
| Proxy | `0x9eF6d7de627DB2d885Cb3263B387b9979964825c` |
| Implementation | `0xd2c9A004e1271a8C2c0Ba08677112c85f6581df4` (only one) |
| Deployer and owner | `0x45a0744065e5455CaAC18aACB99bBB64154F8cfb` (EOA) |
| Proxy creation | block 42937311, 2025-07-03 16:06:04 UTC, tx `0x7c09d2e8357b379ac46992e5af6643b36d55ba5caaee2fac9deb82299c9ac152` |
| Admin | `0xabcbBAa4690Bb632CD8c6c5655f3a06324838d2A` (EOA) since block 44423445 (2025-08-06); previously `0x53dD1be9A3d4085EDEb527626c5Ca41248c5F86b` |
| Paused | never |
| Tokens | 119,829 |
| Status types | 14, same names and order as mainnet |

## Registered status types (both networks)

| ID | Name | ID | Name |
| --- | --- | --- | --- |
| 1 | `1` | 8 | `3.2` |
| 2 | `2` | 9 | `3.3` |
| 3 | `3` | 10 | `3.4` |
| 4 | `4` | 11 | `4.1` |
| 5 | `5` | 12 | `4.2` |
| 6 | `6` | 13 | `5.1` |
| 7 | `3.1` | 14 | `5.2` |

Consumers depend on these IDs. A new deployment must register them in this order.

## Committed broadcast files

`broadcast/Deploy.s.sol/43113/` holds five Fuji test runs from commits `d691833` and `b4f9e5a`
(2025-06-23 to 2025-07-02). None of them is the live Fuji proxy above, and there is no mainnet
broadcast in the repository. Because one deployer was used on both chains, some of those Fuji test
addresses equal mainnet addresses (`0x168bb1c9…` is a Fuji test proxy and the mainnet implementation;
`0x0cbbb0f4…` is a Fuji test implementation and the mainnet proxy).

## Not verified

- The audit referred to by commit `a75987b` ("audit fix"); no report is in the repository.
- Who controls the Safe signer or the admin keys.
- The unmerged branch `feat/HierachicalAccessControl` (`dc0c447`, role hierarchy and ownership
  manager) is not deployed anywhere checked here.
