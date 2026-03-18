# Relatório de Auditoria de Segurança — DecentraChat Smart Contracts v4.0

**Autor:** The Architect — AGI-Core / Distinguished Engineer  
**Data:** 18 de março de 2026  
**Escopo:** DGovToken.sol, DChatStablecoin.sol, DividendPool.sol, DGovGovernance.sol  
**Compilador:** Solidity ^0.8.24 | Hardhat | OpenZeppelin Contracts v5.x  
**Rede-alvo:** Polygon (Amoy Testnet → Mainnet)  
**Classificação:** CONFIDENCIAL — Uso interno DecentraChat Protocol

---

## 1. Resumo Executivo

Esta auditoria examinou os quatro smart contracts que compõem o ecossistema financeiro e de governança do DecentraChat Protocol. A análise cobriu vetores de ataque incluindo reentrância, overflow/underflow, controle de acesso, lógica de negócio, manipulação de gas, edge cases aritméticos e conformidade com o padrão ERC-20. O sistema utiliza Solidity 0.8.24 com proteção nativa contra overflow, OpenZeppelin AccessControl e ReentrancyGuard, o que elimina classes inteiras de vulnerabilidades comuns.

Foram identificados **23 findings** distribuídos em 5 níveis de severidade. Dois findings são classificados como **críticos** e requerem correção obrigatória antes de qualquer deploy em mainnet. Quatro findings são de **alta severidade** e representam riscos significativos ao protocolo. Oito findings são de **severidade média**, seis de **baixa** e três são **informativos**.

| Severidade | Quantidade | Ação Requerida |
|---|---|---|
| Crítica | 2 | Correção obrigatória antes do deploy |
| Alta | 4 | Correção fortemente recomendada |
| Média | 8 | Correção recomendada |
| Baixa | 6 | Melhoria sugerida |
| Informativa | 3 | Documentação/decisão de design |

---

## 2. Descrição dos Contratos

### 2.1 DGovToken.sol — Token de Governança ($DGOV)

O DGovToken é um token ERC-20 com supply fixo de 100 milhões de unidades, implementando um sistema complexo de alocação, vesting e leilões fracionados. O contrato herda de `ERC20`, `AccessControl` e `ReentrancyGuard` do OpenZeppelin, garantindo proteções fundamentais contra reentrância e overflow.

A alocação do supply segue a estrutura: 30% para o fundador com vesting de 10M a cada 12 meses (36 meses total), 10% para marketing com lock de 180 dias seguido de 180 dias de liberação linear por transferência individual, e 60% destinados a 156 leilões semanais fracionados com distribuição progressiva em 6 fases. O sistema de leilão implementa um modelo de order book onde múltiplos compradores submetem lances com quantidade e preço por unidade, sendo preenchidos do maior preço ao menor na finalização. Tokens não vendidos são queimados permanentemente, e 100% da receita em $DCHAT é enviada ao DividendPool.

O contrato também gerencia um sistema de escrow pool onde participantes depositam $DCHAT previamente para garantir seus lances, um mecanismo anti-sniping que estende o leilão em 10 minutos se houver lance nos últimos 10 minutos, e funções helper para o contrato de governança externo (`getTotalEmitted()`, `getVestingWeight()`).

### 2.2 DChatStablecoin.sol — Stablecoin de Utilidade ($DCHAT)

O DChatStablecoin é uma stablecoin ERC-20 com peg 1:1 ao dólar americano, lastreada por USDC e USDT depositados em um vault on-chain. O supply é ilimitado e auto-regulado pela demanda — tokens são mintados quando colateral é depositado e queimados quando colateral é resgatado, seguindo o modelo do USDC da Circle.

O contrato implementa o sistema de processamento de mensagens do DecentraChat, onde cada mensagem gera uma taxa calculada com base no tamanho em bytes e no tipo de dado (texto 1.0x, imagem 1.5x, vídeo 2.0x, áudio 1.5x, arquivo 1.2x). A distribuição das taxas segue a proporção: 70% para nodes processadores, 20% para o DividendPool (holders de $DGOV) e 10% para a reserva operacional. O settlement é individual e em tempo real.

