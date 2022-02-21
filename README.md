# Curve Cross-Chain Gauge Factory

Permissionless deployment of Curve cross-chain gauges.

## Overview

The cross-chain gauge factory requires components to be deployed both on Ethereum and on an alternate EVM compatible network.

Ethereum Components:

- [`RootGaugeFactory`](./contracts/RootGaugeFactory.vy): the main contract for deploying root gauges on Ethereum. It also serves as a registry for finding deployed
  gauges and the bridge wrapper contracts used to bridge CRV emissions to alternate chains.
- [`RootGauge`](./contracts/implementations/RootGauge.vy): the implementation used for root gauges deployed on Ethereum.
- [`Bridger Wrappers`](./contracts/bridgers/): contracts used to transmit CRV emissions across chains. Due to the increasing number of networks Curve deploys to,
  bridge wrappers adhere to a specific interface and allow for a modular bridging system.

Alternate Chain Components:

- [`ChildGaugeFactory`](./contracts/ChildGaugeFactory.vy): the main contract for deploying child gauges on alternate chains. This contract also serves as a registry
  for finding deployed gauges and as a psuedo CRV minter where users can collect CRV they are entitled to from LPing.
- [`ChildGauge`](./contracts/implementations/ChildGauge.vy): the implementation used for child gauges deployed on alternate chains.

The `RootGaugeFactory` and `ChildGaugeFactory`, as well as the `RootGauge` and `ChildGauge` contracts need to be deployed at the same address on every network.
This enables for deterministic mirrored deployment of gauges (via `CREATE2`), a root gauge on Ethereum and a child gauge on the alternate network.

Bridge wrappers are simple contracts which are used by root gauges to transmit emissions to alternate chains where their respective child gauge is.

The gauge system works without any XCMP system, but requires manual interaction for gauges to be deployed and for emissions to be bridged.
With the addition of Multichain's AnyCallProxy, the system operates autonomously and gauges deployed on Ethereum will automatically deploy a child gauge, and
additionally emissions will be automatically bridge when requested on the alternate chain.

### Dependencies

* [python3](https://www.python.org/downloads/release/python-368/) version 3.6 or greater, python3-dev
* [brownie](https://github.com/eth-brownie/brownie) - tested with version [1.15.0](https://github.com/eth-brownie/brownie/releases/tag/v1.17.2)
* [ganache-cli](https://github.com/trufflesuite/ganache-cli) - tested with version [6.12.1](https://github.com/trufflesuite/ganache-cli/releases/tag/v6.12.1)

### Testing

To run the unit tests:

```bash
$ brownie test --ignore=tests/forked/
$ brownie test tests/forked/ --network mainnet-fork
```

### License

(c) Curve.Fi, 2020 - [All rights reserved](LICENSE).
