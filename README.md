# NaijaProp

A Stacks blockchain smart contract for land NFT management and property verification.

## Overview

NaijaProp enables digital representation of land ownership through NFTs on the Stacks blockchain. Each land parcel is minted as a unique NFT with verifiable metadata including coordinates, size, and document hashes.

## Features

- **Land NFT Minting**: Create unique tokens for land parcels
- **Metadata Storage**: Store coordinates, size, owner details, and document hashes
- **Document Verification**: Verify authenticity through SHA-256 hash comparison
- **Transfer Management**: Secure ownership transfers with validation
- **SIP-009 Compliance**: Standard NFT interface for interoperability

## Contract Functions

### Admin Functions
- `mint-land`: Create new land NFT (admin only)
- `get-admin`: Get current admin address

### Public Functions
- `transfer-land`: Transfer land ownership
- `transfer`: SIP-009 standard transfer function
- `get-land`: Retrieve land metadata
- `get-owner`: Get NFT owner
- `verify-doc`: Verify document hash
- `token-exists`: Check if token exists

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for testing

### Installation

```bash
git clone <repository-url>
cd Naijaprop
clarinet check
```

### Testing

```bash
npm install
npm test
```

## Contract Structure

```
contracts/
├── naijaprop.clar          # Main contract
tests/
├── naijaprop_test.ts       # Test suite
settings/
├── Devnet.toml            # Network configuration
```

## Usage Example

```clarity
;; Mint a new land NFT
(contract-call? .naijaprop mint-land 
  u1 
  "6.5244N,3.3792E" 
  u1000 
  "John Doe" 
  0x1234... 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  "Lagos property")

;; Transfer land
(contract-call? .naijaprop transfer-land u1 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)

;; Verify document
(contract-call? .naijaprop verify-doc u1 0x1234...)
```

## Error Codes

- `u100`: Not admin
- `u101`: Not owner
- `u102`: NFT not found
- `u107`: Already exists

## Development

This is a basic implementation for educational purposes. For production use:

- Implement comprehensive access controls
- Add KYC/AML compliance
- Integrate with official land registries
- Add multi-signature requirements
- Implement proper audit trails

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Security

This contract has not been audited. Use at your own risk. Always audit smart contracts before production deployment.