O contrato também gerencia um registro de nodes com stake proporcional para distribuição de recompensas, uma taxa de ativação de conta de $0.10 para cobrir custos de SMS, e funções administrativas para ajuste de parâmetros.

### 2.3 DividendPool.sol — Pool de Dividendos

O DividendPool implementa um sistema de distribuição de dividendos usando o padrão **points-per-token**, que permite distribuição eficiente sem loops sobre todos os holders. O contrato recebe receita de duas fontes: 20% das taxas de mensagem (via DChatStablecoin) e 100% da receita dos leilões (via DGovToken).

O peso de dividendo de cada holder é calculado como `balanceOf($DGOV) + vestingWeight`, onde o vestingWeight permite que tokens em vesting (fundador e marketing) contem para dividendos desde o dia 1. O sistema de vesting weight é gerenciado manualmente pelo admin, que deve atualizar os pesos quando tranches de vesting são liberadas.

### 2.4 DGovGovernance.sol — Governança Avançada

O DGovGovernance é um contrato separado que implementa governança on-chain avançada para o protocolo DecentraChat. O contrato referencia o DGovToken via interface `IDGovToken` para consultar saldos e pesos de vesting.

O sistema implementa quorum de 60% + 1 do total emitido (descontando tokens queimados nos leilões), threshold dinâmico de 1% do total emitido para criação de propostas, timelock de 48 horas entre aprovação e execução, delegação de voto com inscrição obrigatória de votantes, snapshot de saldo no momento da proposta para proteção anti flash-loan, e desativação automática de votantes inativos por mais de 90 dias. As propostas suportam execução arbitrária de chamadas a contratos externos.

---

## 3. Findings Críticos

### F-01: Algoritmo de Sorting O(n²) Pode Causar DoS por Gas no Leilão

**Severidade:** CRÍTICA  
**Contrato:** DGovToken.sol  
**Função:** `_sortBidsByPrice()` (linhas 655-671)  
**Categoria:** Denial of Service

A função `_sortBidsByPrice()` implementa um insertion sort com complexidade O(n²). Na finalização do leilão, todos os bids são ordenados por preço em memória. Se um leilão acumular centenas de bids, o custo de gas para `finalizeAuction()` pode exceder o gas limit do bloco Polygon (30M gas), tornando o leilão **impossível de finalizar**. Neste cenário, os tokens do leilão e os $DCHAT no escrow ficam permanentemente locked no contrato.

Um atacante pode explorar isso intencionalmente: com escrow suficiente, ele cria centenas de bids pequenos (cada um custando apenas `MIN_BID_PER_DGOV * 1 token = 0.01 DCHAT`), tornando a finalização inviável. O custo do ataque é baixo porque os bids não preenchidos são reembolsados ao escrow.

> **Recomendação:** Adicionar uma constante `MAX_BIDS_PER_AUCTION` (recomendado: 500) com `require` no `placeBid()`. Alternativamente, implementar finalização em batches ou sorting off-chain com verificação on-chain via Merkle proof.

### F-09: `adminMint()` Permite Criação de $DCHAT Sem Colateral

**Severidade:** CRÍTICA  
**Contrato:** DChatStablecoin.sol  
**Função:** `adminMint()` (linhas 235-239)  
**Categoria:** Quebra de Invariante Econômica

A função `adminMint()` permite que o `MINTER_ROLE` crie $DCHAT sem depositar colateral correspondente. Isso viola a invariante fundamental da stablecoin: que cada $DCHAT em circulação é 100% lastreado por USDC ou USDT no vault. O uso desta função reduz o `getCollateralizationRatio()` abaixo de 100%, efetivamente descolateralizando a stablecoin.

Embora a função exista para "bootstrap e bridge operations" conforme o NatSpec, ela representa um risco sistêmico. Se a chave do `MINTER_ROLE` for comprometida, ou se houver erro operacional, a confiança na stablecoin é destruída.

