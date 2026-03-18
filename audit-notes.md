# Notas de Auditoria — DecentraChat Smart Contracts v4.0

## Contratos Analisados
1. DGovToken.sol (911 linhas) — Token de governança ERC-20
2. DChatStablecoin.sol (571 linhas) — Stablecoin de utilidade
3. DividendPool.sol (343 linhas) — Pool de dividendos
4. DGovGovernance.sol (432 linhas) — Governança avançada

---

## FINDINGS — DGovToken.sol

### [CRITICAL] F-01: Sorting algorithm O(n²) pode causar DoS por gas
- **Localização**: `_sortBidsByPrice()` (linhas 655-671)
- **Descrição**: Insertion sort é O(n²). Se um leilão tiver centenas de bids, `finalizeAuction()` pode exceder o gas limit do bloco, tornando o leilão impossível de finalizar.
- **Impacto**: ALTO — Tokens ficam permanentemente locked no contrato se o leilão não puder ser finalizado.
- **Recomendação**: Implementar limite máximo de bids por leilão (ex: 200) ou usar sorting off-chain com verificação on-chain.

### [HIGH] F-02: Falta de limite máximo de bids por leilão
- **Localização**: `placeBid()` (linhas 541-608)
- **Descrição**: Não há `require` limitando o número de bids. Um atacante pode criar milhares de bids pequenos para tornar `finalizeAuction()` impossível por gas.
- **Impacto**: ALTO — DoS no leilão, tokens locked.
- **Recomendação**: Adicionar `MAX_BIDS_PER_AUCTION` (ex: 500).

### [MEDIUM] F-03: Anti-sniping pode ser explorado para extensão infinita
- **Localização**: `placeBid()` linhas 602-605
- **Descrição**: Cada bid nos últimos 10 minutos estende por +10 minutos. Um atacante com escrow suficiente pode fazer bids repetidos para estender o leilão indefinidamente.
- **Impacto**: MÉDIO — Leilão pode durar dias, afetando a programação semanal.
- **Recomendação**: Adicionar `MAX_EXTENSIONS` (ex: 6, totalizando 1h extra máxima).

### [MEDIUM] F-04: `_update()` override com loop pode causar gas alto em transferências
- **Localização**: `_update()` → `getMarketingLockedBalance()` (linhas 328-350)
- **Descrição**: Cada transferência de um prestador de marketing itera sobre todos os locks para calcular o saldo locked. Se um prestador tiver muitos locks, transferências ficam caras.
- **Impacto**: MÉDIO — Gas alto para prestadores com muitos locks.
- **Recomendação**: Manter um `totalLockedCache` atualizado em cada claim, evitando o loop.

### [LOW] F-05: `claimMarketingVesting()` não transfere tokens, apenas atualiza contadores
- **Localização**: `claimMarketingVesting()` (linhas 297-311)
- **Descrição**: A função atualiza `lock.claimed` e `totalMarketingLocked` mas NÃO faz `_transfer()`. Os tokens já estão na carteira do prestador (foram transferidos no `transferMarketingTokens`). O "claim" apenas libera o lock para que possam ser transferidos. Isso é correto por design, mas o nome da função pode confundir.
- **Impacto**: BAIXO — Confusão semântica, sem impacto financeiro.
- **Recomendação**: Renomear para `unlockMarketingVesting()` para clareza.

### [LOW] F-06: `registerUserBatch()` sem limite de array
- **Localização**: Linhas 218-226
- **Descrição**: Sem limite no tamanho do array, pode causar out-of-gas.
- **Recomendação**: Adicionar `require(users.length <= 200)`.

### [INFO] F-07: Incremento mínimo de 5% não é enforced
- **Localização**: `placeBid()` linhas 558-565
- **Descrição**: O comentário menciona incremento de 5% mas o código não o enforça. Qualquer preço >= MIN_BID_PER_DGOV é aceito.
- **Impacto**: INFO — Design decision, mas inconsistente com a documentação.

### [INFO] F-08: `startNextAuction()` pode ser chamada por qualquer pessoa
- **Localização**: Linha 502
- **Descrição**: Não tem `onlyRole`. Qualquer pessoa pode iniciar o próximo leilão se o tempo permitir.
- **Impacto**: INFO — Pode ser intencional (permissionless), mas deve ser documentado.

