# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

Espresso Cash is a full-fledged mobile wallet for iOS and Android on Solana. This is a monorepo managed with Melos containing multiple Dart/Flutter packages.

## Key Packages

- **espressocash_app**: The main mobile wallet application
- **solana**: Solana transaction codec and JSON RPC API implementation
- **espressocash_client**: Client library for Espresso Cash services
- **jupiter_aggregator**: Jupiter DEX aggregator integration
- **solana_mobile_wallet**: Solana Mobile Wallet Adapter implementation
- **solana_mobile_client**: Client-side implementation for mobile wallet scenarios
- **solana_seed_vault**: Solana Seed Vault SDK for Flutter
- **borsh/borsh_annotation**: Borsh serialization packages
- **jsonrpc_client**: RPC API method generator

## Essential Commands

### Setup
```bash
# Install global tools
make activate_utils

# Get dependencies for all packages
melos bootstrap
```

### Build Commands
```bash
# Generate code (run from package directory)
make flutter_build

# Build iOS (requires BUILD_NUMBER and SENTRY_DSN env vars)
make build_ios BUILD_NUMBER=123 SENTRY_DSN=your_dsn

# Build Android (requires BUILD_NUMBER and SENTRY_DSN env vars)
make build_android BUILD_NUMBER=123 SENTRY_DSN=your_dsn

# Generate native splash screen
make splash
```

### Testing
```bash
# Run tests for all packages
melos test

# Run tests for specific package (from package directory)
make flutter_test

# Run integration tests
make flutter_test_e2e

# Run tests with specific Solana RPC (required for some tests)
make flutter_test SOLANA_RPC_URL=https://api.mainnet-beta.solana.com SOLANA_WEBSOCKET_URL=wss://api.mainnet-beta.solana.com
```

### Code Quality
```bash
# Analyze code
make dart_analyze

# Check unused code (from espressocash_app)
make flutter_check_unused_code

# Check dependency cycles
make deps_graph_features
```

### Database Schema
```bash
# Dump current schema (from espressocash_app)
make dump_schema VERSION=63

# Generate test schemas
make flutter_generate_test_schemas
```

## Backend Architecture

The Espresso Cash backend is a separate Go-based service (`ec-backend-go`) that provides gRPC/Connect APIs for the mobile wallet.

### Technology Stack
- **Language**: Go
- **Protocol**: gRPC with Connect framework (HTTP/2)
- **Database**: PostgreSQL
- **Monitoring**: New Relic
- **Container**: Docker (Alpine Linux)
- **Code Generation**: Protocol Buffers (protobuf) with buf

### API Services
The backend exposes these gRPC services:
- **UserService**: Authentication and user management
- **PaymentService**: Direct payments and escrow transactions
- **RateService**: Exchange rates for tokens and fiat
- **ReferralService**: Ambassador/referral program
- **ShortenerService**: URL shortening for payment links
- **MoneygramService**: MoneyGram integration for fiat on/off ramps
- **DlnService**: Cross-chain payment integration
- **TokensService**: Token management
- **SwapService**: Token swapping functionality
- **ManageService**: Administrative functions

### External Integrations
- **Solana**: Main blockchain RPC
- **Jupiter**: DEX aggregator for swaps
- **Helius**: Enhanced Solana RPC
- **Infura**: Ethereum/EVM support
- **Stellar**: Cross-chain payments
- **MoneyGram**: Fiat on/off ramps
- **DLN/Allbridge**: Cross-chain bridges
- **CoinGecko/Frankfurter**: Price data

### Authentication
- JWT-based authentication with wallet signature verification
- Users authenticate by signing messages with their wallet
- Auth interceptor for protected endpoints

### Backend-Client Communication
- **espressocash_client** package contains generated protobuf clients
- gRPC/Connect protocol over HTTP/2
- JWT tokens after wallet signature verification

## Mobile App Architecture

### Dependency Injection
- Uses GetIt and Injectable for dependency injection
- Configuration in `lib/di.dart` and generated `lib/di.config.dart`
- Feature modules provide their own DI configurations

### State Management
- Uses flutter_bloc for state management
- Each feature has its own BLoCs/Cubits

### Database
- Uses Drift (formerly Moor) for local database
- Schema versions tracked in `moor_schemas/`
- Database implementation in `lib/data/db/`

### Feature Structure
Each feature in `lib/features/` typically contains:
- Models (data classes)
- Services (business logic)
- Widgets/Screens (UI)
- BLoCs/Cubits (state management)

### Import Rules (Enforced by DCM)
- Models cannot import from data, services, widgets, screens, ui, or l10n
- Data cannot import from services, widgets, screens, or ui
- Services cannot import from widgets, screens, ui, or l10n
- UI cannot import from features
- Utils cannot import from features or ui

## Code Style
- Uses mews_pedantic linting rules
- Page width: 100 characters
- Prefer relative imports within packages
- DCM (Dart Code Metrics) for additional static analysis

## Environment Variables
- `SOLANA_RPC_URL`: Solana RPC endpoint
- `SOLANA_WEBSOCKET_URL`: Solana WebSocket endpoint
- `SENTRY_DSN`: Sentry error reporting DSN
- `MIXPANEL_TOKEN`: Mixpanel analytics token
- `PROD`: Set to true for production builds

## Testing Guidelines
- Unit tests use tags: `golden` for golden tests, `solana` for Solana-specific tests
- Integration tests in `integration_test/` directory
- Golden tests for UI components in `test/golden/`
- Test setup script at `tool/tests_setup.dart`

## Development Tips
- Always run `make flutter_build` after modifying models with code generation annotations
- Use Melos for running commands across all packages
- Check for dependency cycles before adding new dependencies between features
- Follow the established import rules to maintain clean architecture