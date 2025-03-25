# PoolPlay

[![EigenLayer](https://img.shields.io/badge/EigenLayer-Restaking-4A90E2)](https://www.eigenlayer.xyz/)
[![Uniswap Hook](https://img.shields.io/badge/Uniswap-Hook-FF007A?logo=uniswap)](https://docs.uniswap.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Forge-FE5000)](https://book.getfoundry.sh/)
[![Next.js](https://img.shields.io/badge/Next.js-14+-000000?logo=nextdotjs&logoColor=white)](https://nextjs.org/)
[![TailwindCSS](https://img.shields.io/badge/TailwindCSS-3.0-06B6D4?logo=tailwindcss)](https://tailwindcss.com/)
[![shadcn/ui](https://img.shields.io/badge/shadcn/ui-Component%20Library-18181B)](https://ui.shadcn.com/)
[![Reown](https://img.shields.io/badge/Reown-AppKit%20&%20WalletKit-blue)](https://reown.dev/)
[![Wagmi](https://img.shields.io/badge/Wagmi-2%20Hooks-FC5200?logo=ethereum)](https://wagmi.sh/)
[![TanStack Query](https://img.shields.io/badge/TanStack%20Query-React%20Query-FF4154)](https://tanstack.com/query)

PoolPlay is a Uniswap V4 hook that gamifies decentralized finance by integrating lottery pools and prediction markets into liquidity pool interactions. Users can enter lotteries simply by swapping tokens through supported pools, with fees collected contributing to prize pots, while prediction markets allow betting on pool metrics like TVL.

## Table of Contents

- [PoolPlay](#poolplay)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Architecture](#architecture)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
  - [Contract Overview](#contract-overview)
    - [`PoolPlayHook`](#poolplayhook)
    - [`LotteryPool`](#lotterypool)
    - [`PoolPlayRouter`](#poolplayrouter)
    - [`PredictionMarket`](#predictionmarket)
  - [Usage](#usage)
  - [Contributing](#contributing)
  - [License](#license)
  - [Team Members](#team-members)

## Features

**Swap-to-Enter Lottery Pools**  

- Every swap through a PoolPlay-integrated Uniswap V4 pool collects a small fee (e.g., 1% of input amount)
- Swappers are automatically entered into daily lotteries via Chainlink VRF
- 90% of pot goes to winner, 10% operator commission

**Prediction Markets**  

- Bet on future pool metrics (TVL, volume) using ERC20 tokens
- Outcomes settled via PoolManager data/oracles
- 0.5% platform fee on settlements

## Architecture

```mermaid
flowchart LR
    subgraph A[User Interaction]
      U1[User: Swaps Tokens]
      U2[User: Creates Lottery]
      U3[User: Places Prediction Bet]
    end

    subgraph B[Uniswap Ecosystem]
      UNI[Uniswap V4 Pool]
      H[PoolPlayHook]
      R[PoolPlayRouter]
    end

    subgraph C[PoolPlay Contracts]
      L[LotteryPool]
      P[PredictionMarket]
    end

    subgraph D[External Services]
      VRF[Chainlink VRF]
      ORACLE[Off-Chain Oracle]
    end

    U1 -->|Initiates Swap| R
    R -->|Executes Swap| UNI
    UNI -->|Triggers Hook| H
    H -->|Collects Fee, Enters Swapper| L
    U2 -->|Creates Lottery for Pool| L
    L -->|Requests Randomness| VRF
    VRF -->|Selects Winner| L
    U3 -->|Places Bet| P
    P -->|Queries Metrics| UNI
    P -->|Fetches Data| ORACLE
```

## Getting Started

### Prerequisites

- Node.js 18+ & npm 9+
- Foundry (forge 0.2.0+)
- Ethereum wallet (MetaMask recommended)
- Solidity fundamentals

### Installation

Clone repository:

```bash
git clone https://github.com/yourusername/PoolPlay.git
cd PoolPlay
```

Install dependencies:

```bash
npm install
forge install
```

Configure environment:

```bash
cp .env.example .env
# Edit .env with your credentials
```

Compile contracts:

```bash
forge build
```

Deploy to testnet:

```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Contract Overview

### `PoolPlayHook`

- Uniswap V4 hook handling swap interception
- Collects fees and manages lottery entries

### `LotteryPool`

- Permissionless lottery creation/management
- Chainlink VRF integration for winner selection
- 10% operator commission structure

### `PoolPlayRouter`

- Swap router ensuring proper hook interaction
- Maintains swapper address tracking

### `PredictionMarket`

- ERC20-based betting system
- Oracle-powered metric verification
- 0.5% platform fee on settlements

## Usage

**As a Swapper**  

1. Connect wallet to PoolPlay dApp
2. Select supported Uniswap V4 pool
3. Perform swap to automatically enter lottery

**As a Lottery Creator**  

```solidity
// Create lottery for pool with 1% fee
LotteryPool.createLottery(
  poolAddress,
  feeToken,
  1 days,
  100 // 1% fee in basis points
);
```

**As a Bettor**  

1. Deposit ERC20 tokens to PredictionMarket
2. Place bet on desired pool metric
3. Settle bet after validation period

## Contributing

We welcome contributions! Please see our [Contribution Guidelines](CONTRIBUTING.md) for details.

## License

MIT License - See [LICENSE](LICENSE) for full text

## Team Members

- [Signor1](https://github.com/Signor1)
- [JeffreyJoel](https://github.com/JeffreyJoel)
- [BenFaruna](https://github.com/BenFaruna)
- [PhantomOZ](https://github.com/PhantomOZ)
