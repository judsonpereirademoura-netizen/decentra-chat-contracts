# Auditoria Completa — DecentraChat Smart Contracts v3.0

**Data:** 2026-03-23
**Auditor:** Claude (Anthropic)
**Escopo:** Todos os 6 contratos Solidity do repositório `decentra-chat-contracts`
**Solidity:** ^0.8.24 | **Framework:** Hardhat | **Rede:** Polygon Mainnet

---

## Sumário Executivo

O ecossistema DecentraChat é composto por 6 contratos que implementam: stablecoin com vault colateralizado (DChatStablecoin), token de governança com leilão fracionado (DGovToken), pool de dividendos (DividendPool), governança on-chain (DGovGovernance), token de utilidade legado (DChatToken) e staking (DChatStaking). Os contratos já passaram por 2 auditorias anteriores com 23+ findings corrigidos. Esta auditoria v3 identifica **21 novos findings** remanescentes.

---

## Contratos Auditados

| # | Contrato | Linhas | Descrição |
|---|----------|--------|-----------|
| 1 | `DChatStablecoin.sol` | 665 | Stablecoin $DCHAT 1:1 USD, vault USDC/USDT, messaging, nodes |
| 2 | `DGovToken.sol` | 956 | Governança $DGOV, leilão fracionado, vesting, marketing lock |
| 3 | `DividendPool.sol` | 405 | Pool de dividendos para holders de $DGOV |
| 4 | `DGovGovernance.sol` | 508 | Governança avançada com quorum, timelock, delegação |
| 5 | `DChatToken.sol` | 627 | Token ERC-20 legado com billing por byte |
| 6 | `DChatStaking.sol` | 336 | Staking pool com reward-per-token |

---

## Findings

### CRÍTICO (C) — Risco de perda de fundos

#### C-01: Redeem sem `whenNotPaused` — DChatStablecoin.sol:273-303

**Contrato:** `DChatStablecoin`
**Função:** `redeem()`
**Severidade:** Crítico

A função `redeem()` não possui o modificador `whenNotPaused`. Se o admin pausar o contrato por uma emergência (hack, bug, exploit), o redeem continua operando, permitindo que um atacante drene o vault de colateral mesmo com o contrato pausado.

```solidity
// ATUAL — sem whenNotPaused
function redeem(
    address collateralToken,
    uint256 dchatAmount
) external nonReentrant { // ← FALTA whenNotPaused
```

**Recomendação:** Adicionar `whenNotPaused` ao `redeem()`.

---

#### C-02: Decimal Mismatch no Vault — Assume todos colaterais com 6 decimais — DChatStablecoin.sol:226,282

**Contrato:** `DChatStablecoin`
**Severidade:** Crítico

O `mint()` e `redeem()` assumem que **todo** colateral possui 6 decimais (`* 1e12` / `/ 1e12`). Se um token com decimais diferentes (ex: DAI com 18 decimais) for adicionado via `addCollateralToken()`, o mint/redeem produzirá valores incorretos, potencialmente mintando 1e12x mais tokens ou devolvendo 1e12x menos colateral.

```solidity
uint256 dchatAmount = collateralAmount * 1e12; // Assume 6 decimals
uint256 collateralAmount = dchatAmount / 1e12;  // Assume 6 decimals
```

**Recomendação:** Armazenar os decimais de cada colateral aceito e usar a conversão dinâmica:
```solidity
mapping(address => uint8) public collateralDecimals;
uint256 dchatAmount = collateralAmount * 10**(18 - collateralDecimals[collateralToken]);
```

---

#### C-03: Sorting O(n²) com MAX_BIDS = 100 pode causar DoS por gas — DGovToken.sol:687-703

**Contrato:** `DGovToken`
**Função:** `_sortBidsByPrice()` / `finalizeAuction()`
**Severidade:** Crítico