---

## FINDINGS — DChatStablecoin.sol

### [CRITICAL] F-09: `adminMint()` permite mint sem colateral
- **Localização**: Linhas 235-239
- **Descrição**: `MINTER_ROLE` pode mintar $DCHAT sem depositar colateral. Isso quebra o peg 1:1 e a garantia de 100% de colateralização.
- **Impacto**: CRÍTICO — Se abusado, descolateraliza a stablecoin.
- **Recomendação**: Remover `adminMint()` ou adicionar mecanismo de colateral obrigatório. Se necessário para bootstrap, adicionar um `maxAdminMint` com cap e timelock.

### [HIGH] F-10: `processMessage()` assume que sender tem saldo suficiente mas não verifica allowance
- **Localização**: Linhas 296-340
- **Descrição**: A função usa `_transfer(sender, ...)` diretamente, o que funciona porque é chamada pelo RELAYER_ROLE. Mas o relayer pode transferir tokens do sender sem sua aprovação explícita on-chain. Isso é um design centralizado.
- **Impacto**: ALTO — Relayer malicioso pode drenar saldos de qualquer usuário.
- **Recomendação**: Implementar sistema de allowance onde o sender pré-aprova o contrato, ou usar meta-transactions com assinatura.

### [MEDIUM] F-11: `_distributeToNodes()` com loop pode causar DoS
- **Localização**: Linhas 548-561
- **Descrição**: Itera sobre todos os nodes ativos (até 500). Se houver muitos nodes, `processMessage()` pode exceder gas limit.
- **Impacto**: MÉDIO — Mensagens não podem ser processadas se houver muitos nodes.
- **Recomendação**: Usar sistema de acumulação (como o DividendPool) ao invés de distribuição direta.

### [MEDIUM] F-12: Remoção de collateral token com swap-and-pop pode alterar ordem
- **Localização**: `removeCollateralToken()` linhas 430-443
- **Descrição**: Usa swap-and-pop que altera a ordem do array. Não é um bug, mas pode confundir integrações off-chain.
- **Impacto**: BAIXO.

### [LOW] F-13: `getCollateralizationRatio()` pode retornar valor incorreto com adminMint
- **Localização**: Linhas 535-542
- **Descrição**: Se `adminMint()` for usado, o ratio cai abaixo de 100%, mas não há mecanismo para impedir isso.
- **Impacto**: BAIXO — Depende de F-09.

### [INFO] F-14: Sem mecanismo de pausa (circuit breaker)
- **Descrição**: Nenhum dos contratos implementa `Pausable`. Em caso de exploit, não há como pausar operações.
- **Recomendação**: Adicionar `Pausable` do OpenZeppelin a todos os contratos.

---

## FINDINGS — DividendPool.sol

### [HIGH] F-15: Diluição de dividendos por tokens no contrato DGovToken
- **Localização**: `_getTotalDividendWeight()` (linhas 216-246)
- **Descrição**: Usa `dgovToken.totalSupply() + totalVestingWeight` como denominador. Mas `totalSupply()` inclui tokens held pelo contrato DGovToken (auction tokens não vendidos). Esses tokens nunca podem claim dividendos, mas diluem os dividendos de todos os holders reais.
- **Impacto**: ALTO — Holders recebem menos dividendos do que deveriam. A diluição pode ser significativa (até 60% do supply está no contrato no início).
- **Recomendação**: Usar `getTotalDividendWeight()` do DGovToken que já desconta auction tokens, ou subtrair `balanceOf(dgov_contract_address)` do totalSupply.

### [MEDIUM] F-16: `depositDividends()` e `depositAuctionRevenue()` sem access control
- **Localização**: Linhas 144-155
- **Descrição**: Qualquer endereço pode depositar dividendos. Isso não é um bug per se, mas permite manipulação do `pointsPerToken` se feito antes de holders registrarem seus snapshots.
- **Impacto**: MÉDIO — Manipulação de timing de dividendos.
- **Recomendação**: Adicionar `onlyRole(DEPOSITOR_ROLE)` para controlar quem pode depositar.