> **Recomendação:** Implementar uma das seguintes abordagens: (A) Remover `adminMint()` completamente e exigir colateral para todo mint; (B) Adicionar um `maxUncollateralizedMint` com cap absoluto e timelock de 48h; (C) Manter mas adicionar `Pausable` e monitoramento on-chain do ratio de colateralização.

---

## 4. Findings de Alta Severidade

### F-02: Ausência de Limite Máximo de Bids por Leilão

**Severidade:** ALTA  
**Contrato:** DGovToken.sol  
**Função:** `placeBid()` (linhas 541-608)

Complementar ao F-01, não existe `require` limitando o número de bids por leilão. Mesmo sem intenção maliciosa, um leilão popular pode acumular bids suficientes para tornar a finalização impossível. Este finding amplifica o impacto do F-01.

> **Recomendação:** Adicionar `require(auctionBids[auctionId].length < MAX_BIDS_PER_AUCTION, "Max bids reached")`.

### F-10: Relayer Pode Transferir Tokens de Qualquer Usuário Sem Aprovação On-Chain

**Severidade:** ALTA  
**Contrato:** DChatStablecoin.sol  
**Função:** `processMessage()` (linhas 296-340)

A função `processMessage()` usa `_transfer(sender, ...)` diretamente, permitindo que o `RELAYER_ROLE` mova tokens de qualquer endereço sem aprovação explícita on-chain (sem `approve`/`transferFrom`). Isso cria um ponto de confiança centralizado: se a chave do relayer for comprometida, o atacante pode drenar o saldo de qualquer usuário.

> **Recomendação:** Implementar um sistema de allowance onde o usuário pré-aprova um valor máximo por período, ou usar meta-transactions com assinatura EIP-712 onde o sender assina cada mensagem off-chain.

### F-15: Diluição de Dividendos por Tokens Inativos no Contrato DGovToken

**Severidade:** ALTA  
**Contrato:** DividendPool.sol  
**Função:** `_getTotalDividendWeight()` (linhas 216-246)

O denominador do cálculo de dividendos usa `dgovToken.totalSupply() + totalVestingWeight`. Porém, `totalSupply()` inclui tokens held pelo contrato DGovToken que estão reservados para leilões futuros. Esses tokens nunca podem claim dividendos (o contrato não tem mecanismo para isso), mas diluem os dividendos de todos os holders reais. No início do protocolo, até 60% do supply está no contrato, causando uma diluição massiva.

Exemplo concreto: se o DividendPool recebe 1.000 $DCHAT e o founder tem 30M de peso em um total de 100M + 20M (vesting) = 120M, ele recebe apenas 25% dos dividendos. Mas os 60M de auction tokens no contrato nunca claimam, então ~50% dos dividendos ficam permanentemente presos no pool.

> **Recomendação:** Usar `DGovToken.getTotalDividendWeight()` que já desconta auction tokens, ou calcular: `totalSupply() - balanceOf(dgov_contract_address) + totalVestingWeight`.

### F-19: Execução Arbitrária de Chamadas Sem Restrições na Governança

**Severidade:** ALTA  
**Contrato:** DGovGovernance.sol  
**Função:** `executeProposal()` (linhas 311-323)

Se uma proposta atinge quorum e passa pelo timelock, `ex.target.call(ex.data)` é executado sem restrições de target ou function selector. Isso permite chamar qualquer função em qualquer contrato, incluindo `transferOwnership()`, `grantRole()`, `selfdestruct()`, ou transferência de fundos. Embora o quorum de 60%+1 seja alto, em um cenário onde poucos tokens estão em circulação (início do protocolo), o risco é amplificado.

> **Recomendação:** Implementar uma whitelist de targets permitidos (apenas contratos do protocolo) e/ou uma whitelist de function selectors. Adicionar também um mecanismo de veto pelo admin com timelock para emergências.

---

## 5. Findings de Média Severidade

