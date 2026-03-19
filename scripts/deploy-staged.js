const { ethers, run } = require("hardhat");
const fs = require("fs");

/**
 * DecentraChat Dual-Token System — Staged Deploy Script v5.2
 * 
 * Deploy em etapas com checkpoint entre cada contrato.
 * Se o deploy falhar no meio, pode ser retomado a partir do último checkpoint.
 * 
 * Uso:
 *   # Deploy completo (todas as etapas):
 *   PRIVATE_KEY="0x..." npx hardhat run scripts/deploy-staged.js --network polygonAmoy
 * 
 *   # Retomar a partir de uma etapa específica:
 *   PRIVATE_KEY="0x..." RESUME_FROM=3 npx hardhat run scripts/deploy-staged.js --network polygonAmoy
 * 
 *   # Mainnet:
 *   PRIVATE_KEY="0x..." npx hardhat run scripts/deploy-staged.js --network polygonMainnet
 */

// ─── Endereços oficiais de colateral ───
const COLLATERAL = {
  31337: { // Hardhat local
    USDC: null, // Deploy mock
    USDT: null, // Deploy mock
  },
  80002: { // Polygon Amoy Testnet
    USDC: null, // Deploy mock
    USDT: null, // Deploy mock
  },
  137: { // Polygon Mainnet
    USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
    USDT: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
  },
};

const CHECKPOINT_FILE = "./deploy-checkpoint.json";

function loadCheckpoint() {
  try {
    if (fs.existsSync(CHECKPOINT_FILE)) {
      return JSON.parse(fs.readFileSync(CHECKPOINT_FILE, "utf8"));
    }
  } catch (e) {
    console.log("⚠️  Could not load checkpoint, starting fresh");
  }
  return { stage: 0, addresses: {} };
}

function saveCheckpoint(stage, addresses) {
  const checkpoint = { stage, addresses, timestamp: new Date().toISOString() };
  fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify(checkpoint, null, 2));
  console.log(`   💾 Checkpoint saved (stage ${stage})`);
}

