# DecentraChat contracts

Solidity contracts for DecentraChat on Polygon: DChatStablecoin ($DCHAT, USDC/USDT-backed), DGovToken ($DGOV, auctions and vesting), DividendPool and DGovGovernance. All four are UUPS upgradeable proxies (v6).

## Layout
- `contracts/`: the four v6 contracts (OpenZeppelin upgradeable 5.0.2). `DChatToken.sol` and `DChatStaking.sol` are legacy and not deployed in v6.
- `scripts/deploy-proxy.js`: v6 deploy (UUPS). `scripts/deploy*.js` without "proxy" are the old v5 scripts.
- `scripts/transfer-admin-to-safe.js` / `accept-admin-transfer.js` / `verify-admin-status.js`: move admin roles to a Gnosis Safe.
- `deployment.json`: current mainnet record (v6 proxies + implementations; v5.2 kept under `previousDeploy` as deprecated). The same addresses live in `decentra-chat` (`MAINNET_CONFIG`) and `decentrachat-node-runner` (`CONTRACTS`); keep all three in sync.
- `AUDIT_V3_REPORT.md`: latest audit and the fixes applied.

## Commands
- `npm install`, then `npx hardhat compile` and `npx hardhat test`.
- Compiling downloads solc 0.8.24; it fails behind a proxy that blocks binaries.soliditylang.org.
- `@openzeppelin/contracts-upgradeable` must stay on 5.0.x: later 5.x removed `ReentrancyGuardUpgradeable`, which these contracts import.

## Rules
- Never commit private keys, mnemonics or `.env`.
- Deploying, upgrading a proxy (`upgrades.upgradeProxy`) or transferring admin roles is done by the owner with their wallet or the Safe, never by an agent.
- Upgrades must keep storage layout: only append state variables, never reorder or remove them.
