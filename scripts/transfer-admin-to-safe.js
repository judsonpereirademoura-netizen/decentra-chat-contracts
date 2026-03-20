/**
 * ============================================================
 * TRANSFER ADMIN TO GNOSIS SAFE — DecentraChat SC-01 Fix
 * ============================================================
 * 
 * Este script transfere o controle administrativo dos 4 contratos
 * para o Gnosis Safe multisig 2/3 criado em:
 * 0xfb094a46421958ed4810D00433aadC3a2976AE76
 * 
 * CONTRATOS:
 * 1. DChatStablecoin  — OpenZeppelin AccessControl (grantRole + renounceRole)
 * 2. DGovToken        — OpenZeppelin AccessControl (grantRole + renounceRole)
 * 3. DividendPool     — OpenZeppelin AccessControl (grantRole + renounceRole)
 * 4. DGovGovernance   — Custom admin (initiateAdminTransfer → 48h timelock → acceptAdminTransfer)
 * 
 * EXECUÇÃO:
 *   npx hardhat run scripts/transfer-admin-to-safe.js --network polygon
 * 
 * IMPORTANTE:
 * - Execute com a wallet deployer (0x5a37daD4eE116380BF4008A94E5b433ae32406F6)
 * - Certifique-se de ter MATIC suficiente para gas (~0.05 MATIC total)
 * - Após executar, o DGovGovernance terá um timelock de 48h
 * - Depois de 48h, execute o script accept-admin-transfer.js pelo Gnosis Safe
 * 
 * ============================================================
 */

const { ethers } = require("hardhat");

// ============================================================
// CONFIGURAÇÃO
// ============================================================

const GNOSIS_SAFE = "0xfb094a46421958ed4810D00433aadC3a2976AE76";

const CONTRACTS = {
  DChatStablecoin: "0xECC263f838B99f21432898200fb2d34D103253Eb",
  DGovToken: "0x99Af6047482554dfC150De94582fBAA52a00596A",
  DividendPool: "0xC9aCAf89231ADdEF53087F7670E4b22Ff1FB573B",
  DGovGovernance: "0x1A38ee6C8Cf505d6404aF6CF7843513B4B99d9E1",
};

// OpenZeppelin DEFAULT_ADMIN_ROLE = bytes32(0)
const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;

// ============================================================
// HELPERS
// ============================================================

async function waitForTx(tx, label) {
  console.log(`  ⏳ Aguardando confirmação: ${label}...`);
  console.log(`     TX Hash: ${tx.hash}`);
  const receipt = await tx.wait(2); // Aguarda 2 confirmações
  console.log(`  ✅ Confirmado no bloco ${receipt.blockNumber} (gas: ${receipt.gasUsed.toString()})`);
  return receipt;
}

// ============================================================
// FASE 1: Contratos com AccessControl (DChatStablecoin, DGovToken, DividendPool)
// ============================================================

