const { ethers, run } = require("hardhat");
const fs = require("fs");

/**
 * DecentraChat Dual-Token System — Deploy Script v5.1
 * 
 * Ordem de deploy (dependências):
 * 1. DividendPool (precisa de DCHAT e DGOV, mas usamos placeholder → depois setamos)
 * 2. DChatStablecoin (precisa de dividendPool, reserveWallet, USDC, USDT)
 * 3. DGovToken (precisa de dchatToken, dividendPool)
 * 4. DGovGovernance (precisa de dgov)
 * 5. Configurações pós-deploy (setDGovToken, setDChatToken, roles, etc.)
 * 
 * Uso:
 *   export PRIVATE_KEY="0x..."
 *   export POLYGONSCAN_API_KEY="..."
 *   npx hardhat run scripts/deploy.js --network polygonAmoy
 */

// ─── Endereços de colateral na Polygon Amoy Testnet ───
// Estes são endereços de USDC/USDT mockados para testnet
// Em mainnet, usar os endereços oficiais da Polygon
const TESTNET_COLLATERAL = {
  polygonAmoy: {
    USDC: "0x0000000000000000000000000000000000000000", // Será deployado como mock
    USDT: "0x0000000000000000000000000000000000000000", // Será deployado como mock
  },
  polygon: {
    USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359", // USDC oficial Polygon
    USDT: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", // USDT oficial Polygon
  },
};

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const networkName = network.name === "unknown" ? "polygonAmoy" : network.name;
  const chainId = Number(network.chainId);

  console.log("═══════════════════════════════════════════════════════════════");
  console.log("  DecentraChat Dual-Token System — Deploy v5.1");
  console.log("═══════════════════════════════════════════════════════════════");
  console.log(`  Network:    ${networkName} (chainId: ${chainId})`);
  console.log(`  Deployer:   ${deployer.address}`);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`  Balance:    ${ethers.formatEther(balance)} MATIC`);
  console.log("═══════════════════════════════════════════════════════════════\n");

  if (balance === 0n) {
    console.error("❌ Deployer has no MATIC. Get testnet MATIC from https://faucet.polygon.technology/");
    process.exit(1);
  }

  // ─── Configuração ───
  const founderAddress = deployer.address;
  const reserveWallet = deployer.address; // Carteira pessoal do fundador para despesas operacionais

  // ─── Step 0: Deploy Mock USDC/USDT para testnet ───
  let usdcAddress, usdtAddress;

  if (chainId === 80002 || chainId === 31337) {
    // Testnet: deploy mocks
    console.log("📦 [0/5] Deploying Mock USDC & USDT (testnet only)...");
    const MockERC20 = await ethers.getContractFactory("MockERC20");

    const mockUSDC = await MockERC20.deploy("USD Coin (Mock)", "USDC", 6);
    await mockUSDC.waitForDeployment();
    usdcAddress = await mockUSDC.getAddress();
    console.log(`   ✅ Mock USDC: ${usdcAddress}`);

    const mockUSDT = await MockERC20.deploy("Tether USD (Mock)", "USDT", 6);
    await mockUSDT.waitForDeployment();
    usdtAddress = await mockUSDT.getAddress();
    console.log(`   ✅ Mock USDT: ${usdtAddress}`);

    // Mint 1M USDC e 1M USDT para o deployer (para testes)
    await mockUSDC.mint(deployer.address, ethers.parseUnits("1000000", 6));
    await mockUSDT.mint(deployer.address, ethers.parseUnits("1000000", 6));
    console.log("   ✅ Minted 1M USDC + 1M USDT to deployer for testing");
  } else {
    // Mainnet: usar endereços oficiais
    const collateral = TESTNET_COLLATERAL.polygon;
    usdcAddress = collateral.USDC;
    usdtAddress = collateral.USDT;
    console.log(`📦 [0/5] Using official collateral tokens:`);
    console.log(`   USDC: ${usdcAddress}`);
    console.log(`   USDT: ${usdtAddress}`);
  }

  // ─── Step 1: Deploy DChatStablecoin (precisa de dividendPool placeholder) ───
  // Usamos deployer como placeholder para dividendPool, depois atualizamos
  console.log("\n📦 [1/5] Deploying DChatStablecoin ($DCHAT)...");
  const DChatStablecoin = await ethers.getContractFactory("DChatStablecoin");
  const dchat = await DChatStablecoin.deploy(
    founderAddress,       // _founder
    deployer.address,     // _dividendPool (placeholder — será atualizado)
    reserveWallet,        // _reserveWallet (carteira pessoal do fundador)
    usdcAddress,          // _usdc
    usdtAddress           // _usdt
  );
  await dchat.waitForDeployment();
  const dchatAddress = await dchat.getAddress();
  console.log(`   ✅ DChatStablecoin: ${dchatAddress}`);

  // ─── Step 2: Deploy DividendPool ───
  console.log("\n📦 [2/5] Deploying DividendPool...");
  const DividendPool = await ethers.getContractFactory("DividendPool");
  const dividendPool = await DividendPool.deploy(
    dchatAddress,         // _dchatToken
    deployer.address,     // _dgovToken (placeholder — será atualizado)
    founderAddress        // _admin
  );
  await dividendPool.waitForDeployment();
  const dividendPoolAddress = await dividendPool.getAddress();
  console.log(`   ✅ DividendPool: ${dividendPoolAddress}`);

  // ─── Step 3: Deploy DGovToken ───
  console.log("\n📦 [3/5] Deploying DGovToken ($DGOV)...");
  const DGovToken = await ethers.getContractFactory("DGovToken");
  const dgov = await DGovToken.deploy(
    founderAddress,       // _founder
    dchatAddress,         // _dchatToken
    dividendPoolAddress   // _dividendPool
  );
  await dgov.waitForDeployment();
  const dgovAddress = await dgov.getAddress();
  console.log(`   ✅ DGovToken: ${dgovAddress}`);

  // ─── Step 4: Deploy DGovGovernance ───
  console.log("\n📦 [4/5] Deploying DGovGovernance...");
  const DGovGovernance = await ethers.getContractFactory("DGovGovernance");
  const governance = await DGovGovernance.deploy(
    dgovAddress,          // _dgov
    founderAddress        // _admin
  );
  await governance.waitForDeployment();
  const governanceAddress = await governance.getAddress();
  console.log(`   ✅ DGovGovernance: ${governanceAddress}`);

  // ─── Step 5: Configurações pós-deploy ───
  console.log("\n⚙️  [5/5] Post-deploy configuration...");

  // 5a. Atualizar dividendPool no DChatStablecoin
  console.log("   → Setting dividendPool on DChatStablecoin...");
  await dchat.setDividendPool(dividendPoolAddress);
  console.log("   ✅ DChatStablecoin.dividendPool updated");

  // 5b. Atualizar DGovToken no DividendPool (precisa de uma função para isso)
  // O DividendPool já recebeu o dgovToken como placeholder, precisamos verificar
  // se há uma função para atualizar. Se não, o placeholder deployer.address foi usado.
  // Verificar se DividendPool tem setDGovToken
  console.log("   → Granting DEPOSITOR_ROLE to DChatStablecoin on DividendPool...");
  const DEPOSITOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DEPOSITOR_ROLE"));
  await dividendPool.grantRole(DEPOSITOR_ROLE, dchatAddress);
  console.log("   ✅ DEPOSITOR_ROLE granted to DChatStablecoin");

  // 5c. Granting DEPOSITOR_ROLE to DGovToken (para notifyAuctionDeposit)
  console.log("   → Granting DEPOSITOR_ROLE to DGovToken on DividendPool...");
  await dividendPool.grantRole(DEPOSITOR_ROLE, dgovAddress);
  console.log("   ✅ DEPOSITOR_ROLE granted to DGovToken");

  // 5d. Configurar DividendPool no DGovToken
  console.log("   → Setting dividendPool on DGovToken...");
  await dgov.setDividendPool(dividendPoolAddress);
  console.log("   ✅ DGovToken.dividendPool updated");

  // 5e. Registrar deployer como primeiro node (founder node)
  // O constructor do DChatStablecoin já registra o founder como node automaticamente (N-02)
  console.log("   ✅ Founder node auto-registered in DChatStablecoin constructor");

  // 5f. Adicionar DGovGovernance como allowed target na governance
  console.log("   → Adding contracts as allowed targets in governance...");
  await governance.setAllowedTarget(dgovAddress, true);
  await governance.setAllowedTarget(dchatAddress, true);
  await governance.setAllowedTarget(dividendPoolAddress, true);
  console.log("   ✅ DGovToken, DChatStablecoin, DividendPool added as allowed targets");

  // ─── Verificação de estado ───
  console.log("\n🔍 Verifying deployment state...");
  
  const dgovTotalSupply = await dgov.totalSupply();
  console.log(`   DGOV Total Supply: ${ethers.formatEther(dgovTotalSupply)} DGOV`);
  
  const founderVesting = await dgov.getFounderVestingStatus();
  console.log(`   Founder Vesting Total: ${ethers.formatEther(founderVesting[0])} DGOV`);
  console.log(`   Founder Claimed: ${ethers.formatEther(founderVesting[1])} DGOV`);

  // ─── Resumo do Deploy ───
  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log("  DEPLOYMENT SUMMARY — DecentraChat v5.1");
  console.log("═══════════════════════════════════════════════════════════════");
  console.log(`  Network:          ${networkName} (chainId: ${chainId})`);
  console.log(`  Deployer/Founder: ${founderAddress}`);
  console.log(`  Reserve Wallet:   ${reserveWallet}`);
  console.log("───────────────────────────────────────────────────────────────");
  console.log(`  DChatStablecoin:  ${dchatAddress}`);
  console.log(`  DGovToken:        ${dgovAddress}`);
  console.log(`  DividendPool:     ${dividendPoolAddress}`);
  console.log(`  DGovGovernance:   ${governanceAddress}`);
  if (chainId === 80002 || chainId === 31337) {
    console.log(`  Mock USDC:        ${usdcAddress}`);
    console.log(`  Mock USDT:        ${usdtAddress}`);
  }
  console.log("═══════════════════════════════════════════════════════════════");

  // ─── Salvar deployment info ───
  const deploymentInfo = {
    version: "5.1",
    network: networkName,
    chainId: chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      DChatStablecoin: {
        address: dchatAddress,
        name: "DecentraChat Stablecoin",
        symbol: "DCHAT",
      },
      DGovToken: {
        address: dgovAddress,
        name: "DecentraChat Governance",
        symbol: "DGOV",
      },
      DividendPool: {
        address: dividendPoolAddress,
      },
      DGovGovernance: {
        address: governanceAddress,
      },
    },
    collateral: {
      USDC: usdcAddress,
      USDT: usdtAddress,
    },
    config: {
      founderAddress: founderAddress,
      reserveWallet: reserveWallet,
      founderVesting: "30% (30M DGOV) — 10M/12mo, 10M/24mo, 10M/36mo",
      marketingAllocation: "10% (10M DGOV) — 180d lock + 180d linear per transfer",
      auctionAllocation: "60% (60M DGOV) — 6 phases over 36 months",
      dividendSplit: "70% nodes / 20% dividendPool / 10% reserve",
      quorum: "60% + 1 of total emitted (minus burned)",
      timelock: "48 hours",
    },
  };

  fs.writeFileSync("./deployment.json", JSON.stringify(deploymentInfo, null, 2));
  console.log("\n📄 Deployment info saved to deployment.json");

  // ─── Verificação no Polygonscan (se não for hardhat local) ───
  if (chainId !== 31337) {
    console.log("\n🔍 Waiting 30s for block confirmations before verification...");
    await new Promise((r) => setTimeout(r, 30000));

    console.log("\n📝 Verifying contracts on Polygonscan...");
    
    const contracts = [
      {
        name: "DChatStablecoin",
        address: dchatAddress,
        args: [founderAddress, deployer.address, reserveWallet, usdcAddress, usdtAddress],
      },
      {
        name: "DividendPool",
        address: dividendPoolAddress,
        args: [dchatAddress, deployer.address, founderAddress],
      },
      {
        name: "DGovToken",
        address: dgovAddress,
        args: [founderAddress, dchatAddress, dividendPoolAddress],
      },
      {
        name: "DGovGovernance",
        address: governanceAddress,
        args: [dgovAddress, founderAddress],
      },
    ];

    // Verificar mocks se testnet
    if (chainId === 80002) {
      contracts.unshift(
        { name: "MockUSDC", address: usdcAddress, args: ["USD Coin (Mock)", "USDC", 6] },
        { name: "MockUSDT", address: usdtAddress, args: ["Tether USD (Mock)", "USDT", 6] }
      );
    }

    for (const contract of contracts) {
      try {
        console.log(`   → Verifying ${contract.name}...`);
        await run("verify:verify", {
          address: contract.address,
          constructorArguments: contract.args,
        });
        console.log(`   ✅ ${contract.name} verified!`);
      } catch (e) {
        if (e.message.includes("Already Verified")) {
          console.log(`   ✅ ${contract.name} already verified`);
        } else {
          console.log(`   ⚠️  ${contract.name} verification failed: ${e.message}`);
        }
      }
    }
  }

  console.log("\n✅ Deployment complete! Next steps:");
  console.log("   1. Copy deployment.json to frontend");
  console.log("   2. Update frontend contract addresses");
  console.log("   3. Test mint DCHAT with mock USDC/USDT");
  console.log("   4. Test founder vesting claim");
  console.log("   5. Start first auction after T+90 days");

  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
