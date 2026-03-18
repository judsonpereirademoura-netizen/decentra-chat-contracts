# DecentraChat — Guia de Deploy dos Smart Contracts

## Pré-requisitos

1. **Node.js 18+** instalado
2. **Wallet com MATIC** na rede Polygon Amoy (testnet) ou Polygon Mainnet
3. **Polygonscan API Key** (opcional, para verificação dos contratos)

## Deploy na Polygon Amoy Testnet

### Passo 1: Obter MATIC de Teste

Acesse uma das faucets abaixo e solicite MATIC para sua wallet:

- [Polygon Faucet](https://faucet.polygon.technology/) — Faucet oficial
- [Alchemy Faucet](https://www.alchemy.com/faucets/polygon-amoy) — 0.1 POL/dia
- [Chainstack Faucet](https://chainstack.com/amoy-faucet/) — 1 MATIC/dia

### Passo 2: Configurar Variáveis de Ambiente

```bash
cd decentra-chat-contracts

# Sua private key (NUNCA compartilhe!)
export PRIVATE_KEY="0xSUA_PRIVATE_KEY_AQUI"

# Opcional: para verificação no Polygonscan
export POLYGONSCAN_API_KEY="SUA_API_KEY"
```

### Passo 3: Compilar e Testar

```bash
# Compilar contratos
npx hardhat compile

# Executar testes (29 testes devem passar)
npx hardhat test
```

### Passo 4: Deploy

```bash
# Deploy na testnet Polygon Amoy
npx hardhat run scripts/deploy.js --network polygonAmoy

# Output esperado:
# DChatToken deployed at: 0x...
# DChatStaking deployed at: 0x...
# deployment.json gerado com endereços
```

### Passo 5: Verificar Contratos no Polygonscan

```bash
# Verificar DChatToken
npx hardhat verify --network polygonAmoy <DCHAT_TOKEN_ADDRESS> \
  <FOUNDER_ADDRESS> <TREASURY_ADDRESS> <STAKING_ADDRESS> \
  <PUBLIC_SALE_ADDRESS> <AIRDROP_ADDRESS> <COST_PER_BYTE>

# Verificar DChatStaking
npx hardhat verify --network polygonAmoy <DCHAT_STAKING_ADDRESS> \
  <DCHAT_TOKEN_ADDRESS> <LOCK_PERIOD>
```

### Passo 6: Atualizar Frontend

Após o deploy, copie os endereços do `deployment.json` para o arquivo:
`decentra-chat/client/src/lib/blockchain-service.ts`

Atualize as constantes:
```typescript
const DCHAT_TOKEN_ADDRESS = "0x_ENDERECO_DO_TOKEN";
const DCHAT_STAKING_ADDRESS = "0x_ENDERECO_DO_STAKING";
```

## Deploy na Polygon Mainnet (Produção)

```bash
export PRIVATE_KEY="0xSUA_PRIVATE_KEY"
npx hardhat run scripts/deploy.js --network polygonMainnet
```

**IMPORTANTE:** Antes do deploy em mainnet:
1. Realize auditoria completa dos contratos
2. Teste extensivamente na testnet
3. Revise todas as configurações de tokenomics
4. Consulte assessoria jurídica

## Endereços do Deploy Local (Hardhat)

| Contrato | Endereço |
|---|---|
| DChatToken | `0x5FbDB2315678afecb367f032d93F642f64180aa3` |
| DChatStaking | `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512` |
| Deployer/Founder | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |

## Configurações dos Contratos

| Parâmetro | Valor |
|---|---|
| Supply Total | 1,000,000,000 DCHAT |
| Custo por Byte | 0.000001 DCHAT |
| Lock Period (Staking) | 7 dias |
| Burn Rate | 1% por transação |
| Vesting do Fundador | 2 anos linear |
| Distribuição Nodes | 70% das taxas |
| Distribuição Fundador | 20% das taxas |
| Distribuição Staking | 10% das taxas |
