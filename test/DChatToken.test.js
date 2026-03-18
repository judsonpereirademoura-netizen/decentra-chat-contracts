const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("DChatToken", function () {
  let dchatToken, dchatStaking;
  let owner, founder, treasury, publicSale, airdrop, node1, node2, user1, user2;
  const TOTAL_SUPPLY = ethers.parseUnits("1000000000", 18); // 1 bilhão
  const COST_PER_BYTE = ethers.parseUnits("0.000001", 18);

  beforeEach(async function () {
    [owner, founder, treasury, publicSale, airdrop, node1, node2, user1, user2] =
      await ethers.getSigners();

    // Deploy DChatToken
    const DChatToken = await ethers.getContractFactory("DChatToken");
    dchatToken = await DChatToken.deploy(
      founder.address,
      treasury.address,
      owner.address, // staking pool temporário
      publicSale.address,
      airdrop.address,
      COST_PER_BYTE
    );
    await dchatToken.waitForDeployment();

    // Deploy DChatStaking
    const lockPeriod = 7 * 24 * 60 * 60; // 7 dias
    const DChatStaking = await ethers.getContractFactory("DChatStaking");
    dchatStaking = await DChatStaking.deploy(
      await dchatToken.getAddress(),
      lockPeriod
    );
    await dchatStaking.waitForDeployment();

    // Atualizar staking pool
    await dchatToken.setStakingPool(await dchatStaking.getAddress());

    // Registrar nodes
    await dchatToken.registerNode(node1.address);
    await dchatToken.registerNode(node2.address);

    // Transferir tokens para user1 e user2 para testes
    await dchatToken.connect(publicSale).transfer(
      user1.address,
      ethers.parseUnits("10000", 18)
    );
    await dchatToken.connect(publicSale).transfer(
      user2.address,
      ethers.parseUnits("10000", 18)
    );
  });

  describe("Deployment", function () {
    it("deve ter o nome e símbolo corretos", async function () {
      expect(await dchatToken.name()).to.equal("DecentraChat");
      expect(await dchatToken.symbol()).to.equal("DCHAT");
    });

    it("deve ter o supply total correto", async function () {
      expect(await dchatToken.TOTAL_SUPPLY()).to.equal(TOTAL_SUPPLY);
    });

    it("deve distribuir tokens corretamente na inicialização", async function () {
      const publicSaleExpected = (TOTAL_SUPPLY * 4000n) / 10000n; // 40%
      const treasuryExpected = (TOTAL_SUPPLY * 2500n) / 10000n;   // 25%
      const stakingExpected = (TOTAL_SUPPLY * 1000n) / 10000n;    // 10%
      const airdropExpected = (TOTAL_SUPPLY * 500n) / 10000n;     // 5%

      // Treasury deve ter recebido 25%
      expect(await dchatToken.balanceOf(treasury.address)).to.equal(treasuryExpected);

      // Airdrop deve ter recebido 5%
      expect(await dchatToken.balanceOf(airdrop.address)).to.equal(airdropExpected);
    });

    it("deve configurar o custo por byte corretamente", async function () {
      expect(await dchatToken.costPerByte()).to.equal(COST_PER_BYTE);
    });

    it("deve configurar multiplicadores de tipo de dado", async function () {
      expect(await dchatToken.dataTypeMultiplier(0)).to.equal(10000); // TEXT = 1.0x
      expect(await dchatToken.dataTypeMultiplier(1)).to.equal(12000); // IMAGE = 1.2x
      expect(await dchatToken.dataTypeMultiplier(3)).to.equal(20000); // VIDEO = 2.0x
    });
  });

  describe("Node Management", function () {
    it("deve registrar nodes corretamente", async function () {
      expect(await dchatToken.authorizedNodes(node1.address)).to.be.true;
      expect(await dchatToken.authorizedNodes(node2.address)).to.be.true;
      expect(await dchatToken.nodeCount()).to.equal(2);
    });

    it("deve impedir registro de node duplicado", async function () {
      await expect(
        dchatToken.registerNode(node1.address)
      ).to.be.revertedWith("DChatToken: node already registered");
    });

    it("deve remover node corretamente", async function () {
      await dchatToken.removeNode(node1.address);
      expect(await dchatToken.authorizedNodes(node1.address)).to.be.false;
      expect(await dchatToken.nodeCount()).to.equal(1);
    });

    it("deve impedir não-owner de registrar node", async function () {
      await expect(
        dchatToken.connect(user1).registerNode(user2.address)
      ).to.be.revertedWithCustomError(dchatToken, "OwnableUnauthorizedAccount");
    });
  });

  describe("Message Billing", function () {
    it("deve calcular custo de mensagem de texto corretamente", async function () {
      const byteSize = 1000; // 1KB
      const [totalCost, nodeFee, founderFee, stakingFee, burnAmount] =
        await dchatToken.calculateMessageCost(byteSize, 0); // TYPE_TEXT

      // Custo base = 1000 * 0.000001 * 1.0 = 0.001 DCHAT
      const expectedBase = ethers.parseUnits("0.001", 18);
      const expectedBurn = (expectedBase * 100n) / 10000n; // 1%
      const expectedTotal = expectedBase + expectedBurn;

      expect(totalCost).to.equal(expectedTotal);
      expect(nodeFee).to.equal((expectedBase * 7000n) / 10000n); // 70%
      expect(founderFee).to.equal((expectedBase * 2000n) / 10000n); // 20%
    });

    it("deve aplicar multiplicador para imagens", async function () {
      const byteSize = 1000;
      const [totalCostText] = await dchatToken.calculateMessageCost(byteSize, 0); // TEXT
      const [totalCostImage] = await dchatToken.calculateMessageCost(byteSize, 1); // IMAGE

      // Imagem deve custar 1.2x mais que texto
      expect(totalCostImage).to.be.gt(totalCostText);
    });

    it("deve processar mensagem e distribuir taxas corretamente", async function () {
      const byteSize = 1000;
      const [totalCost, nodeFee, founderFee, stakingFee, burnAmount] =
        await dchatToken.calculateMessageCost(byteSize, 0);

      const founderBalanceBefore = await dchatToken.balanceOf(founder.address);

      await dchatToken.connect(user1).processMessage(
        user2.address,
        byteSize,
        0, // TYPE_TEXT
        node1.address
      );

      // Verificar que o fundador recebeu sua taxa
      const founderBalanceAfter = await dchatToken.balanceOf(founder.address);
      expect(founderBalanceAfter - founderBalanceBefore).to.equal(founderFee);

      // Verificar que o node tem recompensas pendentes
      expect(await dchatToken.pendingNodeRewards(node1.address)).to.equal(nodeFee);

      // Verificar métricas
      expect(await dchatToken.totalBytesProcessed()).to.equal(byteSize);
      expect(await dchatToken.totalMessagesProcessed()).to.equal(1);
      expect(await dchatToken.totalBurned()).to.equal(burnAmount);
    });

    it("deve emitir evento MessageProcessed", async function () {
      await expect(
        dchatToken.connect(user1).processMessage(
          user2.address,
          500,
          0,
          node1.address
        )
      ).to.emit(dchatToken, "MessageProcessed");
    });

    it("deve rejeitar mensagem com saldo insuficiente", async function () {
      // Criar um usuário sem saldo
      const [, , , , , , , , , poorUser] = await ethers.getSigners();

      await expect(
        dchatToken.connect(poorUser).processMessage(
          user2.address,
          1000,
          0,
          node1.address
        )
      ).to.be.revertedWith("DChatToken: insufficient balance");
    });

    it("deve rejeitar mensagem para node não autorizado", async function () {
      await expect(
        dchatToken.connect(user1).processMessage(
          user2.address,
          1000,
          0,
          user2.address // não é node autorizado
        )
      ).to.be.revertedWith("DChatToken: relay node not authorized");
    });

    it("deve rejeitar mensagem para si mesmo", async function () {
      await expect(
        dchatToken.connect(user1).processMessage(
          user1.address,
          1000,
          0,
          node1.address
        )
      ).to.be.revertedWith("DChatToken: cannot message yourself");
    });
  });

  describe("Batch Processing", function () {
    it("deve processar múltiplas mensagens em batch", async function () {
      const recipients = [user2.address, user2.address];
      const byteSizes = [500, 1000];
      const dataTypes = [0, 1];
      const relayNodes = [node1.address, node2.address];

      await dchatToken.connect(user1).processMessageBatch(
        recipients,
        byteSizes,
        dataTypes,
        relayNodes
      );

      expect(await dchatToken.totalMessagesProcessed()).to.equal(2);
      expect(await dchatToken.totalBytesProcessed()).to.equal(1500);
    });
  });

  describe("Node Rewards", function () {
    it("deve permitir que node resgate recompensas", async function () {
      // Processar mensagem para gerar recompensas
      await dchatToken.connect(user1).processMessage(
        user2.address,
        1000,
        0,
        node1.address
      );

      const pendingRewards = await dchatToken.pendingNodeRewards(node1.address);
      expect(pendingRewards).to.be.gt(0);

      // Node resgata recompensas
      const balanceBefore = await dchatToken.balanceOf(node1.address);
      await dchatToken.connect(node1).claimNodeRewards();
      const balanceAfter = await dchatToken.balanceOf(node1.address);

      expect(balanceAfter - balanceBefore).to.equal(pendingRewards);
      expect(await dchatToken.pendingNodeRewards(node1.address)).to.equal(0);
    });
  });

  describe("Founder Vesting", function () {
    it("deve liberar tokens linearmente ao longo de 2 anos", async function () {
      // Avançar 1 ano (metade do vesting)
      await time.increase(365 * 24 * 60 * 60);

      const available = await dchatToken.founderVestingAvailable();
      const founderTotal = await dchatToken.founderTotalVesting();

      // Deve ter ~50% disponível (com margem para arredondamento)
      const halfVesting = founderTotal / 2n;
      const tolerance = ethers.parseUnits("1000", 18); // 1000 DCHAT de tolerância

      expect(available).to.be.closeTo(halfVesting, tolerance);
    });

    it("deve permitir claim de tokens vested", async function () {
      await time.increase(365 * 24 * 60 * 60); // 1 ano

      const available = await dchatToken.founderVestingAvailable();
      await dchatToken.connect(founder).claimFounderVesting();

      // O claimed pode ser ligeiramente maior que 'available' calculado antes do tx
      // porque o bloco avança entre a leitura e a execução
      const claimed = await dchatToken.founderTokensClaimed();
      const tolerance = ethers.parseUnits("100", 18);
      expect(claimed).to.be.closeTo(available, tolerance);
    });

    it("deve liberar 100% após 2 anos", async function () {
      await time.increase(730 * 24 * 60 * 60); // 2 anos

      const available = await dchatToken.founderVestingAvailable();
      const founderTotal = await dchatToken.founderTotalVesting();

      expect(available).to.equal(founderTotal);
    });
  });

  describe("Governance", function () {
    it("deve permitir owner atualizar custo por byte", async function () {
      const newCost = ethers.parseUnits("0.000002", 18);
      await dchatToken.setCostPerByte(newCost);
      expect(await dchatToken.costPerByte()).to.equal(newCost);
    });

    it("deve permitir owner atualizar multiplicador", async function () {
      await dchatToken.setDataTypeMultiplier(0, 15000); // TEXT = 1.5x
      expect(await dchatToken.dataTypeMultiplier(0)).to.equal(15000);
    });

    it("deve permitir toggle de emergency mode", async function () {
      await dchatToken.toggleEmergencyMode();
      expect(await dchatToken.emergencyMode()).to.be.true;

      // Mensagens devem ser bloqueadas em emergency mode
      await expect(
        dchatToken.connect(user1).processMessage(
          user2.address,
          1000,
          0,
          node1.address
        )
      ).to.be.revertedWith("DChatToken: emergency mode active");
    });
  });

  describe("Network Stats", function () {
    it("deve retornar métricas corretas após processamento", async function () {
      await dchatToken.connect(user1).processMessage(
        user2.address,
        2000,
        0,
        node1.address
      );

      const stats = await dchatToken.getNetworkStats();
      expect(stats._totalBytesProcessed).to.equal(2000);
      expect(stats._totalMessagesProcessed).to.equal(1);
      expect(stats._totalBurned).to.be.gt(0);
      expect(stats._nodeCount).to.equal(2);
    });
  });
});