O insertion sort em `_sortBidsByPrice()` tem complexidade O(n²). Com `MAX_BIDS_PER_AUCTION = 100`, o worst case é 100² = 10.000 iterações de comparação + swap, cada uma envolvendo leitura de storage (`bids[sortedIndices[j-1]].pricePerUnit`). Isso pode exceder o gas limit do bloco em Polygon (30M gas), causando DoS na finalização do leilão — **travando os fundos em escrow de todos os participantes**.

**Recomendação:**
- Reduzir `MAX_BIDS_PER_AUCTION` para 50, ou
- Usar um heap/priority queue off-chain com verificação on-chain, ou
- Manter bids ordenados no `placeBid()` via binary search insertion.

---

### ALTO (H) — Risco significativo

#### H-01: `processMessage` permite que RELAYER gaste tokens do usuário sem ERC-20 approval — DChatStablecoin.sol:336-400

**Contrato:** `DChatStablecoin`
**Função:** `processMessage()`
**Severidade:** Alto

O relayer chama `processMessage(sender, ...)` e o contrato executa `_transfer(sender, ...)` diretamente, movendo tokens do `sender` sem que o sender tenha feito um `approve()` ERC-20 padrão. O controle de acesso depende exclusivamente do `relayerDailyLimit` customizado. Isso cria um vetor de ataque: se o RELAYER_ROLE for comprometido, ele pode drenar tokens de **qualquer usuário que tenha chamado `approveRelayerAllowance()`**, até o limite diário, sem nenhuma interação do usuário.

**Recomendação:** Considerar implementar meta-transactions com assinatura EIP-712 do usuário por mensagem, ou exigir `approve()` ERC-20 padrão + `transferFrom()` ao invés de `_transfer()` direto.

---

#### H-02: Falta validação de `recipient` em `processMessage` — DChatStablecoin.sol:336-400

**Contrato:** `DChatStablecoin`
**Severidade:** Alto

O parâmetro `recipient` não é validado contra `address(0)`. Embora não afete a lógica de transfer (o recipient não recebe tokens), o evento `MessageProcessed` é emitido com um `recipient` inválido, podendo corromper dados off-chain e logs.

Além disso, não há validação de que `sender != recipient` (auto-mensagem).

---

#### H-03: `_fillBids` pode underflow em `bidderBal.total -= fillCost` — DGovToken.sol:730

**Contrato:** `DGovToken`
**Função:** `_fillBids()`
**Severidade:** Alto

No preenchimento parcial de um bid, o `fillCost` é recalculado como `(fillQty * bid.pricePerUnit) / 1e18`. Devido ao arredondamento de divisão inteira, é possível que `fillCost` difira ligeiramente do `bid.totalCost` original. A linha `bidderBal.total -= fillCost` pode, em cenários de edge case, causar um underflow (revert no Solidity 0.8+), travando a finalização do leilão.

**Recomendação:** Usar `min(fillCost, bidderBal.total)` ou recalcular consistentemente.

---

#### H-04: Tokens de node reward ficam no contrato sem mecanismo de withdraw — DChatStablecoin.sol:370-377

**Contrato:** `DChatStablecoin`
**Função:** `processMessage()` → distribuição para nodes
**Severidade:** Alto

Quando `processMessage()` distribui `nodeFee`, os tokens ficam no contrato (`address(this)`) e o `nodeRewardPerToken` é incrementado. Porém, os tokens não são segregados — eles compartilham o balanço do contrato com vault, escrow fees, etc. Se a contabilidade interna divergir do saldo real (por qualquer motivo), `claimNodeRewards()` pode falhar por falta de saldo.

---

### MÉDIO (M) — Risco moderado

#### M-01: `cancelProposal` marca `executed = true` — semântica incorreta — DGovGovernance.sol:389-399

**Contrato:** `DGovGovernance`
**Função:** `cancelProposal()`
**Severidade:** Médio

Propostas canceladas são marcadas como `executed = true` para prevenir ações futuras. Isso polui as métricas e confunde frontend/indexers, pois não há como distinguir propostas executadas de canceladas on-chain (exceto pelo evento `ProposalCancelled`).

