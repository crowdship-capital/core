# Crowdship

---

[![Tests](https://github.com/carterax/crowdship/actions/workflows/tests.yml/badge.svg)](https://github.com/carterax/crowdship/actions/workflows/tests.yml) [![codecov](https://codecov.io/gh/carterax/crowdship/branch/main/graph/badge.svg?token=9NQURT1YJD)](https://codecov.io/gh/carterax/crowdship)

Crowdship is an open source project built for anyone looking to setup their own crowdfunding initiative, with inspiration from the likes of kickstarter, indiegogo e.t.c Crowdship aims to be familiar while adding on concepts from the blockchain e.g

- Governance Protocol
- Concensus Mechanism

## Features

- Private Campaigns
- Backers vote on fund management
- Censorship resistant
- Reward delivery assurance

---

## Quick Start

To work on the contracts locally there are a few requirements

- [Node.js v12+](https://nodejs.org/en/)
- [Ganache](https://www.npmjs.com/package/ganache-cli)

## Installation

In the terminal, clone https://github.com/carterax/crowdship and install dependencies

```sh
git clone https://github.com/carterax/crowdship.git
cd crowdship
npm i
```

Compile and generate the contracts

```sh
npm run postinstall
```

---

## Deploying to ganache

After `npm run migrate` take note of the contract addresses returned in the terminal

```sh
ganache-cli --deterministic
npm run migrate
```

### Interacting with the contracts on ganache

This opens up truffle console on the default development network, to open on any other work scroll to scripts section.

```sh
npm run truffle-console
factory = await Factory.at("0x00")
deployedCampaignCount = await factory.deployedCampaignCount()
```

---

## Deploying to [Remix](http://remix.ethereum.org/)

Make sure you have [Metamask](https://metamask.io/) installed and setup

- In the select input under workspaces select `connect to localhost`, Follow the instruction given in the modal.
- Open and compile all contracts under `./contracts/*.sol` using `solc v0.8.0`
- Under compiler configuration enable `optimization` with a runs value of `1`, hit the compile button
- Under deploy & run transactions from the select dropdown, choose `Injected web3`
- Deploy `Factory.sol` `CampaignFactory.sol` `CampaignRewards.sol` and `Campaign.sol`, after deploying these contracts please take note of their addresses as they would be required for various implementations across some contracts.
- After deployment you can now interact with the contract methods 🎉

## Running tests

Ensure ganche is running

```sh
npm run test
```

## Scripts

| Script                  | Feature                                                         |
| ----------------------- | --------------------------------------------------------------- |
| `npm run docs`          | Generates documentation for the contracts                       |
| `npm run coverage`      | Generates test coverage                                         |
| `npm run contract-size` | Outputs the contract size so far, run after compiling contracts |

## License

MIT
