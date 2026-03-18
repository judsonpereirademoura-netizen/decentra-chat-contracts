# Segunda Auditoria — Notas de Análise Cruzada

## Análise Realizada em: 2026-03-18

---

## A. FINDINGS CRÍTICOS / ALTOS

### SA-01 [ALTO] DGovToken._fillBids: Bid parcialmente preenchido marca filled=true incorretamente
- **Contrato**: DGovToken.sol, linha 710
- **Problema**: Quando um bid é parcialmente preenchido (fillQty < bid.quantity), `bid.filled = true` é setado. Isso impede que o bid restante seja preenchido em cenário futuro e marca como "preenchido" algo que foi parcial.
- **Impacto**: O bidder perde a diferença (bid.quantity - fillQty) sem receber tokens nem refund do escrow correspondente.
- **Análise detalhada**: Na linha 715, `bidderBal.locked -= bid.totalCost` remove TODO o locked, mas na linha 722, `bidderBal.total -= fillCost` só remove o custo proporcional. Isso significa que o excedente (bid.totalCost - fillCost) é corretamente desbloqueado (locked diminui pelo total, total diminui só pelo parcial). O refund na linha 717-719 emite evento de refund da diferença. **MAS** o _refundUnfilledBids na linha 736 verifica `if (!bid.filled)` — como filled=true, bids parciais NÃO passam pelo refund loop. Isso está correto porque o refund já aconteceu na _fillBids. **REAVALIAÇÃO: NÃO É BUG — o fluxo está correto, mas a nomenclatura é confusa.**
- **Recomendação**: Renomear `filled` para `processed` e adicionar campo `partialFill` para clareza.

### SA-02 [ALTO] DGovToken.finalizeAuction: Sorting O(n²) pode causar DoS com 500 bids
- **Contrato**: DGovToken.sol, _sortBidsByPrice (linha 679-695)
- **Problema**: Insertion sort é O(n²). Com MAX_BIDS=500, são 250.000 comparações. Cada comparação acessa storage (bids[sortedIndices[j-1]].pricePerUnit), que custa ~2.100 gas (SLOAD).
- **Cálculo de gas**: 250.000 × 2.100 = ~525M gas. Block gas limit na Polygon é ~30M.
- **Impacto**: **finalizeAuction pode ser impossível de executar** se houver mais de ~120 bids.
- **Correção**: Reduzir MAX_BIDS para 100, ou implementar sorting off-chain com verificação on-chain, ou usar bucket sort por faixas de preço.

### SA-03 [ALTO] DGovToken.placeBid: F-07 (5% increment) bloqueia bids legítimos
- **Contrato**: DGovToken.sol, linha 584-587
- **Problema**: O require exige que qualquer bid ACIMA do highest seja >= 5% maior. Mas e se o highest é 1.0 DCHAT/DGOV e alguém quer dar bid de 1.02? Isso é rejeitado (precisa ser >= 1.05). Isso pode desincentivar participação.
- **Impacto**: Médio — reduz liquidez do leilão. Mas é uma decisão de design, não um bug.
- **Recomendação**: Manter como está (decisão do Judson), mas documentar claramente no whitepaper.

### SA-04 [ALTO] DChatStablecoin.processMessage: Relayer pode ser front-runned
- **Contrato**: DChatStablecoin.sol, processMessage (linha 336)
- **Problema**: O relayer submete tx com dados da mensagem. Um MEV bot pode ver a tx no mempool e front-run com uma tx que drena o allowance do sender (se o bot tiver RELAYER_ROLE, o que não deveria).
- **Análise**: Como RELAYER_ROLE é restrito, isso NÃO é explorável por terceiros. Mas o relayer em si pode ser malicioso.
- **Mitigação existente**: F-10 (relayerDailyLimit) limita o dano. **ADEQUADO.**