**Recomendação:** Adicionar campo `cancelled` ao `ProposalCore` ou um enum de status.

---

#### M-02: `totalVaultBalance` tracking pode divergir se colateral for fee-on-transfer — DChatStablecoin.sol:237-238

**Contrato:** `DChatStablecoin`
**Severidade:** Médio

O `mint()` assume que o `transferFrom` transfere exatamente `collateralAmount`. Se um token fee-on-transfer (como USDT em algumas chains) for usado como colateral, o vault receberá menos tokens do que o registrado, criando um déficit de colateral. O `vaultBalance` e `totalVaultBalance` ficam inflados.

**Recomendação:** Verificar saldo antes/depois do `transferFrom`:
```solidity
uint256 balanceBefore = IERC20(collateralToken).balanceOf(address(this));
IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
uint256 received = IERC20(collateralToken).balanceOf(address(this)) - balanceBefore;
```

---

#### M-03: Sem limite superior para `dataTypeMultiplier` — DChatToken.sol:532-537

**Contrato:** `DChatToken`
**Função:** `setDataTypeMultiplier()`
**Severidade:** Médio

O owner pode definir um multiplicador arbitrariamente alto (ex: `type(uint256).max`), tornando o custo por mensagem astronomicamente alto e efetivamente congelando o protocolo de mensagens. O `DChatStablecoin` tem proteção (`5000-50000`), mas o `DChatToken` não.

**Recomendação:** Adicionar bounds check: `require(_multiplier >= 5000 && _multiplier <= 50000)`.

---

#### M-04: `setLockPeriod` sem limite máximo — DChatStaking.sol:306-309

**Contrato:** `DChatStaking`
**Severidade:** Médio

O owner pode definir `lockPeriod` para um valor extremamente alto (ex: `type(uint256).max`), efetivamente travando todos os tokens em stake permanentemente. Não há limite máximo.

**Recomendação:** Adicionar `require(_newLockPeriod <= 365 days, "Lock period too long")`.

---

#### M-05: Dividend weight dupla contagem potencial — DividendPool.sol:272-280,285-303

**Contrato:** `DividendPool`
**Função:** `getHolderWeight()` / `_getTotalDividendWeight()`
**Severidade:** Médio

O sistema usa `max(autoWeight, manualWeight)` para retrocompatibilidade. Se o admin setar manualmente um `vestingWeight` alto E o sistema automático também retornar um peso, o `max()` previne dupla contagem. Porém, o `_getTotalDividendWeight()` calcula `autoTotal` (founder + marketing) e compara com `totalVestingWeight` (soma de todos os manuais). Se houver holders com peso manual > 0 além de founder/marketing, esses pesos podem ser ignorados, resultando em distribuição incorreta de dividendos.

**Recomendação:** Remover completamente o sistema manual `vestingWeight` após migração para automático, ou iterar sobre todos os holders com peso manual.

---

#### M-06: Falta `SafeERC20` no DChatStablecoin e DGovToken — DChatStablecoin.sol:229,299 / DGovToken.sol:462,483

**Contrato:** `DChatStablecoin`, `DGovToken`
**Severidade:** Médio

Ambos contratos usam `IERC20.transfer()` e `IERC20.transferFrom()` diretamente com `require(success)`. O USDT em mainnet Ethereum **não retorna `bool`** em `transfer()`. Embora em Polygon o USDT funcione corretamente, se o protocolo for migrado para Ethereum ou outro colateral não-conforme for adicionado, as transferências falharão silenciosamente.

**Recomendação:** Usar `SafeERC20.safeTransfer()` e `SafeERC20.safeTransferFrom()` da OpenZeppelin.

---

### BAIXO (L) — Risco menor

#### L-01: `emergencyMode` e `Pausable` são redundantes — DChatToken.sol:108,553-556

**Contrato:** `DChatToken`
**Severidade:** Baixo