async function transferAccessControl(contractName, contractAddress, signer) {
  console.log(`\n${"=".repeat(60)}`);
  console.log(`📋 ${contractName} (${contractAddress})`);
  console.log(`${"=".repeat(60)}`);

  const abi = [
    "function grantRole(bytes32 role, address account) external",
    "function renounceRole(bytes32 role, address callerConfirmation) external",
    "function hasRole(bytes32 role, address account) external view returns (bool)",
    "function getRoleAdmin(bytes32 role) external view returns (bytes32)",
  ];

  const contract = new ethers.Contract(contractAddress, abi, signer);

  // Step 1: Verificar que o deployer tem DEFAULT_ADMIN_ROLE
  const deployerHasAdmin = await contract.hasRole(DEFAULT_ADMIN_ROLE, signer.address);
  if (!deployerHasAdmin) {
    console.log(`  ❌ ERRO: Deployer ${signer.address} NÃO tem DEFAULT_ADMIN_ROLE!`);
    console.log(`  Pulando este contrato...`);
    return false;
  }
  console.log(`  ✅ Deployer tem DEFAULT_ADMIN_ROLE`);

  // Step 2: Verificar se o Safe já tem a role
  const safeHasAdmin = await contract.hasRole(DEFAULT_ADMIN_ROLE, GNOSIS_SAFE);
  if (safeHasAdmin) {
    console.log(`  ⚠️  Safe já tem DEFAULT_ADMIN_ROLE — pulando grantRole`);
  } else {
    // Step 2a: Grant DEFAULT_ADMIN_ROLE ao Gnosis Safe
    console.log(`  📤 grantRole(DEFAULT_ADMIN_ROLE, ${GNOSIS_SAFE})`);
    const tx1 = await contract.grantRole(DEFAULT_ADMIN_ROLE, GNOSIS_SAFE);
    await waitForTx(tx1, "grantRole");
  }

  // Step 3: Verificar que o Safe agora tem a role
  const safeConfirmed = await contract.hasRole(DEFAULT_ADMIN_ROLE, GNOSIS_SAFE);
  if (!safeConfirmed) {
    console.log(`  ❌ ERRO: Safe NÃO recebeu DEFAULT_ADMIN_ROLE! Abortando renounce.`);
    return false;
  }
  console.log(`  ✅ Safe confirmado como DEFAULT_ADMIN_ROLE`);

  // Step 4: Renounce DEFAULT_ADMIN_ROLE do deployer
  console.log(`  📤 renounceRole(DEFAULT_ADMIN_ROLE, ${signer.address})`);
  const tx2 = await contract.renounceRole(DEFAULT_ADMIN_ROLE, signer.address);
  await waitForTx(tx2, "renounceRole");

  // Step 5: Verificação final
  const deployerStillAdmin = await contract.hasRole(DEFAULT_ADMIN_ROLE, signer.address);
  const safeFinalAdmin = await contract.hasRole(DEFAULT_ADMIN_ROLE, GNOSIS_SAFE);

  if (!deployerStillAdmin && safeFinalAdmin) {
    console.log(`  🎉 SUCESSO: Admin transferido para Gnosis Safe!`);
    return true;
  } else {
    console.log(`  ⚠️  Estado inesperado:`);
    console.log(`     Deployer admin: ${deployerStillAdmin}`);
    console.log(`     Safe admin: ${safeFinalAdmin}`);
    return false;
  }
}

// ============================================================
// FASE 2: DGovGovernance (custom admin com timelock 48h)
// ============================================================

async function initiateGovernanceTransfer(signer) {
  console.log(`\n${"=".repeat(60)}`);
  console.log(`📋 DGovGovernance (${CONTRACTS.DGovGovernance})`);
  console.log(`${"=".repeat(60)}`);
  console.log(`  ⚠️  Este contrato tem timelock de 48 HORAS`);
  console.log(`  ⚠️  Após executar, aguarde 48h e execute accept-admin-transfer.js`);

  const abi = [
    "function admin() external view returns (address)",
    "function pendingAdmin() external view returns (address)",
    "function adminTransferTimestamp() external view returns (uint256)",
    "function initiateAdminTransfer(address _newAdmin) external",
  ];

  const contract = new ethers.Contract(CONTRACTS.DGovGovernance, abi, signer);

  // Step 1: Verificar admin atual
  const currentAdmin = await contract.admin();
  console.log(`  Admin atual: ${currentAdmin}`);

  if (currentAdmin.toLowerCase() !== signer.address.toLowerCase()) {
    console.log(`  ❌ ERRO: Deployer NÃO é o admin atual!`);
    return false;
  }

  // Step 2: Verificar se já há transferência pendente
  const pendingAdmin = await contract.pendingAdmin();
  if (pendingAdmin.toLowerCase() === GNOSIS_SAFE.toLowerCase()) {
    const timestamp = await contract.adminTransferTimestamp();
    const timelockEnd = Number(timestamp) + 48 * 3600;
    const now = Math.floor(Date.now() / 1000);
    const remaining = timelockEnd - now;
    if (remaining > 0) {
      const hours = Math.floor(remaining / 3600);
      const mins = Math.floor((remaining % 3600) / 60);
      console.log(`  ⚠️  Transferência já iniciada! Timelock restante: ${hours}h ${mins}m`);
      console.log(`  ⚠️  Execute accept-admin-transfer.js após o timelock expirar.`);
      return true;
    } else {
      console.log(`  ✅ Timelock já expirou! Execute accept-admin-transfer.js agora.`);
      return true;
    }
  }

  // Step 3: Iniciar transferência
  console.log(`  📤 initiateAdminTransfer(${GNOSIS_SAFE})`);
  const tx = await contract.initiateAdminTransfer(GNOSIS_SAFE);
  await waitForTx(tx, "initiateAdminTransfer");

  // Step 4: Confirmar
  const newPending = await contract.pendingAdmin();
  const newTimestamp = await contract.adminTransferTimestamp();
  const timelockEnd = new Date((Number(newTimestamp) + 48 * 3600) * 1000);

  console.log(`  ✅ Transferência iniciada com sucesso!`);
  console.log(`  📅 Pending admin: ${newPending}`);
  console.log(`  ⏰ Timelock expira em: ${timelockEnd.toISOString()}`);
  console.log(`  ⚠️  IMPORTANTE: Após ${timelockEnd.toISOString()}, execute:`);
  console.log(`     npx hardhat run scripts/accept-admin-transfer.js --network polygon`);
  console.log(`     (deve ser executado pelo Gnosis Safe via proposta multisig)`);

  return true;
}

