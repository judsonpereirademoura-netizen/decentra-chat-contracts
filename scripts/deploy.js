const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("═══════════════════════════════════════════════════════════");
  console.log("  DecentraChat Smart Contract Deployment");
  console.log("═══════════════════════════════════════════════════════════");
  console.log(`  Deployer: ${deployer.address}`);
  console.log(`  Balance:  ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
  console.log("═══════════════════════════════════════════════════════════\n");

  // ─── Endereços para distribuição inicial ───
  // Em produção, estes seriam endereços de multisig wallets
  const founderAddress = deployer.address;
  const treasuryAddress = deployer.address;
  const publicSaleAddress = deployer.address;
  const airdropAddress = deployer.address;

  // ─── Custo base por byte: 0.000001 DCHAT (1e12 wei) ───
  const costPerByte = ethers.parseUnits("0.000001", 18);

  // ─── 1. Deploy DChatStaking (precisa do endereço do token, mas deploy primeiro para ter o endereço) ───
  // Estratégia: deploy token primeiro com staking pool = deployer, depois deploy staking, depois atualizar

  console.log("📦 [1/3] Deploying DChatToken...");
  const DChatToken = await ethers.getContractFactory("DChatToken");
  const dchatToken = await DChatToken.deploy(
    founderAddress,
    treasuryAddress,
    deployer.address, // stakingPool temporário (será atualizado)
    publicSaleAddress,
    airdropAddress,
    costPerByte
  );
  await dchatToken.waitForDeployment();
  const tokenAddress = await dchatToken.getAddress();
  console.log(`   ✅ DChatToken deployed at: ${tokenAddress}`);

  // ─── 2. Deploy DChatStaking ───
  console.log("\n📦 [2/3] Deploying DChatStaking...");
  const lockPeriod = 7 * 24 * 60 * 60; // 7 dias em segundos
  const DChatStaking = await ethers.getContractFactory("DChatStaking");
  const dchatStaking = await DChatStaking.deploy(tokenAddress, lockPeriod);
  await dchatStaking.waitForDeployment();
  const stakingAddress = await dchatStaking.getAddress();
  console.log(`   ✅ DChatStaking deployed at: ${stakingAddress}`);

  // ─── 3. Configurar staking pool no token ───
  console.log("\n⚙️  [3/3] Configuring staking pool...");

  // Transferir tokens do staking pool inicial para o contrato de staking
  const stakingInitialBalance = await dchatToken.balanceOf(deployer.address);
  const stakingPoolAmount = ethers.parseUnits("100000000", 18); // 100M DCHAT (10% do supply)

  // Aprovar e transferir para o staking contract
  await dchatToken.approve(stakingAddress, stakingPoolAmount);
  console.log(`   ✅ Approved ${ethers.formatEther(stakingPoolAmount)} DCHAT for staking contract`);

  // Atualizar o endereço do staking pool no token
  await dchatToken.setStakingPool(stakingAddress);
  console.log(`   ✅ Staking pool updated to: ${stakingAddress}`);

  // ─── Registrar deployer como primeiro node ───
  console.log("\n🖥️  Registering deployer as first node...");
  await dchatToken.registerNode(deployer.address);
  console.log(`   ✅ Node registered: ${deployer.address}`);

  // ─── Resumo do Deploy ───
  console.log("\n═══════════════════════════════════════════════════════════");
  console.log("  DEPLOYMENT SUMMARY");
  console.log("═══════════════════════════════════════════════════════════");
  console.log(`  DChatToken:   ${tokenAddress}`);
  console.log(`  DChatStaking: ${stakingAddress}`);
  console.log(`  Founder:      ${founderAddress}`);
  console.log(`  Treasury:     ${treasuryAddress}`);
  console.log(`  Cost/Byte:    ${ethers.formatUnits(costPerByte, 18)} DCHAT`);
  console.log(`  Lock Period:  ${lockPeriod / 86400} days`);
  console.log("═══════════════════════════════════════════════════════════");

  // ─── Verificar distribuição ───
  const stats = await dchatToken.getNetworkStats();
  console.log(`\n  Total Supply:  ${ethers.formatEther(await dchatToken.totalSupply())} DCHAT`);
  console.log(`  Node Count:    ${stats._nodeCount}`);
  console.log(`  Cost/Byte:     ${ethers.formatUnits(stats._currentCostPerByte, 18)} DCHAT`);

  // ─── Salvar endereços para integração frontend ───
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: Number((await ethers.provider.getNetwork()).chainId),
    deployer: deployer.address,
    contracts: {
      DChatToken: tokenAddress,
      DChatStaking: stakingAddress,
    },
    config: {
      costPerByte: costPerByte.toString(),
      lockPeriod: lockPeriod,
      founderAddress: founderAddress,
      treasuryAddress: treasuryAddress,
    },
    timestamp: new Date().toISOString(),
  };

  const fs = require("fs");
  fs.writeFileSync(
    "./deployment.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\n📄 Deployment info saved to deployment.json");

  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