### SA-05 [ALTO] DividendPool._getTotalDividendWeight: Marketing weight conta tokens locked E unlocked
- **Contrato**: DividendPool.sol, linha 274
- **Problema**: `marketingAutoWeight = dgovToken.totalMarketingDistributed()` inclui tokens que já foram unlocked (claimed). Esses tokens já estão no balanceOf do prestador, então são contados DUAS VEZES: uma pelo balanceOf e outra pelo marketingAutoWeight.
- **Impacto**: **Diluição de dividendos para todos os outros holders.** Prestadores de marketing recebem dividendos duplicados sobre tokens já unlocked.
- **Correção**: Usar `totalMarketingLocked` ao invés de `totalMarketingDistributed`, ou subtrair tokens já claimed.

### SA-06 [ALTO] DGovGovernance.cancelProposal: Operador de precedência incorreto
- **Contrato**: DGovGovernance.sol, linha 392-395
- **Problema**: `msg.sender == c.proposer && block.timestamp < c.endTime || msg.sender == admin`
- Em Solidity, `&&` tem precedência sobre `||`. Então isso é: `(proposer AND antes_do_fim) OR admin`. Isso está CORRETO para a lógica desejada.
- **Mas**: Falta parênteses explícitos para clareza. Pode confundir auditores.
- **Recomendação**: Adicionar parênteses: `(msg.sender == c.proposer && block.timestamp < c.endTime) || msg.sender == admin`

---

## B. FINDINGS MÉDIOS

### SA-07 [MÉDIO] DGovToken: Falta evento em setDividendPool
- **Contrato**: DGovToken.sol, linha 914-917
- **Problema**: `setDividendPool` não emite evento. Mudança de endereço crítico sem registro on-chain.
- **Correção**: Adicionar evento DividendPoolUpdated.

### SA-08 [MÉDIO] DChatStablecoin: payActivationFee não verifica relayer allowance
- **Contrato**: DChatStablecoin.sol, linha 486-490
- **Problema**: `payActivationFee` é chamado pelo RELAYER_ROLE mas NÃO verifica o relayerDailyLimit do user. O relayer pode cobrar ativação sem aprovação.
- **Correção**: Adicionar check de relayer allowance ou fazer o user pagar diretamente.

### SA-09 [MÉDIO] DGovGovernance: Snapshot pode ser manipulado se voter comprar tokens entre criação e voto
- **Contrato**: DGovGovernance.sol, _autoSnapshot (linha 341-347)
- **Problema**: O snapshot é gravado no momento do VOTO (se não foi gravado antes). Se um voter compra tokens DEPOIS da criação da proposta mas ANTES de votar, o snapshot captura o saldo inflado.
- **Impacto**: Flash-loan parcialmente mitigado (precisa manter tokens até votar), mas whale pode comprar tokens no mercado para influenciar voto.
- **Correção**: Forçar snapshot no momento da criação da proposta para TODOS os voters registrados, ou usar block number snapshot como OpenZeppelin Governor.

### SA-10 [MÉDIO] ReserveWallet: _getCurrentMonth usa divisão por 30 dias (impreciso)
- **Contrato**: ReserveWallet.sol, linha 381
- **Problema**: `block.timestamp / 30 days` não corresponde a meses reais. Fevereiro tem 28 dias, meses com 31 dias cruzam a fronteira.
- **Impacto**: Baixo — pode haver overlap de ~1 dia entre "meses" contábeis.
- **Recomendação**: Aceitável para v1, documentar que "mês" = período de 30 dias.

### SA-11 [MÉDIO] DGovToken: Founder pode chamar claimFounderVesting e transferir tokens para si mesmo sem limite de frequência
- **Contrato**: DGovToken.sol
- **Problema**: Não encontrado — preciso verificar se existe rate limiting no claimFounderVesting.
- **Verificação necessária**: Ler a função claimFounderVesting.

### SA-12 [MÉDIO] DividendPool: getHolderWeight usa max(auto, manual) — pode causar inconsistência
- **Contrato**: DividendPool.sol, linha 254-256
- **Problema**: Se o admin seta vestingWeight manual para 20M mas o auto retorna 15M (porque tokens foram claimed), o sistema usa 20M (o maior). Isso pode ser intencional (retrocompatibilidade) mas cria risco de peso inflado se o admin esquecer de atualizar.
- **Correção**: Remover vestingWeight manual e usar APENAS o automático (F-17 já implementado). Ou adicionar função para sincronizar.