| ID | Contrato | Descrição | Recomendação |
|---|---|---|---|
| F-03 | DGovToken | Anti-sniping pode ser explorado para extensão infinita do leilão via bids repetidos nos últimos 10 minutos | Adicionar `MAX_EXTENSIONS = 6` (1h extra máxima) |
| F-04 | DGovToken | `_update()` override itera sobre todos os marketing locks em cada transferência, causando gas alto para prestadores com muitos locks | Manter `totalLockedCache` atualizado em cada claim |
| F-11 | DChatStablecoin | `_distributeToNodes()` itera sobre até 500 nodes em cada mensagem, podendo exceder gas limit | Usar sistema de acumulação (points-per-token) como o DividendPool |
| F-16 | DividendPool | `depositDividends()` sem access control permite que qualquer endereço deposite e manipule timing de dividendos | Adicionar `DEPOSITOR_ROLE` |
| F-17 | DividendPool | Vesting weight gerenciado manualmente pelo admin pode causar dividendos duplicados se não sincronizado | Automatizar via callback ou leitura direta do DGovToken |
| F-20 | DGovGovernance | Auto-snapshot usa saldo atual se não registrado previamente, permitindo compra-voto-venda | Forçar snapshot no momento da criação da proposta usando ERC20Votes |
| F-21 | DGovGovernance | `_markDelegatorsVoted()` com loop pode causar DoS se delegate tem muitos delegators | Limitar delegators por delegate (máx: 50) |
| F-22 | DGovGovernance | Admin não pode ser alterado após deploy, sem mecanismo de recovery | Adicionar `transferAdmin()` com timelock |

---

## 6. Findings de Baixa Severidade e Informativos

| ID | Severidade | Contrato | Descrição |
|---|---|---|---|
| F-05 | Baixa | DGovToken | `claimMarketingVesting()` não transfere tokens (apenas libera lock). Nome confuso — sugerir renomear para `unlockMarketingVesting()` |
| F-06 | Baixa | DGovToken | `registerUserBatch()` sem limite de array pode causar out-of-gas |
| F-13 | Baixa | DChatStablecoin | `getCollateralizationRatio()` retorna valor incorreto se `adminMint()` for usado |
| F-18 | Baixa | DividendPool | `estimateAnnualYield()` assume 30 dias de dados, incorreto nos primeiros dias |
| F-23 | Baixa | DGovGovernance | Propostas não têm deadline para execução após timelock — podem ser executadas meses depois |
| F-24 | Baixa | DGovGovernance | Sem mecanismo de cancelamento de proposta pelo proposer ou admin |
| F-07 | Info | DGovToken | Incremento mínimo de 5% documentado mas não enforced no código |
| F-08 | Info | DGovToken | `startNextAuction()` é permissionless — qualquer pessoa pode iniciar |
| F-14 | Info | Todos | Nenhum contrato implementa `Pausable` (circuit breaker para emergências) |

---

## 7. Análise de Conformidade

### 7.1 Padrão ERC-20

Ambos os tokens ($DGOV e $DCHAT) implementam corretamente o padrão ERC-20 via herança do OpenZeppelin. O override de `_update()` no DGovToken para verificação de marketing locks é compatível com o padrão, pois apenas adiciona uma restrição de transferência (similar a tokens com blacklist). A função `burn()` do DChatStablecoin via `ERC20Burnable` está correta.

### 7.2 Proteção contra Reentrância

Todos os contratos utilizam `ReentrancyGuard` do OpenZeppelin nas funções que envolvem transferências externas. O padrão checks-effects-interactions é seguido na maioria das funções. A exceção parcial é `finalizeAuction()` que faz múltiplas transferências em loop, mas está protegida pelo `nonReentrant` modifier.

### 7.3 Overflow/Underflow

Solidity 0.8.24 fornece proteção nativa contra overflow e underflow. Não foram identificados cenários de underflow não protegido. Os cálculos de divisão usam denominadores constantes (`BPS_DENOMINATOR`, `PRECISION`), eliminando riscos de divisão por zero nos caminhos principais.

