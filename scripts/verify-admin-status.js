/**
 * ============================================================
 * VERIFY ADMIN STATUS — Todos os 4 contratos
 * ============================================================
 * 
 * Verifica quem é o admin de cada contrato.
 * Execute antes e depois da transferência para confirmar.
 * 
 * EXECUÇÃO:
 *   npx hardhat run scripts/verify-admin-status.js --network polygon
 * 
 * ============================================================
 */

const { ethers } = require("hardhat");

const GNOSIS_SAFE = "0xfb094a46421958ed4810D00433aadC3a2976AE76";
const DEPLOYER = "0x5a37daD4eE116380BF4008A94E5b433ae32406F6";
const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;

const CONTRACTS = {
  DChatStablecoin: "0xECC263f838B99f21432898200fb2d34D103253Eb",
  DGovToken: "0x99Af6047482554dfC150De94582fBAA52a00596A",
  DividendPool: "0xC9aCAf89231ADdEF53087F7670E4b22Ff1FB573B",
  DGovGovernance: "0x1A38ee6C8Cf505d6404aF6CF7843513B4B99d9E1",
};

async function main() {
  console.log("\n" + "█".repeat(60));
  console.log("█  VERIFY ADMIN STATUS — DecentraChat Contracts");
  console.log("█".repeat(60));
  console.log(`\n  Gnosis Safe: ${GNOSIS_SAFE}`);
  console.log(`  Deployer:    ${DEPLOYER}\n`);

  // AccessControl contracts
  const accessControlAbi = [
    "function hasRole(bytes32 role, address account) external view returns (bool)",
  ];

  for (const name of ["DChatStablecoin", "DGovToken", "DividendPool"]) {
    const contract = new ethers.Contract(
      CONTRACTS[name],
      accessControlAbi,
      ethers.provider
    );

    const deployerIsAdmin = await contract.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER);
    const safeIsAdmin = await contract.hasRole(DEFAULT_ADMIN_ROLE, GNOSIS_SAFE);

    const status = safeIsAdmin && !deployerIsAdmin
      ? "✅ SAFE É ADMIN (deployer removido)"
      : safeIsAdmin && deployerIsAdmin
      ? "⚠️  AMBOS são admin (renounce pendente)"
      : !safeIsAdmin && deployerIsAdmin
      ? "🔴 DEPLOYER ainda é admin (transfer pendente)"
      : "❌ NINGUÉM é admin (PROBLEMA!)";

    console.log(`  ${name}:`);
    console.log(`    Deployer admin: ${deployerIsAdmin}`);
    console.log(`    Safe admin:     ${safeIsAdmin}`);
    console.log(`    Status: ${status}\n`);
  }

  // DGovGovernance (custom admin)
  const govAbi = [
    "function admin() external view returns (address)",
    "function pendingAdmin() external view returns (address)",
    "function adminTransferTimestamp() external view returns (uint256)",
  ];

  const gov = new ethers.Contract(CONTRACTS.DGovGovernance, govAbi, ethers.provider);
  const admin = await gov.admin();
  const pending = await gov.pendingAdmin();
  const timestamp = await gov.adminTransferTimestamp();

  let govStatus;
  if (admin.toLowerCase() === GNOSIS_SAFE.toLowerCase()) {
    govStatus = "✅ SAFE É ADMIN";
  } else if (pending.toLowerCase() === GNOSIS_SAFE.toLowerCase()) {
    const timelockEnd = Number(timestamp) + 48 * 3600;
    const now = Math.floor(Date.now() / 1000);
    const remaining = timelockEnd - now;
    if (remaining > 0) {
      const hours = Math.floor(remaining / 3600);
      const mins = Math.floor((remaining % 3600) / 60);
      govStatus = `⏳ TIMELOCK ATIVO (${hours}h ${mins}m restantes)`;
    } else {
      govStatus = "⏰ TIMELOCK EXPIRADO — execute acceptAdminTransfer pelo Safe!";
    }
  } else {
    govStatus = "🔴 DEPLOYER ainda é admin (transfer não iniciado)";
  }

  console.log(`  DGovGovernance:`);
  console.log(`    Admin atual:    ${admin}`);
  console.log(`    Pending admin:  ${pending}`);
  console.log(`    Status: ${govStatus}\n`);

  // Resumo
  console.log("─".repeat(60));
  console.log("  RESUMO:");
  console.log("─".repeat(60));
  console.log(`  Execute ANTES da transferência para ver o estado atual.`);
  console.log(`  Execute DEPOIS para confirmar que tudo foi transferido.\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ ERRO:", error);
    process.exit(1);
  });