describe("DChatStaking", function () {
  let dchatToken, dchatStaking;
  let owner, founder, treasury, publicSale, airdrop, user1, user2;
  const COST_PER_BYTE = ethers.parseUnits("0.000001", 18);
  const LOCK_PERIOD = 7 * 24 * 60 * 60; // 7 dias

  beforeEach(async function () {
    [owner, founder, treasury, publicSale, airdrop, , , user1, user2] =
      await ethers.getSigners();

    const DChatToken = await ethers.getContractFactory("DChatToken");
    dchatToken = await DChatToken.deploy(
      founder.address,
      treasury.address,
      owner.address,
      publicSale.address,
      airdrop.address,
      COST_PER_BYTE
    );
    await dchatToken.waitForDeployment();

    const DChatStaking = await ethers.getContractFactory("DChatStaking");
    dchatStaking = await DChatStaking.deploy(
      await dchatToken.getAddress(),
      LOCK_PERIOD
    );
    await dchatStaking.waitForDeployment();

    // Transferir tokens para users
    await dchatToken.connect(publicSale).transfer(
      user1.address,
      ethers.parseUnits("100000", 18)
    );
    await dchatToken.connect(publicSale).transfer(
      user2.address,
      ethers.parseUnits("100000", 18)
    );
  });

  describe("Staking", function () {
    it("deve permitir stake de tokens", async function () {
      const amount = ethers.parseUnits("1000", 18);
      await dchatToken.connect(user1).approve(
        await dchatStaking.getAddress(),
        amount
      );
      await dchatStaking.connect(user1).stake(amount);

      expect(await dchatStaking.totalStaked()).to.equal(amount);
      const info = await dchatStaking.getStakeInfo(user1.address);
      expect(info.stakedAmount).to.equal(amount);
    });

    it("deve impedir unstake durante lock period", async function () {
      const amount = ethers.parseUnits("1000", 18);
      await dchatToken.connect(user1).approve(
        await dchatStaking.getAddress(),
        amount
      );
      await dchatStaking.connect(user1).stake(amount);

      await expect(
        dchatStaking.connect(user1).unstake(amount)
      ).to.be.revertedWith("DChatStaking: lock period not expired");
    });

    it("deve permitir unstake após lock period", async function () {
      const amount = ethers.parseUnits("1000", 18);
      await dchatToken.connect(user1).approve(
        await dchatStaking.getAddress(),
        amount
      );
      await dchatStaking.connect(user1).stake(amount);

      // Avançar 7 dias
      await time.increase(LOCK_PERIOD + 1);

      const balanceBefore = await dchatToken.balanceOf(user1.address);
      await dchatStaking.connect(user1).unstake(amount);
      const balanceAfter = await dchatToken.balanceOf(user1.address);

      expect(balanceAfter - balanceBefore).to.equal(amount);
      expect(await dchatStaking.totalStaked()).to.equal(0);
    });
  });

  describe("Rewards", function () {
    it("deve distribuir recompensas proporcionalmente", async function () {
      const stakeAmount = ethers.parseUnits("1000", 18);
      const rewardAmount = ethers.parseUnits("100", 18);

      // User1 faz stake
      await dchatToken.connect(user1).approve(
        await dchatStaking.getAddress(),
        stakeAmount
      );
      await dchatStaking.connect(user1).stake(stakeAmount);

      // Depositar recompensas
      await dchatToken.connect(publicSale).approve(
        await dchatStaking.getAddress(),
        rewardAmount
      );
      await dchatStaking.connect(publicSale).depositRewards(rewardAmount);

      // Verificar recompensas pendentes
      const info = await dchatStaking.getStakeInfo(user1.address);
      expect(info.pendingRewards).to.be.gt(0);
    });
  });
});

