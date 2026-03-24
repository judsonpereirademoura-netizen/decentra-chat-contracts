const { ethers, upgrades, run } = require("hardhat");
const fs = require("fs");

/**
 * DecentraChat Dual-Token System — Proxy Deploy Script v6.0
 *
 * Deploy com UUPS Proxy para todos os 4 contratos.
 * Permite upgrades futuros sem migração de estado.
 *
 * Uso:
 *   # Deploy completo:
 *   PRIVATE_KEY="0x..." npx hardhat run scripts/deploy-proxy.js --network polygonAmoy
 *
 *   # Retomar a partir de uma etapa:
 *   PRIVATE_KEY="0x..." RESUME_FROM=3 npx hardhat run scripts/deploy-proxy.js --network polygonAmoy
 *
 *   # Mainnet:
 *   PRIVATE_KEY="0x..." npx hardhat run scripts/deploy-proxy.js --network polygonMainnet
 */

// Enderecos oficiais de colateral
const COLLATERAL = {
  31337: { USDC: null, USDT: null },
  80002: { USDC: null, USDT: null },
  137: {
    USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
    USDT: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
  },
};

const CHECKPOINT_FILE = "./deploy-checkpoint-proxy.json";

function loadCheckpoint() {
  try {
    if (fs.existsSync(CHECKPOINT_FILE)) {
      return JSON.parse(fs.readFileSync(CHECKPOINT_FILE, "utf8"));
    }
  } catch (e) {
    console.log("  Could not load checkpoint, starting fresh");
  }
  return { stage: 0, addresses: {} };
}

function saveCheckpoint(stage, addresses) {
  const checkpoint = { stage, addresses, timestamp: new Date().toISOString() };
  fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify(checkpoint, null, 2));
  console.log(`   Checkpoint saved (stage ${stage})`);
}