O contrato possui tanto `emergencyMode` (toggle manual) quanto `Pausable` do OpenZeppelin. Ambos fazem essencialmente a mesma coisa (bloquear operações). Manter dois mecanismos de pausa cria complexidade desnecessária e confusão operacional.

**Recomendação:** Remover `emergencyMode` e usar exclusivamente `Pausable`.

---

#### L-02: `depositRewards` aberto a qualquer endereço — DChatStaking.sol:209

**Contrato:** `DChatStaking`
**Função:** `depositRewards()`
**Severidade:** Baixo

Qualquer endereço pode chamar `depositRewards()`, não apenas o `DChatToken`. Embora não cause perda de fundos (tokens são transferidos para o contrato), permite manipulação das métricas de APY e distribuição de recompensas.

---

#### L-03: `collateralTokens` array cresce indefinidamente — DChatStablecoin.sol:47-48,520-526

**Contrato:** `DChatStablecoin`
**Severidade:** Baixo

O array `collateralTokens` só cresce (no `addCollateralToken`). O `removeCollateralToken` faz swap-and-pop, mas não há limite no tamanho do array. Se muitos tokens forem adicionados e removidos, o array pode ficar grande, embora o gas impact seja mínimo pois nenhuma função itera sobre ele internamente.

---

#### L-04: Sem evento para `setActivationFee` — DChatStablecoin.sol:562-565

**Contrato:** `DChatStablecoin`
**Severidade:** Baixo

A função `setActivationFee()` não emite evento, dificultando rastreamento off-chain de mudanças na taxa de ativação.

---

#### L-05: `processMessageBatch` duplica lógica ao invés de chamar `processMessage` — DChatToken.sol:339-395

**Contrato:** `DChatToken`
**Severidade:** Baixo

A função `processMessageBatch()` duplica toda a lógica de `processMessage()` inline ao invés de chamar a função individual. Isso aumenta o risco de inconsistência se uma for atualizada sem a outra. Além disso, o batch usa `nonReentrant` no loop externo, o que está correto, mas a duplicação de código é desnecessária.

---

#### L-06: `isProposalExecutable` não verifica `EXECUTION_DEADLINE` — DGovGovernance.sol:470-473

**Contrato:** `DGovGovernance`
**Severidade:** Baixo

A view function `isProposalExecutable()` retorna `true` mesmo se o `EXECUTION_DEADLINE` já expirou, enquanto a função real `executeProposal()` faz essa verificação. Isso causa informação inconsistente para frontends.

```solidity
// ATUAL — não verifica deadline
function isProposalExecutable(uint256 pid) external view returns (bool) {
    ProposalCore storage c = proposalCores[pid];
    return (c.timelockEnd > 0 && block.timestamp >= c.timelockEnd && !c.executed);
    // FALTA: && block.timestamp <= c.timelockEnd + EXECUTION_DEADLINE
}
```

---

#### L-07: `founderVestingAvailable()` pode retornar valor incorreto se `founderVestingStart` for futuro — DChatToken.sol:482-492

**Contrato:** `DChatToken`
**Severidade:** Informacional

O `founderVestingStart` é definido como `block.timestamp` no constructor, então nunca será futuro. Porém, a função `founderVestingAvailable()` verifica `block.timestamp < founderVestingStart` sem considerar que o vesting é configurado no constructor e nunca muda. Código defensivo correto, sem ação necessária.

---

### INFORMACIONAL (I)

#### I-01: Dois contratos de token com mesmo ticker "DCHAT"

O `DChatToken.sol` (ERC-20 de utilidade) e o `DChatStablecoin.sol` (stablecoin) usam o mesmo ticker "DCHAT". Isso causa confusão em exploradores de bloco, wallets e DEXs. O `DChatToken` parece ser um contrato legado não utilizado na arquitetura atual.

**Recomendação:** Remover `DChatToken.sol` se não for mais utilizado, ou renomear um dos tickers.