async function estimateAndDeploy(factory, args, name) {
  console.log(`   → Estimating gas for ${name}...`);
  const deployTx = await factory.getDeployTransaction(...args);
  const estimatedGas = await ethers.provider.estimateGas(deployTx);
  const feeData = await ethers.provider.getFeeData();
  const gasPrice = feeData.gasPrice || ethers.parseUnits("30", "gwei");
  const estimatedCost = estimatedGas * gasPrice;
  console.log(`   → Gas estimate: ${estimatedGas.toString()} units (~${ethers.formatEther(estimatedCost)} POL)`);
  
  console.log(`   → Deploying ${name}...`);
  const contract = await factory.deploy(...args, {
    gasLimit: estimatedGas * 120n / 100n, // 20% buffer
  });
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`   ✅ ${name}: ${address}`);
  return { contract, address };
}

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const chainId = Number(network.chainId);
  const networkName = chainId === 31337 ? "hardhat" : chainId === 80002 ? "polygonAmoy" : "polygonMainnet";

  console.log("═══════════════════════════════════════════════════════════════");
  console.log("  DecentraChat Dual-Token System — Staged Deploy v5.2");
  console.log("═══════════════════════════════════════════════════════════════");
  console.log(`  Network:    ${networkName} (chainId: ${chainId})`);
  console.log(`  Deployer:   ${deployer.address}`);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`  Balance:    ${ethers.formatEther(balance)} POL`);
  console.log("═══════════════════════════════════════════════════════════════\n");

  if (balance === 0n) {
    console.error("❌ Deployer has no POL. Get testnet POL from faucet.");
    process.exit(1);
  }

  // ─── Load checkpoint or resume ───
  const resumeFrom = parseInt(process.env.RESUME_FROM || "0");
  let checkpoint = resumeFrom > 0 ? loadCheckpoint() : { stage: 0, addresses: {} };
  const startStage = resumeFrom > 0 ? resumeFrom : checkpoint.stage + 1;
  
  if (startStage > 1) {
    console.log(`📋 Resuming from stage ${startStage} (checkpoint loaded)`);
    console.log(`   Known addresses: ${JSON.stringify(checkpoint.addresses, null, 2)}\n`);
  }

  const founderAddress = deployer.address;
  const reserveWallet = deployer.address;
  const collateral = COLLATERAL[chainId];
  
  if (!collateral) {
    console.error(`❌ Unsupported chainId: ${chainId}`);
    process.exit(1);
  }

  let usdcAddress = checkpoint.addresses.mockUSDC;
  let usdtAddress = checkpoint.addresses.mockUSDT;
  let dchatAddress = checkpoint.addresses.dchat;
  let dividendPoolAddress = checkpoint.addresses.dividendPool;
  let dgovAddress = checkpoint.addresses.dgov;
  let governanceAddress = checkpoint.addresses.governance;

  // ═══════════════════════════════════════════════════════════
  // STAGE 1: Deploy Mock USDC/USDT (testnet only) or use official
  // ═══════════════════════════════════════════════════════════
  if (startStage <= 1) {
    if (collateral.USDC === null) {
      console.log("📦 [Stage 1/6] Deploying Mock USDC & USDT...");
      const MockERC20 = await ethers.getContractFactory("MockERC20");
      
      const { address: _usdc } = await estimateAndDeploy(
        MockERC20, ["USD Coin (Mock)", "USDC", 6], "MockUSDC"
      );
      usdcAddress = _usdc;

      const { address: _usdt } = await estimateAndDeploy(
        MockERC20, ["Tether USD (Mock)", "USDT", 6], "MockUSDT"
      );
      usdtAddress = _usdt;

      // Mint test tokens
      const mockUSDC = await ethers.getContractAt("MockERC20", usdcAddress);
      const mockUSDT = await ethers.getContractAt("MockERC20", usdtAddress);
      await mockUSDC.mint(deployer.address, ethers.parseUnits("1000000", 6));
      await mockUSDT.mint(deployer.address, ethers.parseUnits("1000000", 6));
      console.log("   ✅ Minted 1M USDC + 1M USDT to deployer\n");
    } else {
      console.log("📦 [Stage 1/6] Using official collateral tokens...");
      usdcAddress = collateral.USDC;
      usdtAddress = collateral.USDT;
      console.log(`   USDC: ${usdcAddress}`);
      console.log(`   USDT: ${usdtAddress}\n`);
    }
    checkpoint.addresses.mockUSDC = usdcAddress;
    checkpoint.addresses.mockUSDT = usdtAddress;
    saveCheckpoint(1, checkpoint.addresses);
  }

  // ═══════════════════════════════════════════════════════════
  // STAGE 2: Deploy DChatStablecoin
  // ═══════════════════════════════════════════════════════════
  if (startStage <= 2) {
    console.log("📦 [Stage 2/6] Deploying DChatStablecoin ($DCHAT)...");
    const DChatStablecoin = await ethers.getContractFactory("DChatStablecoin");
    const { address } = await estimateAndDeploy(
      DChatStablecoin,
      [founderAddress, deployer.address, reserveWallet, usdcAddress, usdtAddress],
      "DChatStablecoin"
    );
    dchatAddress = address;
    checkpoint.addresses.dchat = dchatAddress;
    saveCheckpoint(2, checkpoint.addresses);
    console.log("");
  }

  // ═══════════════════════════════════════════════════════════
  // STAGE 3: Deploy DividendPool
  // ═══════════════════════════════════════════════════════════
  if (startStage <= 3) {
    console.log("📦 [Stage 3/6] Deploying DividendPool...");
    const DividendPool = await ethers.getContractFactory("DividendPool");
    const { address } = await estimateAndDeploy(
      DividendPool,
      [dchatAddress, deployer.address, founderAddress],
      "DividendPool"
    );
    dividendPoolAddress = address;
    checkpoint.addresses.dividendPool = dividendPoolAddress;
    saveCheckpoint(3, checkpoint.addresses);
    console.log("");
  }

  // ═══════════════════════════════════════════════════════════
  // STAGE 4: Deploy DGovToken
  // ═══════════════════════════════════════════════════════════
  if (startStage <= 4) {
    console.log("📦 [Stage 4/6] Deploying DGovToken ($DGOV)...");
    const DGovToken = await ethers.getContractFactory("DGovToken");
    const { address } = await estimateAndDeploy(
      DGovToken,
      [founderAddress, dchatAddress, dividendPoolAddress],
      "DGovToken"
    );
    dgovAddress = address;
    checkpoint.addresses.dgov = dgovAddress;
    saveCheckpoint(4, checkpoint.addresses);
    console.log("");
  }

  // ═══════════════════════════════════════════════════════════
  // STAGE 5: Deploy DGovGovernance
  // ═══════════════════════════════════════════════════════════
  if (startStage <= 5) {
    console.log("📦 [Stage 5/6] Deploying DGovGovernance...");
    const DGovGovernance = await ethers.getContractFactory("DGovGovernance");
    const { address } = await estimateAndDeploy(
      DGovGovernance,
      [dgovAddress, founderAddress],
      "DGovGovernance"
    );
    governanceAddress = address;
    checkpoint.addresses.governance = governanceAddress;
    saveCheckpoint(5, checkpoint.addresses);
    console.log("");
  }

  // ═══════════════════════════════════════════════════════════
  // STAGE 6: Post-deploy configuration
  // ═══════════════════════════════════════════════════════════
  if (startStage <= 6) {
    console.log("⚙️  [Stage 6/6] Post-deploy configuration...");

    const dchat = await ethers.getContractAt("DChatStablecoin", dchatAddress);
    const dgov = await ethers.getContractAt("DGovToken", dgovAddress);
    const dividendPool = await ethers.getContractAt("DividendPool", dividendPoolAddress);
    const governance = await ethers.getContractAt("DGovGovernance", governanceAddress);

    // 6a. Set dividendPool on DChatStablecoin
    console.log("   → Setting dividendPool on DChatStablecoin...");
    const tx1 = await dchat.setDividendPool(dividendPoolAddress);
    await tx1.wait();
    console.log("   ✅ DChatStablecoin.dividendPool updated");

    // 6b. Grant DEPOSITOR_ROLE to DChatStablecoin on DividendPool
    console.log("   → Granting DEPOSITOR_ROLE to DChatStablecoin...");
    const DEPOSITOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DEPOSITOR_ROLE"));
    const tx2 = await dividendPool.grantRole(DEPOSITOR_ROLE, dchatAddress);
    await tx2.wait();
    console.log("   ✅ DEPOSITOR_ROLE granted to DChatStablecoin");

    // 6c. Grant DEPOSITOR_ROLE to DGovToken on DividendPool
    console.log("   → Granting DEPOSITOR_ROLE to DGovToken...");
    const tx3 = await dividendPool.grantRole(DEPOSITOR_ROLE, dgovAddress);
    await tx3.wait();
    console.log("   ✅ DEPOSITOR_ROLE granted to DGovToken");

    // 6d. Set dividendPool on DGovToken
    console.log("   → Setting dividendPool on DGovToken...");
    const tx4 = await dgov.setDividendPool(dividendPoolAddress);
    await tx4.wait();
    console.log("   ✅ DGovToken.dividendPool updated");

    // 6e. Add allowed targets in governance
    console.log("   → Adding allowed targets in governance...");
    const tx5 = await governance.setAllowedTarget(dgovAddress, true);
    await tx5.wait();
    const tx6 = await governance.setAllowedTarget(dchatAddress, true);
    await tx6.wait();
    const tx7 = await governance.setAllowedTarget(dividendPoolAddress, true);
    await tx7.wait();
    console.log("   ✅ All contracts added as allowed targets");

    saveCheckpoint(6, checkpoint.addresses);
  }

  // ─── Verification ───
  console.log("\n🔍 Verifying deployment state...");
  const dgov = await ethers.getContractAt("DGovToken", dgovAddress);
  const dgovTotalSupply = await dgov.totalSupply();
  console.log(`   DGOV Total Supply: ${ethers.formatEther(dgovTotalSupply)} DGOV`);
  const founderVesting = await dgov.getFounderVestingStatus();
  console.log(`   Founder Vesting Total: ${ethers.formatEther(founderVesting[0])} DGOV`);

  // ─── Summary ───
  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log("  DEPLOYMENT COMPLETE — DecentraChat v5.2");
  console.log("═══════════════════════════════════════════════════════════════");
  console.log(`  Network:          ${networkName} (chainId: ${chainId})`);
  console.log(`  Deployer/Founder: ${founderAddress}`);
  console.log(`  Reserve Wallet:   ${reserveWallet}`);
  console.log("───────────────────────────────────────────────────────────────");
  console.log(`  DChatStablecoin:  ${dchatAddress}`);
  console.log(`  DGovToken:        ${dgovAddress}`);
  console.log(`  DividendPool:     ${dividendPoolAddress}`);
  console.log(`  DGovGovernance:   ${governanceAddress}`);
  console.log(`  USDC:             ${usdcAddress}`);
  console.log(`  USDT:             ${usdtAddress}`);
  console.log("═══════════════════════════════════════════════════════════════");

  // ─── Save deployment.json ───
  const deploymentInfo = {
    version: "5.2",
    network: networkName,
    chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      DChatStablecoin: { address: dchatAddress, symbol: "DCHAT" },
      DGovToken: { address: dgovAddress, symbol: "DGOV" },
      DividendPool: { address: dividendPoolAddress },
      DGovGovernance: { address: governanceAddress },
    },
    collateral: { USDC: usdcAddress, USDT: usdtAddress },
    config: {
      founderAddress,
      reserveWallet,
      founderVesting: "30% (30M DGOV) — 10M/12mo, 10M/24mo, 10M/36mo",
      marketingAllocation: "10% (10M DGOV) — 180d lock + 180d linear",
      auctionAllocation: "60% (60M DGOV) — 6 phases, 36 months",
      dividendSplit: "70% nodes / 20% dividendPool / 10% reserve",
      messagingFee: "Dynamic per byte (C option)",
      quorum: "60% + 1 of total emitted",
      timelock: "48 hours",
    },
  };

  fs.writeFileSync("./deployment.json", JSON.stringify(deploymentInfo, null, 2));
  console.log("\n📄 deployment.json saved");

  // ─── Export ABIs ───
  const abiDir = "./abis";
  if (!fs.existsSync(abiDir)) fs.mkdirSync(abiDir);
  
  const contractNames = ["DChatStablecoin", "DGovToken", "DividendPool", "DGovGovernance"];
  for (const name of contractNames) {
    const artifact = await ethers.getContractFactory(name);
    const abi = artifact.interface.formatJson();
    fs.writeFileSync(`${abiDir}/${name}.json`, abi);
  }
  console.log("📄 ABIs exported to ./abis/");

  // ─── Polygonscan verification (non-local only) ───
  if (chainId !== 31337 && process.env.POLYGONSCAN_API_KEY) {
    console.log("\n🔍 Waiting 30s for block confirmations...");
    await new Promise((r) => setTimeout(r, 30000));

    const verifyList = [
      { name: "DChatStablecoin", address: dchatAddress, args: [founderAddress, deployer.address, reserveWallet, usdcAddress, usdtAddress] },
      { name: "DividendPool", address: dividendPoolAddress, args: [dchatAddress, deployer.address, founderAddress] },
      { name: "DGovToken", address: dgovAddress, args: [founderAddress, dchatAddress, dividendPoolAddress] },
      { name: "DGovGovernance", address: governanceAddress, args: [dgovAddress, founderAddress] },
    ];

    if (chainId === 80002) {
      verifyList.unshift(
        { name: "MockUSDC", address: usdcAddress, args: ["USD Coin (Mock)", "USDC", 6] },
        { name: "MockUSDT", address: usdtAddress, args: ["Tether USD (Mock)", "USDT", 6] },
      );
    }

    for (const c of verifyList) {
      try {
        console.log(`   → Verifying ${c.name}...`);
        await run("verify:verify", { address: c.address, constructorArguments: c.args });
        console.log(`   ✅ ${c.name} verified`);
      } catch (e) {
        console.log(`   ⚠️  ${c.name}: ${e.message.includes("Already") ? "already verified" : e.message}`);
      }
    }
  }

  // ─── Cleanup checkpoint ───
  if (fs.existsSync(CHECKPOINT_FILE)) {
    fs.renameSync(CHECKPOINT_FILE, `./deploy-checkpoint-${networkName}-${Date.now()}.json`);
    console.log("📋 Checkpoint archived");
  }

  console.log("\n✅ All done! Deploy commands for reference:");
  console.log("   Testnet:  PRIVATE_KEY=0x... npx hardhat run scripts/deploy-staged.js --network polygonAmoy");
  console.log("   Mainnet:  PRIVATE_KEY=0x... npx hardhat run scripts/deploy-staged.js --network polygonMainnet");
  console.log("   Resume:   PRIVATE_KEY=0x... RESUME_FROM=3 npx hardhat run scripts/deploy-staged.js --network polygonAmoy");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    console.error("   Use RESUME_FROM=<stage> to retry from the last successful stage");
    process.exit(1);
  });
