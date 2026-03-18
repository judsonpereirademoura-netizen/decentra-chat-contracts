# Cronograma de Implementação — Correção de Findings da Auditoria

**Projeto:** DecentraChat Smart Contracts v4.0  
**Autor:** The Architect — AGI-Core  
**Data:** 18 de março de 2026  
**Total de Findings:** 23 | **Corrigidos:** 15 | **Pendentes:** 8

---

## Status Geral dos Findings

### Findings JÁ CORRIGIDOS (15/23)

| ID | Severidade | Contrato | Descrição | Status |
|---|---|---|---|---|
| F-01 | Crítica | DGovToken | DoS por sorting O(n²) no leilão | CORRIGIDO — MAX_BIDS_PER_AUCTION=500 |
| F-02 | Alta | DGovToken | Ausência de limite de bids por leilão | CORRIGIDO — require no placeBid() |
| F-03 | Média | DGovToken | Anti-sniping com extensão infinita | CORRIGIDO — MAX_ANTI_SNIPE_EXTENSIONS=6 |
| F-05 | Baixa | DGovToken | Nome confuso claimMarketingVesting | CORRIGIDO — renomeado para unlockMarketingVesting |
| F-06 | Baixa | DGovToken | registerUserBatch sem limite | CORRIGIDO — limitado a 200 users |
| F-09 | Crítica | DChatStablecoin | adminMint sem colateral ilimitado | CORRIGIDO — MAX_ADMIN_MINT=100k |
| F-15 | Alta | DividendPool | Diluição por tokens inativos | CORRIGIDO — exclui balance do DGovToken contract |
| F-16 | Média | DividendPool | depositDividends sem access control | CORRIGIDO — DEPOSITOR_ROLE adicionado |
| F-19 | Alta | DGovGovernance | Execução arbitrária sem restrições | CORRIGIDO — whitelist de targets |
| F-21 | Média | DGovGovernance | DoS por muitos delegators | CORRIGIDO — MAX_DELEGATORS_PER_DELEGATE=50 |
| F-22 | Média | DGovGovernance | Admin sem mecanismo de recovery | CORRIGIDO — initiateAdminTransfer/acceptAdminTransfer |
| F-23 | Baixa | DGovGovernance | Sem deadline de execução | CORRIGIDO — EXECUTION_DEADLINE=7 dias |
| F-24 | Baixa | DGovGovernance | Sem cancelamento de proposta | CORRIGIDO — cancelProposal() |

*Nota: F-01 e F-02 foram corrigidos juntos com a mesma solução (MAX_BIDS_PER_AUCTION).*

---

### Findings PENDENTES (8/23)

| ID | Severidade | Contrato | Descrição | Prioridade |
|---|---|---|---|---|
| F-04 | Média | DGovToken | _update() itera marketing locks em cada transfer | Sprint 1 |
| F-10 | Alta | DChatStablecoin | Relayer transfere sem aprovação on-chain | Sprint 1 |
| F-11 | Média | DChatStablecoin | _distributeToNodes() loop pode exceder gas | Sprint 1 |
| F-13 | Baixa | DChatStablecoin | getCollateralizationRatio incorreto com adminMint | Sprint 2 |
| F-17 | Média | DividendPool | Vesting weight manual pode causar duplicação | Sprint 2 |
| F-18 | Baixa | DividendPool | estimateAnnualYield incorreto nos primeiros dias | Sprint 3 |
| F-20 | Média | DGovGovernance | Snapshot permite compra-voto-venda | Sprint 2 |
| F-07 | Info | DGovToken | Incremento mínimo 5% não enforced | Sprint 3 |
| F-08 | Info | DGovToken | startNextAuction permissionless | Sprint 3 |
| F-14 | Info | Todos | Nenhum contrato implementa Pausable | Sprint 2 |

---

## Novas Implementações Solicitadas

| Item | Contrato | Descrição | Sprint |
|---|---|---|---|
| N-01 | DChatStablecoin | Regras rígidas para ReserveWallet — só despesas operacionais | Sprint 1 |
| N-02 | DChatStablecoin | Configuração do desktop do fundador como primeiro node | Sprint 1 |

---

## Cronograma por Sprint

### Sprint 1 — Segurança Crítica + Operacional (Estimativa: 6-8h)

**Objetivo:** Corrigir o finding de alta severidade restante (F-10), otimizar gas (F-04, F-11), e implementar regras operacionais (N-01, N-02).

| Ordem | ID | Tarefa | Estimativa | Complexidade |
|---|---|---|---|---|
| 1 | N-01 | **ReserveWallet com regras rígidas** — Criar contrato `ReserveWallet.sol` com categorias de despesa (hosting, SMS/Twilio, infra, marketing), limite mensal de saque, registro on-chain de cada gasto com categoria e descrição, e função de auditoria pública. Somente o admin pode sacar, e cada saque emite evento com justificativa. | 3h | Alta |
| 2 | N-02 | **Node do fundador** — Adicionar auto-registro do node do fundador no constructor do DChatStablecoin com stake inicial. Garantir que o desktop do fundador receba os 70% desde o primeiro dia. | 30min | Baixa |
| 3 | F-10 | **Relayer allowance** — Implementar sistema de allowance por período onde o usuário pré-aprova um valor máximo de $DCHAT que o relayer pode gastar por dia. O relayer só pode processar mensagens até o limite aprovado. Função `approveRelayerAllowance(uint256 dailyLimit)` chamada pelo usuário. | 2h | Média |
| 4 | F-04 | **Cache de marketing locks** — Manter `totalLockedCache` por endereço atualizado em cada unlock, evitando iteração sobre todos os locks em cada `_update()`. | 1h | Média |
| 5 | F-11 | **Nodes points-per-token** — Substituir o loop de distribuição por sistema de acumulação (mesmo padrão do DividendPool). Cada mensagem incrementa `rewardPerToken`, e nodes claimam quando quiserem. Elimina o loop de até 500 nodes. | 2h | Alta |