---

## C. AUTOMAÇÕES FALTANTES

### AUTO-01: Founder vesting claim deveria atualizar DividendPool automaticamente
- Quando o founder faz claim de uma tranche, o vestingWeight no DividendPool deveria diminuir automaticamente.
- Atualmente: depende de chamada manual do admin.
- Com F-17: o getVestingWeight já é automático, MAS o vestingWeight manual no DividendPool pode estar desatualizado.

### AUTO-02: Marketing lock unlock deveria atualizar DividendPool automaticamente
- Quando prestador faz unlockMarketingVesting, o peso de marketing deveria diminuir no DividendPool.
- Com F-17: totalMarketingDistributed é usado, mas inclui tokens já unlocked (SA-05).

### AUTO-03: Auction finalization deveria depositar automaticamente no DividendPool
- Atualmente: finalizeAuction transfere tokens para dividendPool, mas NÃO chama depositAuctionRevenue.
- O DividendPool precisa que alguém chame depositAuctionRevenue separadamente.
- **Correção**: DGovToken deveria chamar dividendPool.depositAuctionRevenue() automaticamente, ou o DividendPool deveria aceitar tokens via receive/fallback.

### AUTO-04: Node registration deveria ser self-service (com stake mínimo)
- Atualmente: só admin pode registrar nodes.
- **Sugestão**: Permitir auto-registro com stake mínimo em $DCHAT.

### AUTO-05: Deactivação de voter inativo deveria ser incentivada
- Atualmente: qualquer pessoa pode chamar deactivateInactiveVoter, mas não há incentivo.
- **Sugestão**: Dar um pequeno reward em $DCHAT para quem limpa voters inativos.

### AUTO-06: DGovToken.startNextAuction deveria ser chamável por qualquer pessoa
- Já é! Qualquer pessoa pode chamar startNextAuction. ✅

### AUTO-07: ReserveWallet não tem mecanismo de emergency withdrawal
- Se o contrato for pausado, o admin não pode sacar para emergências.
- **Sugestão**: Adicionar emergencyWithdraw com timelock de 72h.

---

## D. EDGE CASES

### EDGE-01: O que acontece se TODOS os tokens de um leilão forem queimados?
- Se ninguém der bid, finalizeAuction queima tudo. ✅ Correto.

### EDGE-02: O que acontece se o founder nunca fizer claim do vesting?
- Os tokens ficam no contrato DGovToken. O vestingWeight continua contando para dividendos. ✅ Correto.

### EDGE-03: O que acontece se o DividendPool ficar sem $DCHAT?
- claimDividends falhará com "Transfer failed". Holders perdem dividendos? NÃO — pendingDividends continua acumulando, claim funciona quando houver saldo.
- **MAS**: Se o pool recebe mais depósitos, os pontos-por-token aumentam e holders antigos que não claimaram podem ter pending calculado incorretamente se o peso mudou.
- **Análise**: O sistema de pontos-por-token é correto DESDE QUE o peso do holder não mude entre depósitos. Se o holder vende tokens, o pending calculado com o peso antigo é mantido (correto), mas novos depósitos usam o peso novo (correto). ✅

### EDGE-04: Overflow em nodeRewardPerToken
- NODE_PRECISION = 1e36. Se nodeFee = 1e18 e totalNodeStake = 1, então increment = 1e18 * 1e36 / 1 = 1e54. uint256 max = ~1.15e77. Com 1e54 por mensagem e 1e9 mensagens, total = 1e63. Ainda seguro. ✅

### EDGE-05: O que acontece se collateral token (USDC/USDT) for pausado/blacklisted?
- mint e redeem falharão. Não há fallback.
- **Recomendação**: Documentar risco. Adicionar collateral alternativo (DAI).
