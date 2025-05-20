# ShieldChain: Social Recovery Wallet

ShieldChain is a smart contract written in Clarity for the Stacks blockchain that implements a social recovery wallet system. This solution helps users secure their assets while providing a trusted recovery mechanism if access is lost.

## Overview

ShieldChain allows users to:
- Designate trusted "protectors" who can help recover wallet access
- Manage multiple token assets from a single secure wallet
- Initiate and complete account recovery using a consensus-based approach
- Configure consensus threshold requirements for recovery actions

## Features

### Social Recovery System
- **Protector Network**: Register trusted contacts who can help recover wallet access
- **Consensus-Based Recovery**: Requires a majority of protectors to approve recovery actions
- **Configurable Threshold**: Set the percentage of protectors needed for successful recovery
- **Time-Limited Recovery**: Recovery actions expire after a set time window (default: 7 days)

### Asset Management
- **Token Whitelist**: Manage which tokens can be transferred from the wallet
- **STX Support**: Native support for STX token transfers
- **Flexible Token Interface**: Support for any token implementing the token-interface

### Security Features
- **Controller Authentication**: Only the wallet controller can perform sensitive operations
- **Recovery Timeouts**: Rescue operations expire after a configurable window
- **Validation Guards**: Extensive input validation to prevent exploitation
- **Access Controls**: Clear permissions for controller vs. protector operations

## Contract Structure

### Core Components

#### Data Variables
- `account-controller`: The owner/controller of the wallet
- `protector-registry`: Map of registered protector addresses
- `allowed-tokens`: Map of whitelisted token contracts
- `rescue-mode`: State tracking for active recovery operations

#### Key Functions

**Setup and Configuration**
- `setup`: Initialize the wallet with controller and consensus ratio
- `register-protector`: Add a trusted protector to the recovery network
- `unregister-protector`: Remove a protector from the network
- `update-consensus-ratio`: Change the required consensus percentage

**Recovery Process**
- `start-rescue`: Initiate a recovery process by a protector
- `endorse-rescue`: Additional protectors support a recovery attempt
- `complete-rescue`: Finalize recovery when threshold is reached
- `abort-rescue`: Cancel an in-progress recovery (controller only)

**Asset Management**
- `register-token`: Whitelist a token contract for use
- `unregister-token`: Remove a token from the whitelist
- `send-token`: Transfer tokens to a recipient
- `send-stx`: Transfer STX to a recipient

## Usage Guide

### Initial Setup

```clarity
;; Initialize the wallet with yourself as controller and 51% consensus requirement
(contract-call? .shield-chain setup tx-sender u51)
```

### Adding Protectors

```clarity
;; Add trusted contacts as protectors
(contract-call? .shield-chain register-protector 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(contract-call? .shield-chain register-protector 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

### Managing Tokens

```clarity
;; Register a fungible token for use with the wallet
(contract-call? .shield-chain register-token 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token)

;; Send tokens to another address
(contract-call? .shield-chain send-token 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token 
                'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 u1000)
```

### Recovery Process

When a user loses access, the recovery process works as follows:

1. A protector initiates rescue:
```clarity
(contract-call? .shield-chain start-rescue 'ST1NEW5F7MHCXT5CC2KYZK9Y8VCCVP5VH9K38YQD7)
```

2. Other protectors endorse the rescue:
```clarity
(contract-call? .shield-chain endorse-rescue)
```

3. Once enough endorsements are collected, anyone can complete the rescue:
```clarity
(contract-call? .shield-chain complete-rescue)
```

## Security Considerations

- **Controller Selection**: Choose a secure controller address you have reliable access to
- **Protector Network**: Select trustworthy protectors who won't collude against you
- **Consensus Ratio**: Balance between recovery ease and security (higher is more secure)
- **Token Management**: Only whitelist verified token contracts

## Error Codes

| Code | Description |
|------|-------------|
| u100 | ACCESS_DENIED - Caller doesn't have permission |
| u101 | SETUP_ALREADY_COMPLETE - Wallet already initialized |
| u102 | SETUP_INCOMPLETE - Wallet not yet initialized |
| u103 | PROTECTOR_DUPLICATE - Protector already registered |
| u104 | PROTECTOR_NOT_FOUND - Protector not in registry |
| u105 | RESCUE_ALREADY_ACTIVE - A rescue operation is in progress |
| u106 | NO_RESCUE_ACTIVE - No rescue operation is in progress |
| u107 | DUPLICATE_ENDORSEMENT - Protector already endorsed rescue |
| u108 | ENDORSEMENT_THRESHOLD_UNMET - Not enough endorsements |
| u109 | RESCUE_TIMEOUT - Rescue window has expired |
| u110 | BALANCE_TOO_LOW - Insufficient balance for transfer |
| u111 | INVALID_RATIO - Consensus ratio out of valid range |
| u112 | INVALID_CONTROLLER - Invalid controller address |
| u113 | INVALID_TOKEN - Invalid token contract |

## Development

ShieldChain is developed for the Stacks blockchain using the Clarity smart contract language.

### Requirements
- Clarity language support
- Stacks blockchain node or development environment
- Clarity analyzer for testing and verification