describe("Security Fixes", function () {
  let dchatToken, dchatStaking;
  let owner, founder, treasury, publicSale, airdrop, node1, node2, user1, user2;
  const COST_PER_BYTE = ethers.parseUnits("0.000001", 18);
  const LOCK_PERIOD = 7 * 24 * 60 * 60; // 7 dias

  beforeEach(async function () {
    [owner, founder, treasury, publicSale, airdrop, node1, node2, user1, user2] =
      await ethers.getSigners();

    const DChatToken = await ethers.getContractFactory("DChatToken");
    dchatToken = await DChatToken.deploy(
      founder.address,
      treasury.address,
      owner.address,
      publicSale.address,
      airdrop.address,
      COST_PER_BYTE
    );
    await dchatToken.waitForDeployment();

    const DChatStaking = await ethers.getContractFactory("DChatStaking");
    dchatStaking = await DChatStaking.deploy(
      await dchatToken.getAddress(),
      LOCK_PERIOD
    );
    await dchatStaking.waitForDeployment();

    await dchatToken.setStakingPool(await dchatStaking.getAddress());
    await dchatToken.registerNode(node1.address);
    await dchatToken.registerNode(node2.address);

    await dchatToken.connect(publicSale).transfer(
      user1.address,
      ethers.parseUnits("100000", 18)
    );
    await dchatToken.connect(publicSale).transfer(
      user2.address,
      ethers.parseUnits("100000", 18)
    );
  });

  describe("FIX M-01: Staking Lock Period Weighted Average", function () {
    it("deve usar média ponderada ao adicionar stake existente", async function () {
      const amount1 = ethers.parseUnits("1000", 18);
      const amount2 = ethers.parseUnits("100", 18);
      const stakingAddr = await dchatStaking.getAddress();

      // Primeiro stake
      await dchatToken.connect(user1).approve(stakingAddr, amount1 + amount2);
      await dchatStaking.connect(user1).stake(amount1);

      const info1 = await dchatStaking.getStakeInfo(user1.address);
      const firstTimestamp = info1.stakeTimestamp;

      // Avançar 6 dias (quase desbloqueado)
      await time.increase(6 * 24 * 60 * 60);

      // Segundo stake (pequeno)
      await dchatStaking.connect(user1).stake(amount2);

      const info2 = await dchatStaking.getStakeInfo(user1.address);
      const newTimestamp = info2.stakeTimestamp;

      // O novo timestamp deve ser uma média ponderada, NÃO block.timestamp
      // Deve estar entre o primeiro timestamp e o block.timestamp atual
      const latestBlock = await time.latest();
      expect(newTimestamp).to.be.gt(firstTimestamp);
      expect(newTimestamp).to.be.lt(BigInt(latestBlock));

      // O timestamp deve estar mais próximo do primeiro (pois amount1 >> amount2)
      const distFromFirst = newTimestamp - firstTimestamp;
      const distFromLatest = BigInt(latestBlock) - newTimestamp;
      expect(distFromLatest).to.be.gt(distFromFirst); // Mais próximo do primeiro
    });

    it("deve usar block.timestamp para primeiro stake", async function () {
      const amount = ethers.parseUnits("1000", 18);
      const stakingAddr = await dchatStaking.getAddress();

      await dchatToken.connect(user1).approve(stakingAddr, amount);
      await dchatStaking.connect(user1).stake(amount);

      const info = await dchatStaking.getStakeInfo(user1.address);
      const latestBlock = await time.latest();

      // Primeiro stake deve usar block.timestamp exato
      expect(info.stakeTimestamp).to.equal(BigInt(latestBlock));
    });

    it("deve permitir unstake mais cedo com média ponderada vs reset total", async function () {
      const amount1 = ethers.parseUnits("1000", 18);
      const amount2 = ethers.parseUnits("1", 18); // Muito pequeno
      const stakingAddr = await dchatStaking.getAddress();

      await dchatToken.connect(user1).approve(stakingAddr, amount1 + amount2);
      await dchatStaking.connect(user1).stake(amount1);

      // Avançar 6.5 dias
      await time.increase(6 * 24 * 60 * 60 + 12 * 60 * 60);

      // Adicionar stake mínimo
      await dchatStaking.connect(user1).stake(amount2);

      // Avançar mais 1 dia (total ~7.5 dias desde primeiro stake)
      await time.increase(1 * 24 * 60 * 60);

      // Com média ponderada, o lock efetivo deve ter expirado
      // (pois o segundo stake é insignificante comparado ao primeiro)
      const totalAmount = amount1 + amount2;
      await expect(
        dchatStaking.connect(user1).unstake(totalAmount)
      ).to.not.be.reverted;
    });
  });

  describe("FIX M-02: Removed Node Rewards Recovery", function () {
    it("deve permitir owner resgatar recompensas de node removido", async function () {
      // Processar mensagem para gerar recompensas para node1
      await dchatToken.connect(user1).processMessage(
        user2.address,
        1000,
        0,
        node1.address
      );

      const pendingRewards = await dchatToken.pendingNodeRewards(node1.address);
      expect(pendingRewards).to.be.gt(0);

      // Remover o node
      await dchatToken.removeNode(node1.address);
      expect(await dchatToken.authorizedNodes(node1.address)).to.be.false;

      // Node removido NÃO pode resgatar diretamente
      await expect(
        dchatToken.connect(node1).claimNodeRewards()
      ).to.be.revertedWith("DChatToken: not an authorized node");

      // Owner pode resgatar para o node removido
      const balanceBefore = await dchatToken.balanceOf(node1.address);
      await dchatToken.claimRewardsForRemovedNode(node1.address);
      const balanceAfter = await dchatToken.balanceOf(node1.address);

      expect(balanceAfter - balanceBefore).to.equal(pendingRewards);
      expect(await dchatToken.pendingNodeRewards(node1.address)).to.equal(0);
    });

    it("deve emitir evento RemovedNodeRewardClaimed", async function () {
      await dchatToken.connect(user1).processMessage(
        user2.address,
        1000,
        0,
        node1.address
      );

      await dchatToken.removeNode(node1.address);

      await expect(
        dchatToken.claimRewardsForRemovedNode(node1.address)
      ).to.emit(dchatToken, "RemovedNodeRewardClaimed");
    });

    it("deve rejeitar se node ainda está ativo", async function () {
      await dchatToken.connect(user1).processMessage(
        user2.address,
        1000,
        0,
        node1.address
      );

      await expect(
        dchatToken.claimRewardsForRemovedNode(node1.address)
      ).to.be.revertedWith("DChatToken: node still active, use claimNodeRewards");
    });

    it("deve rejeitar se não há recompensas pendentes", async function () {
      await dchatToken.removeNode(node1.address);

      await expect(
        dchatToken.claimRewardsForRemovedNode(node1.address)
      ).to.be.revertedWith("DChatToken: no pending rewards for this node");
    });
  });

  describe("FIX L-01: Max Cost Per Byte Limit", function () {
    it("deve rejeitar costPerByte acima do limite máximo", async function () {
      const tooHigh = ethers.parseUnits("1", 18); // 1e18 > MAX_COST_PER_BYTE (1e15)

      await expect(
        dchatToken.setCostPerByte(tooHigh)
      ).to.be.revertedWith("DChatToken: cost must be > 0 and <= MAX_COST_PER_BYTE");
    });

    it("deve aceitar costPerByte dentro do limite", async function () {
      const validCost = ethers.parseUnits("0.001", 18); // 1e15 = MAX_COST_PER_BYTE

      await dchatToken.setCostPerByte(validCost);
      expect(await dchatToken.costPerByte()).to.equal(validCost);
    });

    it("deve rejeitar costPerByte zero", async function () {
      await expect(
        dchatToken.setCostPerByte(0)
      ).to.be.revertedWith("DChatToken: cost must be > 0 and <= MAX_COST_PER_BYTE");
    });
  });

  describe("FIX L-02: Batch Node Registration Limit", function () {
    it("deve rejeitar batch com mais de 100 nodes", async function () {
      // Gerar 101 endereços
      const nodes = [];
      for (let i = 0; i < 101; i++) {
        nodes.push(ethers.Wallet.createRandom().address);
      }

      await expect(
        dchatToken.registerNodeBatch(nodes)
      ).to.be.revertedWith("DChatToken: batch too large, max 100 nodes");
    });

    it("deve aceitar batch com exatamente 100 nodes", async function () {
      const nodes = [];
      for (let i = 0; i < 100; i++) {
        nodes.push(ethers.Wallet.createRandom().address);
      }

      await dchatToken.registerNodeBatch(nodes);
      // nodeCount = 2 (iniciais) + 100 (batch) = 102
      expect(await dchatToken.nodeCount()).to.equal(102);
    });
  });
});