async function deployProxy(factory, args, name) {
  console.log(`   -> Deploying ${name} (UUPS Proxy)...`);
  const contract = await upgrades.deployProxy(factory, args, {
    kind: "uups",
    initializer: "initialize",
  });
  await contract.waitForDeployment();
  const proxyAddress = await contract.getAddress();
  const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log(`   [OK] ${name} Proxy:          ${proxyAddress}`);
  console.log(`        ${name} Implementation: ${implAddress}`);
  return { contract, proxyAddress, implAddress };
}

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const chainId = Number(network.chainId);
  const networkName = chainId === 31337 ? "hardhat" : chainId === 80002 ? "polygonAmoy" : "polygonMainnet";

  console.log("================================================================");
  console.log("  DecentraChat Dual-Token System — Proxy Deploy v6.0 (UUPS)");
  console.log("================================================================");
  console.log(`  Network:    ${networkName} (chainId: ${chainId})`);
  console.log(`  Deployer:   ${deployer.address}`);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`  Balance:    ${ethers.formatEther(balance)} POL`);
  console.log("================================================================\n");

  if (balance === 0n) {
    console.error("ERROR: Deployer has no POL.");
    process.exit(1);
  }

  const resumeFrom = parseInt(process.env.RESUME_FROM || "0");
  let checkpoint = resumeFrom > 0 ? loadCheckpoint() : { stage: 0, addresses: {} };
  const startStage = resumeFrom > 0 ? resumeFrom : checkpoint.stage + 1;

  if (startStage > 1) {
    console.log(`Resuming from stage ${startStage} (checkpoint loaded)`);
    console.log(`   Known addresses: ${JSON.stringify(checkpoint.addresses, null, 2)}\n`);
  }

  const founderAddress = deployer.address;
  const reserveWallet = deployer.address;
  const collateral = COLLATERAL[chainId];

  if (!collateral) {
    console.error(`ERROR: Unsupported chainId: ${chainId}`);
    process.exit(1);
  }

  let usdcAddress = checkpoint.addresses.mockUSDC;
  let usdtAddress = checkpoint.addresses.mockUSDT;
  let dchatProxyAddress = checkpoint.addresses.dchatProxy;
  let dividendPoolProxyAddress = checkpoint.addresses.dividendPoolProxy;
  let dgovProxyAddress = checkpoint.addresses.dgovProxy;
  let governanceProxyAddress = checkpoint.addresses.governanceProxy;

  // ================================================================
  // STAGE 1: Deploy Mock USDC/USDT (testnet only)
  // ================================================================
  if (startStage <= 1) {
    if (collateral.USDC === null) {
      console.log("[Stage 1/6] Deploying Mock USDC & USDT...");
      const MockERC20 = await ethers.getContractFactory("MockERC20");

      const mockUSDC = await MockERC20.deploy("USD Coin (Mock)", "USDC", 6);
      await mockUSDC.waitForDeployment();
      usdcAddress = await mockUSDC.getAddress();
      console.log(`   [OK] MockUSDC: ${usdcAddress}`);

      const mockUSDT = await MockERC20.deploy("Tether USD (Mock)", "USDT", 6);
      await mockUSDT.waitForDeployment();
      usdtAddress = await mockUSDT.getAddress();
      console.log(`   [OK] MockUSDT: ${usdtAddress}`);

      await mockUSDC.mint(deployer.address, ethers.parseUnits("1000000", 6));
      await mockUSDT.mint(deployer.address, ethers.parseUnits("1000000", 6));
      console.log("   [OK] Minted 1M USDC + 1M USDT to deployer\n");
    } else {
      console.log("[Stage 1/6] Using official collateral tokens...");
      usdcAddress = collateral.USDC;
      usdtAddress = collateral.USDT;
      console.log(`   USDC: ${usdcAddress}`);
      console.log(`   USDT: ${usdtAddress}\n`);
    }
    checkpoint.addresses.mockUSDC = usdcAddress;
    checkpoint.addresses.mockUSDT = usdtAddress;
    saveCheckpoint(1, checkpoint.addresses);
  }

  // ================================================================
  // STAGE 2: Deploy DChatStablecoin (UUPS Proxy)
  // ================================================================
  if (startStage <= 2) {
    console.log("[Stage 2/6] Deploying DChatStablecoin ($DCHAT)...");
    const DChatStablecoin = await ethers.getContractFactory("DChatStablecoin");
    const { proxyAddress } = await deployProxy(
      DChatStablecoin,
      [founderAddress, deployer.address, reserveWallet, usdcAddress, 6, usdtAddress, 6],
      "DChatStablecoin"
    );
    dchatProxyAddress = proxyAddress;
    checkpoint.addresses.dchatProxy = dchatProxyAddress;
    saveCheckpoint(2, checkpoint.addresses);
    console.log("");
  }

  // ================================================================
  // STAGE 3: Deploy DividendPool (UUPS Proxy)
  // ================================================================
  if (startStage <= 3) {
    console.log("[Stage 3/6] Deploying DividendPool...");
    const DividendPool = await ethers.getContractFactory("DividendPool");
    const { proxyAddress } = await deployProxy(
      DividendPool,
      [dchatProxyAddress, founderAddress],
      "DividendPool"
    );
    dividendPoolProxyAddress = proxyAddress;
    checkpoint.addresses.dividendPoolProxy = dividendPoolProxyAddress;
    saveCheckpoint(3, checkpoint.addresses);
    console.log("");
  }

  // ================================================================
  // STAGE 4: Deploy DGovToken (UUPS Proxy)
  // ================================================================
  if (startStage <= 4) {
    console.log("[Stage 4/6] Deploying DGovToken ($DGOV)...");
    const DGovToken = await ethers.getContractFactory("DGovToken");
    const { proxyAddress } = await deployProxy(
      DGovToken,
      [founderAddress, dchatProxyAddress, dividendPoolProxyAddress],
      "DGovToken"
    );
    dgovProxyAddress = proxyAddress;
    checkpoint.addresses.dgovProxy = dgovProxyAddress;
    saveCheckpoint(4, checkpoint.addresses);
    console.log("");
  }

  // ================================================================
  // STAGE 5: Deploy DGovGovernance (UUPS Proxy)
  // ================================================================
  if (startStage <= 5) {
    console.log("[Stage 5/6] Deploying DGovGovernance...");
    const DGovGovernance = await ethers.getContractFactory("DGovGovernance");
    const { proxyAddress } = await deployProxy(
      DGovGovernance,
      [dgovProxyAddress, founderAddress],
      "DGovGovernance"
    );
    governanceProxyAddress = proxyAddress;
    checkpoint.addresses.governanceProxy = governanceProxyAddress;
    saveCheckpoint(5, checkpoint.addresses);
    console.log("");
  }

  // ================================================================
  // STAGE 6: Post-deploy configuration
  // ================================================================
  if (startStage <= 6) {
    console.log("[Stage 6/6] Post-deploy configuration...");

    const dchat = await ethers.getContractAt("DChatStablecoin", dchatProxyAddress);
    const dgov = await ethers.getContractAt("DGovToken", dgovProxyAddress);
    const dividendPool = await ethers.getContractAt("DividendPool", dividendPoolProxyAddress);
    const governance = await ethers.getContractAt("DGovGovernance", governanceProxyAddress);

    // 6a. Set dividendPool on DChatStablecoin
    console.log("   -> Setting dividendPool on DChatStablecoin...");
    const tx1 = await dchat.setDividendPool(dividendPoolProxyAddress);
    await tx1.wait();
    console.log("   [OK] DChatStablecoin.dividendPool updated");

    // 6b. Grant DEPOSITOR_ROLE to DChatStablecoin on DividendPool
    console.log("   -> Granting DEPOSITOR_ROLE to DChatStablecoin...");
    const DEPOSITOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DEPOSITOR_ROLE"));
    const tx2 = await dividendPool.grantRole(DEPOSITOR_ROLE, dchatProxyAddress);
    await tx2.wait();
    console.log("   [OK] DEPOSITOR_ROLE granted to DChatStablecoin");

    // 6c. Grant DEPOSITOR_ROLE to DGovToken on DividendPool
    console.log("   -> Granting DEPOSITOR_ROLE to DGovToken...");
    const tx3 = await dividendPool.grantRole(DEPOSITOR_ROLE, dgovProxyAddress);
    await tx3.wait();
    console.log("   [OK] DEPOSITOR_ROLE granted to DGovToken");

    // 6c2. [FIX-4.1] Set DGovToken address on DividendPool (was not available at Stage 3)
    console.log("   -> Setting DGovToken on DividendPool...");
    const tx3b = await dividendPool.setDGovToken(dgovProxyAddress);
    await tx3b.wait();
    console.log("   [OK] DividendPool.dgovToken updated");

    // 6d. Set dividendPool on DGovToken
    console.log("   -> Setting dividendPool on DGovToken...");
    const tx4 = await dgov.setDividendPool(dividendPoolProxyAddress);
    await tx4.wait();
    console.log("   [OK] DGovToken.dividendPool updated");

    // 6e. Set governance contract on DGovToken
    console.log("   -> Setting governance contract on DGovToken...");
    const tx4b = await dgov.setGovernanceContract(governanceProxyAddress);
    await tx4b.wait();
    console.log("   [OK] DGovToken.governanceContract updated");

    // 6f. Add allowed targets in governance
    console.log("   -> Adding allowed targets in governance...");
    const tx5 = await governance.setAllowedTarget(dgovProxyAddress, true);
    await tx5.wait();
    const tx6 = await governance.setAllowedTarget(dchatProxyAddress, true);
    await tx6.wait();
    const tx7 = await governance.setAllowedTarget(dividendPoolProxyAddress, true);
    await tx7.wait();
    console.log("   [OK] All contracts added as allowed targets");

    saveCheckpoint(6, checkpoint.addresses);
  }

  // Verification
  console.log("\nVerifying deployment state...");
  const dgov = await ethers.getContractAt("DGovToken", dgovProxyAddress);
  const dgovTotalSupply = await dgov.totalSupply();
  console.log(`   DGOV Total Supply: ${ethers.formatEther(dgovTotalSupply)} DGOV`);
  const founderVesting = await dgov.getFounderVestingStatus();
  console.log(`   Founder Vesting Total: ${ethers.formatEther(founderVesting[0])} DGOV`);

  // Summary
  console.log("\n================================================================");
  console.log("  DEPLOYMENT COMPLETE — DecentraChat v6.0 (UUPS Proxy)");
  console.log("================================================================");
  console.log(`  Network:          ${networkName} (chainId: ${chainId})`);
  console.log(`  Deployer/Founder: ${founderAddress}`);
  console.log(`  Reserve Wallet:   ${reserveWallet}`);
  console.log("----------------------------------------------------------------");
  console.log(`  DChatStablecoin (Proxy):  ${dchatProxyAddress}`);
  console.log(`  DGovToken (Proxy):        ${dgovProxyAddress}`);
  console.log(`  DividendPool (Proxy):     ${dividendPoolProxyAddress}`);
  console.log(`  DGovGovernance (Proxy):   ${governanceProxyAddress}`);
  console.log(`  USDC:                     ${usdcAddress}`);
  console.log(`  USDT:                     ${usdtAddress}`);
  console.log("================================================================");

  // Save deployment.json
  const deploymentInfo = {
    version: "6.0-proxy",
    network: networkName,
    chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    proxyPattern: "UUPS (ERC-1967)",
    contracts: {
      DChatStablecoin: {
        proxy: dchatProxyAddress,
        implementation: await upgrades.erc1967.getImplementationAddress(dchatProxyAddress),
        symbol: "DCHAT",
      },
      DGovToken: {
        proxy: dgovProxyAddress,
        implementation: await upgrades.erc1967.getImplementationAddress(dgovProxyAddress),
        symbol: "DGOV",
      },
      DividendPool: {
        proxy: dividendPoolProxyAddress,
        implementation: await upgrades.erc1967.getImplementationAddress(dividendPoolProxyAddress),
      },
      DGovGovernance: {
        proxy: governanceProxyAddress,
        implementation: await upgrades.erc1967.getImplementationAddress(governanceProxyAddress),
      },
    },
    collateral: { USDC: usdcAddress, USDT: usdtAddress },
    config: {
      founderAddress,
      reserveWallet,
      founderVesting: "30% (30M DGOV) — 10M/12mo, 10M/24mo, 10M/36mo",
      marketingAllocation: "10% (10M DGOV) — 180d lock + 180d linear",
      auctionAllocation: "60% (60M DGOV) — 6 phases, 36 months",
      dividendSplit: "70% nodes / 20% dividendPool / 10% reserve",
      messagingFee: "Dynamic per byte",
      quorum: "60% + 1 of total emitted",
      timelock: "48 hours",
    },
  };

  fs.writeFileSync("./deployment.json", JSON.stringify(deploymentInfo, null, 2));
  console.log("\ndeployment.json saved");

  // Export ABIs
  const abiDir = "./abis";
  if (!fs.existsSync(abiDir)) fs.mkdirSync(abiDir);

  const contractNames = ["DChatStablecoin", "DGovToken", "DividendPool", "DGovGovernance"];
  for (const name of contractNames) {
    const artifact = await ethers.getContractFactory(name);
    const abi = artifact.interface.formatJson();
    fs.writeFileSync(`${abiDir}/${name}.json`, abi);
  }
  console.log("ABIs exported to ./abis/");

  // Polygonscan verification (non-local only)
  if (chainId !== 31337 && process.env.POLYGONSCAN_API_KEY) {
    console.log("\nWaiting 30s for block confirmations...");
    await new Promise((r) => setTimeout(r, 30000));

    for (const name of contractNames) {
      try {
        const proxyAddr = deploymentInfo.contracts[name].proxy;
        const implAddr = deploymentInfo.contracts[name].implementation;
        console.log(`   -> Verifying ${name} implementation (${implAddr})...`);
        await run("verify:verify", { address: implAddr, constructorArguments: [] });
        console.log(`   [OK] ${name} implementation verified`);
      } catch (e) {
        console.log(`   WARN ${name}: ${e.message.includes("Already") ? "already verified" : e.message}`);
      }
    }
  }

  // Cleanup checkpoint
  if (fs.existsSync(CHECKPOINT_FILE)) {
    fs.renameSync(CHECKPOINT_FILE, `./deploy-checkpoint-proxy-${networkName}-${Date.now()}.json`);
    console.log("Checkpoint archived");
  }

  console.log("\n[OK] All done! Deploy commands:");
  console.log("   Testnet:  PRIVATE_KEY=0x... npx hardhat run scripts/deploy-proxy.js --network polygonAmoy");
  console.log("   Mainnet:  PRIVATE_KEY=0x... npx hardhat run scripts/deploy-proxy.js --network polygonMainnet");
  console.log("   Resume:   PRIVATE_KEY=0x... RESUME_FROM=3 npx hardhat run scripts/deploy-proxy.js --network polygonAmoy");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("ERROR: Deployment failed:", error);
    console.error("   Use RESUME_FROM=<stage> to retry from the last successful stage");
    process.exit(1);
  });
