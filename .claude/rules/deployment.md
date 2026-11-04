---
paths:
  - "script/**"
  - "deploy.sh"
  - "env.example"
  - "broadcast/**"
  - "foundry.toml"
  - ".github/**"
---

# Deployment rules

- Follow the `crurated-contracts-deploy` skill for every deployment, verification, upgrade or role
  change.
- `./deploy.sh testnet`, `./deploy.sh mainnet` and any `forge script … --broadcast` spend real gas and
  create real contracts. Run them only on the user's explicit, specific instruction for that
  network. `deploy.sh mainnet` asks for no confirmation.
- Dry-run first: the same `forge script` command without `--broadcast`.
- Never commit `.env`, never print `PRIVATE_KEY`, never paste a key on a command line that is logged.
- Commit the `broadcast/Deploy.s.sol/<chainId>/run-*.json` files of a real deployment so the
  repository records it; the mainnet deployment of 2025-07-08 is missing today.
- Do not change `foundry.toml` compiler settings (`0.8.30`, optimizer 200 runs) for an upgrade of an
  existing deployment without saying so: bytecode equivalence checks depend on them.
- CI installs Foundry `nightly`. Pinning it, or re-enabling slither, coverage or `forge fmt --check`,
  is a separate, explicit change.
