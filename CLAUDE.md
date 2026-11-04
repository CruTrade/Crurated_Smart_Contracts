@AGENTS.md

## Claude Code specifics

Scoped rules in `.claude/rules/` load automatically when a matching file is read with the Read
tool. They add detail; they do not override `AGENTS.md`.

| File | Applies to |
| --- | --- |
| `.claude/rules/contracts.md` | `src/**` |
| `.claude/rules/tests.md` | `test/**` |
| `.claude/rules/deployment.md` | `script/**`, `deploy.sh`, `env.example`, `broadcast/**`, `foundry.toml`, `.github/**` |

Project skills are available as `/crurated-contracts-workflow` (build, test, review and change the
contract) and `/crurated-contracts-deploy` (deploy, verify, upgrade, rotate roles and read live
state). Their `.claude/skills/` entrypoints point to the canonical `.agents/skills/` files shared
with other agents. Read the referenced file when using a skill.

## Subagents

Run the `skeptic` agent on the exact staged change before every `git commit` and again before every
`git push`. A FAIL verdict blocks the commit or push. If no `skeptic` agent is defined in your
environment, run an independent general-purpose review with the same brief (verify every claim
against the source, PASS or FAIL) and say so.

Use `Explore` only for questions that span the consumer repositories; this repository is small
enough to read directly.

## Verification

`forge build` and `forge test` are the checks. Do not claim a contract change works without running
them. For a change meant for an existing deployment, also compare `forge inspect Crurated
storage-layout` with the table in `AGENTS.md`. To prove which source is deployed, compare the
compiled runtime bytecode with the on-chain implementation after masking the UUPS `__self`
immutable (inlined at three places) and the metadata trailer.