### [MEDIUM] F-17: Vesting weight é gerenciado manualmente pelo admin
- **Localização**: `setVestingWeight()` e `reduceVestingWeight()` (linhas 107-135)
- **Descrição**: O admin deve manualmente atualizar o vesting weight quando o founder/marketing faz claim. Se esquecer, o holder recebe dividendos duplos (via balance + via vestingWeight).
- **Impacto**: MÉDIO — Dividendos duplicados se admin não sincronizar.
- **Recomendação**: Automatizar via callback do DGovToken no claim, ou ler diretamente do DGovToken.getVestingWeight().

### [LOW] F-18: `estimateAnnualYield()` assume 30 dias de dados
- **Localização**: Linha 323
- **Descrição**: Divide por 30 (dias) para estimar yield anual, mas não há garantia de que o contrato tem 30 dias de dados.
- **Impacto**: BAIXO — Estimativa incorreta nos primeiros dias.

---

## FINDINGS — DGovGovernance.sol

### [HIGH] F-19: `executeProposal()` com arbitrary call sem restrições
- **Localização**: Linhas 311-323
- **Descrição**: Se a proposta passa, `ex.target.call(ex.data)` é executado sem restrições. Isso permite chamar QUALQUER função em QUALQUER contrato, incluindo `selfdestruct`, `transferOwnership`, etc.
- **Impacto**: ALTO — Se o quorum for atingido por atores maliciosos, podem destruir o protocolo.
- **Recomendação**: Implementar whitelist de targets e function selectors permitidos, ou limitar a execução a funções específicas do protocolo.

### [MEDIUM] F-20: Snapshot pode ser manipulado se não registrado antes do voto
- **Localização**: `_autoSnapshot()` (linhas 280-286)
- **Descrição**: Se o voter não registrou snapshot antes, o auto-snapshot usa o saldo ATUAL (não o do momento da criação da proposta). Um atacante pode comprar tokens, votar, e vender.
- **Impacto**: MÉDIO — Parcialmente mitigado pelo timelock de 48h, mas não totalmente.
- **Recomendação**: Forçar snapshot no momento da criação da proposta para TODOS os holders (usando ERC20Votes/Checkpoints do OpenZeppelin).

### [MEDIUM] F-21: `_markDelegatorsVoted()` com loop pode causar DoS
- **Localização**: Linhas 288-295
- **Descrição**: Se um delegate tem muitos delegators, o loop pode exceder gas limit.
- **Recomendação**: Limitar número de delegators por delegate (ex: 50).

### [MEDIUM] F-22: Admin não pode ser alterado
- **Localização**: Linha 43
- **Descrição**: `admin` é set no constructor e não há função para alterá-lo. Se a chave do admin for comprometida, não há recovery.
- **Recomendação**: Adicionar `transferAdmin()` com timelock.

### [LOW] F-23: Propostas não têm deadline para execução
- **Localização**: `executeProposal()` (linhas 311-323)
- **Descrição**: Uma proposta queued pode ser executada a qualquer momento após o timelock, mesmo meses depois. Condições de mercado podem ter mudado.
- **Recomendação**: Adicionar `EXECUTION_DEADLINE` (ex: 7 dias após timelock).

### [LOW] F-24: Sem mecanismo de cancelamento de proposta
- **Descrição**: Uma vez criada, a proposta não pode ser cancelada pelo proposer ou pelo admin.
- **Recomendação**: Adicionar `cancelProposal()` pelo proposer (antes do fim da votação) ou pelo admin (em emergência).

---

## RESUMO DE SEVERIDADE

| Severidade | Quantidade | IDs |
|---|---|---|
| CRITICAL | 2 | F-01, F-09 |
| HIGH | 4 | F-02, F-10, F-15, F-19 |
| MEDIUM | 8 | F-03, F-04, F-11, F-16, F-17, F-20, F-21, F-22 |
| LOW | 6 | F-05, F-06, F-13, F-18, F-23, F-24 |
| INFO | 3 | F-07, F-08, F-14 |
| **TOTAL** | **23** | |
