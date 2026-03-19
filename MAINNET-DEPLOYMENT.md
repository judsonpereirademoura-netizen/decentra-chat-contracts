# DecentraChat — Mainnet Polygon Deployment Record

**DOCUMENTO PERMANENTE — NÃO DELETAR**

---

## Data do Deploy

- **Data:** 19 de Março de 2026, 20:06 UTC
- **Rede:** Polygon Mainnet (chainId: 137)
- **RPC:** https://polygon-bor-rpc.publicnode.com
- **Explorer:** https://polygonscan.com

---

## Wallet do Deployer / Fundador

| Campo | Valor |
|-------|-------|
| **Endereço** | `0x5a37daD4eE116380BF4008A94E5b433ae32406F6` |
| **Papel** | Deployer, Founder, Admin, Reserve Wallet |

---

## Endereços dos Contratos (MAINNET POLYGON)

| Contrato | Endereço | Polygonscan |
|----------|----------|-------------|
| **DChatStablecoin ($DCHAT)** | `0xECC263f838B99f21432898200fb2d34D103253Eb` | [Ver no Polygonscan](https://polygonscan.com/address/0xECC263f838B99f21432898200fb2d34D103253Eb) |
| **DGovToken ($DGOV)** | `0x99Af6047482554dfC150De94582fBAA52a00596A` | [Ver no Polygonscan](https://polygonscan.com/address/0x99Af6047482554dfC150De94582fBAA52a00596A) |
| **DividendPool** | `0xC9aCAf89231ADdEF53087F7670E4b22Ff1FB573B` | [Ver no Polygonscan](https://polygonscan.com/address/0xC9aCAf89231ADdEF53087F7670E4b22Ff1FB573B) |
| **DGovGovernance** | `0x1A38ee6C8Cf505d6404aF6CF7843513B4B99d9E1` | [Ver no Polygonscan](https://polygonscan.com/address/0x1A38ee6C8Cf505d6404aF6CF7843513B4B99d9E1) |

---

## Colateral Oficial (Tokens de Referência na Polygon)

| Token | Endereço | Polygonscan |
|-------|----------|-------------|
| **USDC** | `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359` | [Ver no Polygonscan](https://polygonscan.com/address/0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359) |
| **USDT** | `0xc2132D05D31c914a87C6611C10748AEb04B58e8F` | [Ver no Polygonscan](https://polygonscan.com/address/0xc2132D05D31c914a87C6611C10748AEb04B58e8F) |

---

## Configurações do Sistema

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

## Roles e Permissões Configuradas

| Ação | Status |
|------|--------|
| DChatStablecoin.dividendPool → DividendPool | Configurado |
| DEPOSITOR_ROLE → DChatStablecoin no DividendPool | Concedido |
| DEPOSITOR_ROLE → DGovToken no DividendPool | Concedido |
| DGovToken.dividendPool → DividendPool | Configurado |
| Allowed Targets na Governança → DGovToken, DChatStablecoin, DividendPool | Configurado |
| Founder Node auto-registrado no DChatStablecoin | Automático (constructor) |

---

## Verificação e Auditoria

| Item | Status |
|------|--------|
| Testes unitários | 156/156 passando |
| Auditoria 1 | 23/23 findings corrigidos |
| Auditoria 2 | 7/7 findings corrigidos |
| Deploy local Hardhat | Validado |
| Deploy mainnet Polygon | Concluído |

---

## Gas Consumido no Deploy

| Stage | Contrato | Gas Estimado | Custo Estimado |
|-------|----------|-------------|----------------|
| 2 | DChatStablecoin | 3.508.218 | ~0.44 POL |
| 3 | DividendPool | 1.749.210 | ~0.22 POL |
| 4 | DGovToken | 4.713.417 | ~0.59 POL |
| 5 | DGovGovernance | 3.455.224 | ~0.43 POL |
| 6 | Configurações | ~500.000 | ~0.06 POL |
| **Total** | | **~13.926.069** | **~1.74 POL** |

---

## Repositório de Código

- **GitHub:** https://github.com/judsonpereirademoura-netizen/decentra-chat-contracts
- **Solidity Version:** 0.8.24
- **OpenZeppelin:** v5
- **Hardhat:** v2.x

---

## ABIs

Os ABIs de todos os contratos estão disponíveis em:
- `./abis/DChatStablecoin.json`
- `./abis/DGovToken.json`
- `./abis/DividendPool.json`
- `./abis/DGovGovernance.json`

---

## IMPORTANTE

> **Estes contratos são imutáveis na blockchain.** Os endereços acima são permanentes e não podem ser alterados.
> Qualquer atualização de lógica requer deploy de novos contratos e migração de estado.
> Mantenha este documento e o `deployment.json` em local seguro.
