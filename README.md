# 📊 Data NFT Exchange

A decentralized marketplace for trading data as NFTs with automatic royalty distribution and licensing enforcement.

## 🎯 Overview

The Data NFT Exchange empowers individuals to monetize their data while enabling researchers and businesses to access verified, privacy-preserving datasets. Users mint anonymized datasets as NFTs with customizable licensing terms, buyers license usage under enforceable smart contracts, and automatic royalties flow back to data owners.

## ✨ Features

- 🏷️ **Dataset Minting**: Convert datasets into NFTs with metadata and licensing terms
- 💰 **Automated Licensing**: Smart contract-enforced data usage licenses
- 🔄 **Royalty Distribution**: Automatic payments to data creators
- ⏰ **Time-based Licenses**: Configurable license durations
- 🛡️ **Access Control**: Verify data access rights for users
- 💸 **Platform Fees**: Configurable platform revenue model

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet)
- [Stacks CLI](https://docs.hiro.so/stacks/stacks-cli)

### Installation

```bash
git clone <repository-url>
cd Data-NFT-Exchange--
clarinet check
```

### Testing

```bash
npm install
npm test
```

## 📖 Contract Functions

### 🏭 Public Functions

#### `mint-dataset`
Creates a new data NFT with licensing parameters.

```clarity
(mint-dataset "Dataset Name" "Description" "hash123" u1000000 u100 u144)
```

Parameters:
- `name`: Dataset name (max 50 chars)
- `description`: Dataset description (max 200 chars)
- `dataset-hash`: Unique dataset hash (64 chars)
- `price`: License price in microSTX
- `royalty-rate`: Royalty percentage (basis points, max 1000 = 10%)
- `license-duration`: License duration in blocks

#### `license-dataset`
Purchase a license to use a dataset.

```clarity
(license-dataset u1)
```

#### `update-dataset-price`
Update the licensing price (owner only).

```clarity
(update-dataset-price u1 u2000000)
```

#### `transfer`
Transfer NFT ownership.

```clarity
(transfer u1 'SP123... 'SP456...)
```

#### `withdraw-royalties`
Withdraw accumulated royalties.

```clarity
(withdraw-royalties)
```

#### `set-platform-fee`
Update platform fee rate (contract owner only).

```clarity
(set-platform-fee u300)
```

### 🔍 Read-Only Functions

#### `get-dataset-metadata`
Retrieve dataset information.

```clarity
(get-dataset-metadata u1)
```


```clarity
(get-license-info u1 'SP123...)
```

#### `is-license-valid`
Verify if a license is still active.

```clarity
(is-license-valid u1 'SP123...)
```

#### `calculate-licensing-costs`
Calculate cost breakdown for licensing.

```clarity
(calculate-licensing-costs u1)
```

#### `verify-dataset-access`
Check if user has access rights (owner or valid license).

```clarity
(verify-dataset-access u1 'SP123...)
```

## 💡 Usage Examples

### Minting a Dataset

```bash
clarinet console
(contract-call? .Data-NFT-Exchange-- mint-dataset 
  "COVID-19 Anonymized Survey Data" 
  "Anonymous survey responses about COVID-19 impact on mental health"
  "a1b2c3d4e5f6789..."
  u5000000  ; 5 STX
  u250      ; 2.5% royalty
  u1008)    ; ~1 week license
```

### Licensing a Dataset

```bash
(contract-call? .Data-NFT-Exchange-- license-dataset u1)
```

### Checking License Status

```bash
(contract-call? .Data-NFT-Exchange-- is-license-valid u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🏗️ Architecture

### Error Codes

| Code | Description |
|------|-------------|
| `u100` | Owner only operation |
| `u101` | Not authorized |
| `u102` | Token not found |
| `u103` | Already licensed |
| `u104` | Invalid price |
| `u105` | Invalid royalty rate |
| `u106` | Insufficient funds |
| `u107` | License expired |

### Fee Structure

- **Platform Fee**: 2.5% (default, configurable)
- **Royalty Fee**: Set by data creator (max 10%)
- **Creator Fee**: Remaining amount after platform and royalty fees

## 🔐 Security Features

- Input validation for all parameters
- Owner-only administrative functions
- Time-based license expiration
- Automatic fee distribution
- Balance verification before transfers

## 🛠️ Development

### Contract Structure

```
Data-NFT-Exchange--/
├── contracts/
│   └── Data-NFT-Exchange--.clar
├── tests/
├── settings/
├── Clarinet.toml
└── README.md
```

### Testing

Run comprehensive tests:

```bash
clarinet test
```

### Deployment

Deploy to testnet:

```bash
clarinet deploy --testnet
```

## 📈 Roadmap

- [ ] IPFS integration for dataset storage
- [ ] Advanced metadata schemas
- [ ] Bulk licensing operations
- [ ] Dataset categories and tags
- [ ] Reputation system for data providers
- [ ] Integration with external data marketplaces

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

For questions and support, please open an issue in the GitHub repository.

---

Built with ❤️ for the decentralized data economy
