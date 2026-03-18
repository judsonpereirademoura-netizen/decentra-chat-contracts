# DecentraChat Smart Contracts v5.1

Smart contracts do sistema dual-token da plataforma DecentraChat — mensageiro descentralizado com criptografia E2E e economia tokenizada.

## Arquitetura

```
┌─────────────────────┐     ┌─────────────────────┐
│   DChatStablecoin    │     │     DGovToken        │
│   ($DCHAT - ERC20)   │     │   ($DGOV - ERC20)    │
│                      │     │                      │
│  • Peg 1:1 USD       │     │  • Supply: 100M      │
│  • Colateral USDC/T  │     │  • Founder: 30%      │
│  • Taxa por byte     │     │  • Marketing: 10%    │
│  • 70% nodes         │     │  • Leilões: 60%      │
│  • 20% dividendos    │     │  • Queima automática  │
│  • 10% reserva       │     │  • Vesting 12/24/36m │
└──────────┬──────────┘     └──────────┬──────────┘
           │                           │
           └─────────┬─────────────────┘
                     ▼
           ┌─────────────────────┐
           │    DividendPool     │
           │                     │
           │  • 20% mensagens    │
           │  • 100% leilões     │
           │  • Vesting weight   │
           │  • Auto-compound    │
           └─────────────────────┘
                     │
                     ▼
           ┌─────────────────────┐
           │   DGovGovernance    │
           │                     │
           │  • Quorum 60%+1     │
           │  • Timelock 48h     │
           │  • Delegação        │
           │  • Snapshot anti-FL │
           │  • Inscrição voter  │
           └─────────────────────┘
```

## Contratos

| Contrato | Descrição | Linhas |
|---|---|---|
| `DGovToken.sol` | Token de governança ERC-20 com leilão fracionado, vesting e marketing lock | ~910 |
| `DChatStablecoin.sol` | Stablecoin ERC-20 com colateral, taxas por byte, nodes e relayer | ~620 |
| `DividendPool.sol` | Pool de dividendos com vesting weight automático | ~380 |
| `DGovGovernance.sol` | Governança avançada com timelock, delegação e snapshot | ~430 |

## Stack

- **Solidity** 0.8.24
- **OpenZeppelin** 5.x (ERC20, AccessControl, ReentrancyGuard, Pausable)
- **Hardhat** para compilação, testes e deploy
- **Polygon** (Amoy testnet / Mainnet)

## Instalação

```bash
npm install
npx hardhat compile
npx hardhat test
```

## Deploy

```bash
# Testnet Polygon Amoy
export PRIVATE_KEY="0x..."
export POLYGONSCAN_API_KEY="..."
npx hardhat run scripts/deploy.js --network polygonAmoy

# Mainnet Polygon
npx hardhat run scripts/deploy.js --network polygonMainnet
```

## Testes

```bash
npx hardhat test
# 156 passing
```

## Auditoria

Duas auditorias internas realizadas. Relatórios em:
- `AUDIT_REPORT.md` — Primeira auditoria (23 findings, 23 corrigidos)
- `AUDIT_V2_REPORT.md` — Segunda auditoria (7 findings, 7 corrigidos)

## Licença

Proprietary — Master Rótulos e Etiquetas / Judson Moura
