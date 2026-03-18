# TODO — Governança Avançada v3.1

## Alterações no DGovToken

### Governança
- [ ] Quorum: 60% + 1 do TOTAL EMITIDO (não circulante) — `totalSupply * 60 / 100 + 1`
- [ ] Threshold dinâmico: baseado no total emitido (incluindo 40% fundador+marketing)
- [ ] Timelock 48h: proposta aprovada entra em fila, execução só após 48h
- [ ] Delegação de voto: holders se inscrevem como votantes, podem delegar para outro endereço
- [ ] Atividade: votantes inativos perdem representação, podem se reabilitar
- [ ] Snapshot de saldo: registrar balanceOf no momento da criação da proposta (anti flash-loan)

### Marketing Lock Alternativo
- [ ] Remover cliff puro de 180 dias
- [ ] Implementar: 180 dias de lock total + 180 dias de liberação linear gradual
- [ ] Total: 360 dias do transfer até liberação completa

### Testes
- [ ] Atualizar testes de governança (quorum, threshold, timelock, delegação, snapshot)
- [ ] Atualizar testes de marketing lock (linear vesting após cliff)
- [ ] Testes de integração

### Frontend
- [ ] Atualizar Governance page com novos mecanismos
- [ ] Atualizar ABIs
- [ ] Atualizar dual-token-service.ts

## Decisões de Arquitetura
- Sem rage quit (fere livre comércio)
- Fundador mantém 40% (30% + 10% marketing) — transparente via blockchain
- Controle nos primeiros meses é intencional e transparente