---

#### I-02: `DChatStaking.sol` referencia `DChatToken` mas arquitetura usa `DChatStablecoin`

O contrato de staking aceita qualquer IERC20 via constructor. Na arquitetura documentada, o token circulante é o `DChatStablecoin`, mas o staking foi projetado originalmente para o `DChatToken` legado. Verificar se está deployed com o endereço correto.

---

#### I-03: Sem `receive()` ou `fallback()` — tokens nativos (MATIC) enviados são perdidos

Nenhum dos contratos possui `receive()` ou `fallback()`. MATIC enviado diretamente será rejeitado (revert), o que é o comportamento desejado. Sem ação necessária.

---

## Resumo de Severidades

| Severidade | Quantidade | IDs |
|------------|-----------|-----|
| Crítico | 3 | C-01, C-02, C-03 |
| Alto | 4 | H-01, H-02, H-03, H-04 |
| Médio | 6 | M-01, M-02, M-03, M-04, M-05, M-06 |
| Baixo | 7 | L-01 a L-07 |
| Informacional | 3 | I-01, I-02, I-03 |
| **Total** | **23** | |

---

## Pontos Positivos

1. **Uso correto de OpenZeppelin 5.x** — `ReentrancyGuard`, `Pausable`, `AccessControl`, `SafeERC20` (parcial)
2. **Points-per-token pattern** — Distribuição de rewards O(1) sem loops (DChatStablecoin nodes, DividendPool)
3. **Anti-sniping com limite** — Máximo de 6 extensões (1h extra) previne leilões infinitos
4. **Batch limits** — Nodes (100), user registration (200), bids (100) previnem DoS por gas
5. **Timelock de 48h na governança** — Período adequado para review antes de execução
6. **Target whitelist** — Propostas só executam em contratos pré-aprovados
7. **Admin transfer com 2-step** — `initiateAdminTransfer` + `acceptAdminTransfer` previne perda de admin
8. **Vesting robusto** — Founder com tranches anuais, marketing com lock 180d + vesting 180d linear
9. **Collateralization ratio** — View function desconta admin mints para ratio real
10. **Execution deadline** — Propostas expiram 7 dias após timelock (previne execução de propostas antigas)

---

## Recomendações Prioritárias

### Ação Imediata (Antes de qualquer movimentação significativa)
1. **C-01:** Adicionar `whenNotPaused` ao `redeem()`
2. **C-02:** Implementar conversão dinâmica de decimais para colateral
3. **C-03:** Reduzir `MAX_BIDS_PER_AUCTION` ou otimizar sorting

### Curto Prazo (1-2 semanas)
4. **H-01:** Implementar assinaturas EIP-712 para processMessage
5. **M-06:** Migrar para `SafeERC20` em todos os contratos
6. **M-02:** Adicionar proteção fee-on-transfer no vault

### Médio Prazo (1 mês)
7. **M-01:** Adicionar campo `cancelled` ao ProposalCore
8. **M-05:** Simplificar sistema de dividend weight (remover manual)
9. **L-01:** Remover `emergencyMode` redundante do DChatToken
10. **I-01:** Resolver conflito de tickers "DCHAT"

---

## Notas Sobre Contratos Legados

Os contratos `DChatToken.sol` e `DChatStaking.sol` parecem ser versões legadas da arquitetura v1/v2. A arquitetura atual (v3) utiliza:
- `DChatStablecoin.sol` como token circulante
- `DGovToken.sol` como token de governança
- `DividendPool.sol` para dividendos
- `DGovGovernance.sol` para governança

**Recomendação:** Se `DChatToken.sol` e `DChatStaking.sol` não estão deployed em produção, considerar remover do repositório para evitar confusão.

---

*Relatório gerado em 2026-03-23. Esta auditoria é baseada em análise estática do código-fonte. Testes dinâmicos (fuzzing, symbolic execution) e verificação formal não foram realizados neste escopo.*