// ============================================================
// MAIN
// ============================================================

async function main() {
  console.log("\n" + "█".repeat(60));
  console.log("█  TRANSFER ADMIN TO GNOSIS SAFE — DecentraChat SC-01");
  console.log("█".repeat(60));
  console.log(`\n  Gnosis Safe: ${GNOSIS_SAFE}`);
  console.log(`  Network: Polygon Mainnet (137)`);

  const [signer] = await ethers.getSigners();
  console.log(`  Deployer: ${signer.address}`);

  const balance = await ethers.provider.getBalance(signer.address);
  console.log(`  Balance: ${ethers.formatEther(balance)} MATIC\n`);

  if (balance < ethers.parseEther("0.01")) {
    console.log("  ❌ ERRO: Saldo insuficiente de MATIC para gas!");
    console.log("  Deposite pelo menos 0.05 MATIC na wallet deployer.");
    process.exit(1);
  }

  const results = {};

  // FASE 1: AccessControl contracts
  console.log("\n" + "─".repeat(60));
  console.log("  FASE 1: Contratos com OpenZeppelin AccessControl");
  console.log("─".repeat(60));

  results.DChatStablecoin = await transferAccessControl(
    "DChatStablecoin",
    CONTRACTS.DChatStablecoin,
    signer
  );

  results.DGovToken = await transferAccessControl(
    "DGovToken",
    CONTRACTS.DGovToken,
    signer
  );

  results.DividendPool = await transferAccessControl(
    "DividendPool",
    CONTRACTS.DividendPool,
    signer
  );

  // FASE 2: DGovGovernance (timelock)
  console.log("\n" + "─".repeat(60));
  console.log("  FASE 2: DGovGovernance (custom admin + 48h timelock)");
  console.log("─".repeat(60));

  results.DGovGovernance = await initiateGovernanceTransfer(signer);

  // RESUMO FINAL
  console.log("\n" + "█".repeat(60));
  console.log("█  RESUMO DA TRANSFERÊNCIA");
  console.log("█".repeat(60));

  for (const [name, success] of Object.entries(results)) {
    const icon = success ? "✅" : "❌";
    console.log(`  ${icon} ${name}: ${success ? "OK" : "FALHOU"}`);
  }

  console.log(`\n  📋 PRÓXIMOS PASSOS:`);
  console.log(`  1. Verifique no Polygonscan que o Safe é admin dos 3 contratos AccessControl`);
  console.log(`  2. Aguarde 48h para o timelock do DGovGovernance expirar`);
  console.log(`  3. Execute accept-admin-transfer.js pelo Gnosis Safe`);
  console.log(`  4. Verifique que o Safe é admin de TODOS os 4 contratos`);
  console.log("");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ ERRO FATAL:", error);
    process.exit(1);
  });
