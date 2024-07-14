# LZICA: LayerZero Interchain accounts stack

## Overview

LZICA is a stack of smart contracts that allows to create and manage interchain accounts. An interchain account is an account that can be used to interact with a remote blockchain with cross-chain communication being the only way to interact with it.

Interchain accounts are a concept from the Cosmos ecosystem. The primary use-case being no need to hard wire the logic on the remote chain to do specific actions.
On the remote chain, the interchain accounts can perform almost any action that a regular account can do. The only difference is that the interchain account is controlled by a smart contract on the source chain and the actions are triggered by the source chain.

Read more about the Cosmos spec [here](https://github.com/cosmos/ibc/blob/main/spec/app/ics-027-interchain-accounts/README.md)

## Current demo

The current demo is a simple implementation of the interchain accounts stack. It consists of 1 primary contract that uses the Layerzero SDK to perform the cross chain communication.

The primary contract is the `InterchainAccount` contract. It is responsible for creating and managing interchain accounts. The contract is deployed on the source chain and the remote chain. 

On the source chain, the contract is used to create an account on the remote chain.
On the remote chain, the contract handles the actions received from the source chain using the Layerzero communication protocol.

The demo has to following workflow:
1. Deploys the `InterchainAccount` contract on the source chain and the remote chain in the setup and wires them together using the Mock interface from the Layerzero SDK.

2. Create a dummy CW20 token contracts and initializes them with some tokens. Also send some tokens to the interchain account.

3. Trigger a transfer of tokens from the interchain account on chain B to another account on chain B, and do this using interaction with ICARouter on chain A only by the UserA.

4. Verify that the transfer was successful by checking the balance of the receiving account on chain B.



The tests can be found in the `test` folder and can be run using
```bash
foundry test
```


View more detailed logs using
```bash
foundry test -vvv
```


## Credits

The current demo is adapted from the Hyperlane's ICA stack but instead using the Layerzero SDK for the cross chain communication.

## Future work

The current demo is a simple implementation of the interchain accounts stack. The future work includes:
- Implementing the full ICS-027 spec
- Better examples and documentation
- More tests



