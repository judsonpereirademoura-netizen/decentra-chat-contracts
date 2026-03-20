/**
 * ============================================================
 * ACCEPT ADMIN TRANSFER — DGovGovernance
 * ============================================================
 * 
 * Este script aceita a transferência de admin do DGovGovernance
 * após o timelock de 48h ter expirado.
 * 
 * IMPORTANTE: Este script deve ser executado pelo Gnosis Safe
 * (0xfb094a46421958ed4810D00433aadC3a2976AE76) via proposta multisig.
 * 
 * COMO EXECUTAR VIA GNOSIS SAFE:
 * 1. Acesse app.safe.global com sua wallet conectada
 * 2. Selecione o Safe "DecentraChat Admin"
 * 3. Vá em "New Transaction" → "Contract Interaction"
 * 4. Cole o endereço: 0x1A38ee6C8Cf505d6404aF6CF7843513B4B99d9E1
 * 5. Cole o ABI abaixo ou selecione "acceptAdminTransfer"
 * 6. Clique "Submit" e assine com 2/3 signatários
 * 
 * ABI para colar no Safe:
 * [{"inputs":[],"name":"acceptAdminTransfer","outputs":[],"stateMutability":"nonpayable","type":"function"}]
 * 
 * OU execute via Hardhat (se tiver acesso à chave do Safe):
 *   npx hardhat run scripts/accept-admin-transfer.js --network polygon
 * 
 * ============================================================
 */

const { ethers } = require("hardhat");

const CONTRACTS = {
  DGovGovernance: "0x1A38ee6C8Cf505d6404aF6CF7843513B4B99d9E1",
};

const GNOSIS_SAFE = "0xfb094a46421958ed4810D00433aadC3a2976AE76";

async function main() {
  console.log("\n" + "█".repeat(60));
  console.log("█  ACCEPT ADMIN TRANSFER — DGovGovernance");
  console.log("█".repeat(60));

  const abi = [
    "function admin() external view returns (address)",
    "function pendingAdmin() external view returns (address)",
    "function adminTransferTimestamp() external view returns (uint256)",
    "function acceptAdminTransfer() external",
  ];

  const [signer] = await ethers.getSigners();
  console.log(`\n  Signer: ${signer.address}`);

  const contract = new ethers.Contract(CONTRACTS.DGovGovernance, abi, signer);

  // Verificar estado
  const currentAdmin = await contract.admin();
  const pendingAdmin = await contract.pendingAdmin();
  const timestamp = await contract.adminTransferTimestamp();

  console.log(`  Admin atual: ${currentAdmin}`);
  console.log(`  Pending admin: ${pendingAdmin}`);

  if (pendingAdmin.toLowerCase() !== GNOSIS_SAFE.toLowerCase()) {
    console.log(`\n  ❌ ERRO: Pending admin não é o Gnosis Safe!`);
    console.log(`  Esperado: ${GNOSIS_SAFE}`);
    console.log(`  Encontrado: ${pendingAdmin}`);
    process.exit(1);
  }

  // Verificar timelock
  const timelockEnd = Number(timestamp) + 48 * 3600;
  const now = Math.floor(Date.now() / 1000);
  const remaining = timelockEnd - now;

  if (remaining > 0) {
    const hours = Math.floor(remaining / 3600);
    const mins = Math.floor((remaining % 3600) / 60);
    console.log(`\n  ⏰ Timelock ainda ativo! Restam: ${hours}h ${mins}m`);
    console.log(`  Expira em: ${new Date(timelockEnd * 1000).toISOString()}`);
    process.exit(1);
  }

  console.log(`  ✅ Timelock expirado! Aceitando transferência...`);

  // Verificar que o signer é o pendingAdmin (Safe)
  if (signer.address.toLowerCase() !== GNOSIS_SAFE.toLowerCase()) {
    console.log(`\n  ⚠️  AVISO: Este script deve ser executado pelo Gnosis Safe.`);
    console.log(`  Signer atual: ${signer.address}`);
    console.log(`  Safe esperado: ${GNOSIS_SAFE}`);
    console.log(`\n  Para executar via Gnosis Safe:`);
    console.log(`  1. Acesse app.safe.global`);
    console.log(`  2. "New Transaction" → "Contract Interaction"`);
    console.log(`  3. Endereço: ${CONTRACTS.DGovGovernance}`);
    console.log(`  4. Função: acceptAdminTransfer()`);
    console.log(`  5. Assine com 2/3 signatários`);
    process.exit(1);
  }

  // Aceitar transferência
  const tx = await contract.acceptAdminTransfer();
  console.log(`  TX Hash: ${tx.hash}`);
  const receipt = await tx.wait(2);
  console.log(`  ✅ Confirmado no bloco ${receipt.blockNumber}`);

  // Verificação final
  const newAdmin = await contract.admin();
  console.log(`\n  🎉 Novo admin: ${newAdmin}`);

  if (newAdmin.toLowerCase() === GNOSIS_SAFE.toLowerCase()) {
    console.log(`  ✅ SUCESSO: DGovGovernance admin transferido para Gnosis Safe!`);
  } else {
    console.log(`  ❌ ERRO: Admin não foi transferido corretamente!`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ ERRO:", error);
    process.exit(1);
  });