**Entregável:** Contratos compilados, testes passando, ABIs atualizados.

---

### Sprint 2 — Robustez e Transparência (Estimativa: 4-5h)

**Objetivo:** Corrigir findings de média severidade restantes e adicionar Pausable.

| Ordem | ID | Tarefa | Estimativa | Complexidade |
|---|---|---|---|---|
| 1 | F-14 | **Pausable em todos os contratos** — Adicionar herança de `Pausable` do OpenZeppelin nos 4 contratos. Funções críticas (mint, redeem, processMessage, placeBid, finalizeAuction, depositDividends, claimDividends, executeProposal) recebem modifier `whenNotPaused`. Admin pode pausar/despausar em emergências. | 2h | Média |
| 2 | F-17 | **Vesting weight automático** — DividendPool lê diretamente do DGovToken via `getVestingWeight()` ao invés de depender de atualização manual. Elimina risco de dessincronização. | 1h | Média |
| 3 | F-20 | **Snapshot forçado** — Ao criar proposta, capturar automaticamente o saldo de todos os voters registrados naquele bloco. Usar `block.number` como referência para evitar manipulação intra-bloco. | 1h | Média |
| 4 | F-13 | **Collateralization ratio corrigido** — Descontar `totalAdminMinted` do cálculo para refletir o ratio real de colateralização. | 30min | Baixa |

**Entregável:** Contratos com circuit breaker, vesting automático, snapshot robusto.

---

### Sprint 3 — Polimento e Documentação (Estimativa: 2-3h)

**Objetivo:** Corrigir findings baixos/informativos e documentar decisões de design.

| Ordem | ID | Tarefa | Estimativa | Complexidade |
|---|---|---|---|---|
| 1 | F-18 | **estimateAnnualYield dinâmico** — Usar `min(daysSinceCreation, 30)` como base ao invés de assumir 30 dias fixos. | 30min | Baixa |
| 2 | F-07 | **Enforce incremento mínimo 5%** — Adicionar `require` no `placeBid()` verificando que o preço é pelo menos 5% maior que o preço mínimo ou o menor bid existente. | 30min | Baixa |
| 3 | F-08 | **startNextAuction com restrição** — Manter permissionless mas adicionar `require` de que o leilão anterior foi finalizado e que o delay mínimo entre leilões foi respeitado. Documentar que é intencional. | 30min | Baixa |
| 4 | — | **Atualizar AUDIT_REPORT.md** — Marcar todos os findings como corrigidos, atualizar versão para v5.0, documentar decisões de design para F-08 (permissionless intencional). | 1h | Baixa |

**Entregável:** Todos os 23 findings endereçados, relatório final atualizado.

---

## Timeline Visual

```
Semana 1 (18-22 Mar)
├── Sprint 1: ReserveWallet + Node Fundador + F-10 + F-04 + F-11
│   ├── Dia 1: ReserveWallet.sol (N-01) + Node config (N-02)
│   ├── Dia 2: Relayer allowance (F-10) + Marketing cache (F-04)
│   └── Dia 3: Nodes points-per-token (F-11) + Testes + ABIs
│
Semana 2 (23-27 Mar)
├── Sprint 2: Pausable + Vesting auto + Snapshot + Ratio
│   ├── Dia 1: Pausable em 4 contratos (F-14)
│   ├── Dia 2: Vesting auto (F-17) + Snapshot (F-20) + Ratio (F-13)
│   └── Dia 3: Testes completos + ABIs + Frontend
│
Semana 3 (28-31 Mar)
├── Sprint 3: Polimento + Documentação
│   ├── Dia 1: F-18 + F-07 + F-08
│   └── Dia 2: Atualizar relatório + Testes finais + Deploy testnet
│
Semana 4 (1-4 Abr)
├── Deploy em Testnet Polygon Amoy
│   ├── Scripts de deploy automatizado
│   ├── Verificação no Polygonscan
│   └── Testes end-to-end na testnet
```

---

## Métricas de Sucesso

| Métrica | Alvo |
|---|---|
| Findings corrigidos | 23/23 (100%) |
| Testes passando | 200+ (estimativa com novos testes) |
| Cobertura de código | > 90% |
| Gas por mensagem | < 200k gas (após F-11) |
| Gas por finalizeAuction | < 5M gas (com MAX_BIDS=500) |
| Compilação sem warnings | 0 warnings |

---

## Riscos e Dependências

| Risco | Mitigação |
|---|---|
| ReserveWallet pode ser complexo demais | Começar com versão simples (categorias + eventos) e iterar |
| Points-per-token para nodes pode quebrar distribuição existente | Migrar gradualmente, manter backward compatibility |
| Pausable pode bloquear operações legítimas | Implementar timelock de 24h para unpause, multisig para pause |
| Snapshot por block.number pode ser manipulado por validators | Usar média de 3 blocos ou implementar ERC20Votes completo |

---

*Cronograma sujeito a ajustes conforme decisões do CEO. Prioridade absoluta: Sprint 1 (segurança + operacional).*
