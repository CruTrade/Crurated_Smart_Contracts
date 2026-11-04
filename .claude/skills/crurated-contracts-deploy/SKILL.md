---
name: crurated-contracts-deploy
description: Deploy the Crurated contract locally, to Avalanche Fuji or to mainnet, verify it on the explorer, upgrade the implementation, rotate the admin or owner, or read live on-chain state (owner, admin, implementation, token count, status types). Real-chain writes need the user's explicit instruction.
---

Read and follow the [canonical Crurated deploy runbook](../../../.agents/skills/crurated-contracts-deploy/SKILL.md) before working on the request. Resolve that link from this file, then resolve the canonical skill's links from its own directory. This entrypoint supplies Claude Code discovery without duplicating those instructions.

Apply `CLAUDE.md`, `AGENTS.md` and `.claude/rules/deployment.md`. Invoking the skill does not authorise any broadcast or Safe transaction, and does not bypass the mandatory skeptic review before commits and pushes.