### 7.4 Controle de Acesso

O sistema usa `AccessControl` do OpenZeppelin com roles granulares (`DEFAULT_ADMIN_ROLE`, `AUCTION_MANAGER_ROLE`, `MINTER_ROLE`, `RELAYER_ROLE`). A separação de roles é adequada, mas o `RELAYER_ROLE` tem poder excessivo conforme F-10.

---

## 8. Matriz de Decisão — Correções Recomendadas

A tabela abaixo apresenta três abordagens para cada correção crítica e de alta severidade, conforme o protocolo de decisão do CEO:

| Finding | Abordagem A (Velocidade) | Abordagem B (Performance) | Abordagem C (Custo/Escala) |
|---|---|---|---|
| F-01/F-02 (DoS Sorting) | `MAX_BIDS = 500` com require simples. Deploy em 1h. | Sorting off-chain + Merkle proof on-chain. 3-5 dias. | Finalização em batches (chunks de 100). 2 dias. |
| F-09 (adminMint) | Remover `adminMint()` completamente. 30min. | Manter com cap de 100k DCHAT + timelock 48h. 2h. | Adicionar Pausable + monitoramento on-chain. 4h. |
| F-10 (Relayer) | Adicionar allowance máxima por período. 4h. | Meta-transactions EIP-712 com assinatura. 2-3 dias. | Manter design atual + multisig no relayer. 1h. |
| F-15 (Diluição) | Usar `getTotalDividendWeight()` do DGovToken. 1h. | Subtrair `balanceOf(dgov_address)` no cálculo. 2h. | Manter e documentar que dividendos não-claimed acumulam no pool. 0h. |
| F-19 (Arbitrary Call) | Whitelist de targets + selectors. 3h. | Governança modular com módulos de execução. 2-3 dias. | Adicionar veto do admin com timelock. 2h. |

---

## 9. Pontos Positivos

O protocolo demonstra maturidade arquitetural em diversos aspectos que merecem destaque. A separação da governança em contrato dedicado (`DGovGovernance`) é uma decisão acertada que facilita upgrades futuros sem afetar o token. O sistema de quorum baseado no total emitido (descontando queimas) é progressivamente mais acessível conforme os leilões acontecem, o que é um design inteligente. O padrão points-per-token no DividendPool é eficiente e evita loops custosos na distribuição. O mecanismo de anti-sniping protege contra manipulação de último segundo nos leilões. O vesting linear de marketing (180d lock + 180d linear) é um modelo equilibrado que alinha incentivos de longo prazo. O uso consistente de OpenZeppelin para roles, reentrancy guard e ERC-20 base elimina classes inteiras de vulnerabilidades. Os 148 testes passando cobrem os fluxos principais adequadamente.

---

## 10. Conclusão e Recomendação

O ecossistema de contratos do DecentraChat está **acima da média** para um projeto em fase de desenvolvimento, com arquitetura sólida e uso correto de bibliotecas auditadas. Porém, os findings críticos F-01 (DoS no leilão) e F-09 (mint sem colateral) devem ser corrigidos **obrigatoriamente** antes de qualquer deploy, mesmo em testnet, para evitar que padrões inseguros se propaguem para produção.

A recomendação é corrigir os findings de severidade **Crítica** e **Alta** (6 findings) antes do deploy em testnet Amoy, e os de severidade **Média** (8 findings) antes do deploy em mainnet Polygon. Os findings de severidade **Baixa** e **Informativos** podem ser endereçados em iterações futuras.

Após as correções, recomenda-se uma segunda rodada de auditoria focada nos patches aplicados, seguida de uma auditoria externa por uma firma especializada (Certik, OpenZeppelin, Trail of Bits) antes do launch em mainnet com fundos reais.

---

*Relatório gerado por The Architect — AGI-Core para DecentraChat Protocol. Todos os findings são baseados em análise estática do código-fonte e simulação de cenários de ataque. Uma auditoria formal por terceiros é recomendada antes do deploy em mainnet.*
