# DecentraChat Smart Contracts — Guia de Deploy v5.2

## Visão Geral

O sistema DecentraChat consiste em 4 smart contracts principais + 2 mocks para testnet:

| Contrato | Função | Gas Estimado |
|----------|--------|-------------|
| **DChatStablecoin** | Stablecoin 1:1 USD, billing engine, micro-transações | ~3.5M gas |
| **DGovToken** | Governança, leilão fracionado, vesting, burn | ~4.7M gas |
| **DividendPool** | Pool de dividendos automático | ~1.7M gas |
| **DGovGovernance** | Governança avançada on-chain | ~3.4M gas |
| MockUSDC | Mock USDC para testnet | ~572K gas |
| MockUSDT | Mock USDT para testnet | ~572K gas |

**Gas total estimado:** ~14.5M gas (~0.02 POL na Amoy, ~0.5 POL na mainnet)

---

## Pré-requisitos

1. **Node.js** v18+ instalado
2. **Wallet** com POL (testnet ou mainnet)
3. **Polygonscan API Key** (opcional, para verificação de contratos)

### Obter POL de Teste (Amoy Testnet)

- Faucet Polygon: https://faucet.polygon.technology/
- Faucet Chainlink: https://faucets.chain.link/polygon-amoy
- Faucet Alchemy: https://www.alchemy.com/faucets/polygon-amoy

Recomendado: mínimo **0.5 POL** para deploy completo + configurações.

---

## Instalação

```bash
cd decentra-chat-contracts
npm install
npx hardhat compile
```

---

## Deploy

### Testnet (Polygon Amoy)

```bash
# Deploy completo
PRIVATE_KEY="sua_private_key_aqui" npx hardhat run scripts/deploy-staged.js --network polygonAmoy

# Se falhar no meio, retomar a partir de uma etapa:
PRIVATE_KEY="sua_private_key_aqui" RESUME_FROM=3 npx hardhat run scripts/deploy-staged.js --network polygonAmoy
```

### Mainnet (Polygon)

```bash
# Deploy em produção (usa USDC/USDT oficiais da Polygon)
PRIVATE_KEY="sua_private_key_aqui" npx hardhat run scripts/deploy-staged.js --network polygonMainnet
```

### Verificação no Polygonscan

```bash
# Adicionar API key para verificação automática
PRIVATE_KEY="sua_private_key_aqui" POLYGONSCAN_API_KEY="sua_api_key" npx hardhat run scripts/deploy-staged.js --network polygonAmoy
```

---

## Etapas do Deploy (Staged)

O script `deploy-staged.js` executa 6 etapas com checkpoint entre cada uma:

| Stage | Contrato | Dependências |
|-------|----------|-------------|
| 1 | Mock USDC/USDT (testnet) ou endereços oficiais (mainnet) | Nenhuma |
| 2 | DChatStablecoin | USDC, USDT |
| 3 | DividendPool | DChatStablecoin |
| 4 | DGovToken | DChatStablecoin, DividendPool |
| 5 | DGovGovernance | DGovToken |
| 6 | Configurações pós-deploy (roles, targets, pools) | Todos |

Se o deploy falhar em qualquer etapa, use `RESUME_FROM=<stage>` para retomar.

---

## Arquivos Gerados

Após o deploy, os seguintes arquivos são gerados:

| Arquivo | Conteúdo |
|---------|----------|
| `deployment.json` | Endereços de todos os contratos, configurações, metadata |
| `abis/DChatStablecoin.json` | ABI do contrato DCHAT |
| `abis/DGovToken.json` | ABI do contrato DGOV |
| `abis/DividendPool.json` | ABI do DividendPool |
| `abis/DGovGovernance.json` | ABI da Governança |

---

## Endereços Oficiais de Colateral

| Token | Polygon Mainnet | Polygon Amoy |
|-------|----------------|-------------|
| USDC | `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359` | Mock (deployado) |
| USDT | `0xc2132D05D31c914a87C6611C10748AEb04B58e8F` | Mock (deployado) |

---

## Configurações Pós-Deploy

O Stage 6 executa automaticamente:

1. **setDividendPool** no DChatStablecoin → conecta ao DividendPool
2. **DEPOSITOR_ROLE** → DChatStablecoin e DGovToken podem depositar no DividendPool
3. **setDividendPool** no DGovToken → conecta ao DividendPool
4. **Allowed Targets** na Governança → DGovToken, DChatStablecoin, DividendPool

---

## Parâmetros do Sistema

| Parâmetro | Valor |
|-----------|-------|
| DGOV Total Supply | 100.000.000 (100M) |
| Founder Vesting | 30% (30M) — 10M/12mo, 10M/24mo, 10M/36mo |
| Marketing Allocation | 10% (10M) — 180d lock + 180d linear |
| Auction Allocation | 60% (60M) — 6 fases, 36 meses |
| Dividend Split | 70% nós / 20% dividendPool / 10% reserve |
| Messaging Fee | Dinâmico por byte |
| Activation Fee | $0.10 em DCHAT |
| Quorum | 60% + 1 do total emitido |
| Timelock | 48 horas |
| Voter Inactivity | 90 dias |
| Max Delegators | 50 |
| Execution Deadline | 7 dias |

---

## Testes

```bash
# Rodar todos os 156 testes
npx hardhat test

# Rodar com coverage
npx hardhat coverage

# Rodar teste específico
npx hardhat test test/DualToken.test.js
```

---

## Integração com Frontend

Após o deploy, copie `deployment.json` e a pasta `abis/` para o projeto frontend:

```bash
cp deployment.json ../decentra-chat/shared/
cp -r abis/ ../decentra-chat/shared/abis/
```

No frontend, use ethers.js para interagir:

```typescript
import { ethers } from 'ethers';
import deployment from '@shared/deployment.json';
import DChatABI from '@shared/abis/DChatStablecoin.json';

const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const dchat = new ethers.Contract(deployment.contracts.DChatStablecoin.address, DChatABI, signer);

// Mint DCHAT com USDC
await dchat.mint(amount, 0); // 0 = USDC, 1 = USDT
```

---

## Segurança

- **Nunca commite** a private key no repositório
- Use variáveis de ambiente ou `.env` (com `.gitignore`)
- Os contratos foram auditados: 23/23 findings corrigidos (audit 1) + 7/7 findings corrigidos (audit 2)
- 156/156 testes passando
