# Morigami Monorepo

Current repo contains forked smart contracts of the [Origami Protocol](https://docs.origami.finance/) With new versions of Flash and Borrow manager that supposed to be used only by More Vaults. It support multi asset flashloans and set lp token(must be ERC20) as the reserve asset.

## Getting Started

### Contracts

tl;dr:

```bash
cd apps/protocol
git submodule update --init --recursive

# Install foundry if not already installed.
# curl -L https://foundry.paradigm.xyz | bash
# Update foundry version to latest
foundryup

# npm packages used for ext. deps
nvm use
yarn

forge test
```

See [./apps/protocol/README.md](./apps/protocol/README.md)

### Dapp

To start a local development instance:

```bash
cd apps/dapp
yarn
yarn dev
```

### Automation

This uses the [Overlord](https://www.npmjs.com/package/@mountainpath9/overlord) framework to run daily automations for compounding

To build:

```bash
cd apps/automation
yarn
yarn build
```

## Contributing

We welcome all contributors to this project - please see the [contribution guide](./CONTRIBUTING.md) for more information on how to get involved and what to expect.
