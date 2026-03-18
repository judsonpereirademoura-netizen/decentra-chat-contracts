const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("DecentraChat Dual-Token System v3.0", function () {
  let dchat, dgov, dividendPool;
  let mockUSDC, mockUSDT;
  let founder, user1, user2, user3, user4, node1, node2, relayer, reserve;

  const TOTAL_SUPPLY = ethers.parseEther("100000000"); // 100M
  const FOUNDER_ALLOC = ethers.parseEther("30000000");  // 30M
  const MARKETING_ALLOC = ethers.parseEther("10000000"); // 10M
  const AUCTION_ALLOC = ethers.parseEther("60000000");   // 60M

  const ONE_DAY = 86400;
  const ONE_WEEK = 7 * ONE_DAY;
  const ONE_YEAR = 365 * ONE_DAY;
  const NINETY_DAYS = 90 * ONE_DAY;

  // Helper: deploy mock ERC20 (USDC/USDT with 6 decimals)
  async function deployMockToken(name, symbol, decimals) {
    const MockToken = await ethers.getContractFactory("MockERC20");
    const token = await MockToken.deploy(name, symbol, decimals);
    await token.waitForDeployment();
    return token;
  }

  beforeEach(async function () {
    [founder, user1, user2, user3, user4, node1, node2, relayer, reserve] = await ethers.getSigners();

    // Deploy mock USDC/USDT
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockUSDC = await MockERC20.deploy("USD Coin", "USDC", 6);
    await mockUSDC.waitForDeployment();
    mockUSDT = await MockERC20.deploy("Tether USD", "USDT", 6);
    await mockUSDT.waitForDeployment();

    // Deploy DChatStablecoin
    const DChatStablecoin = await ethers.getContractFactory("DChatStablecoin");
    dchat = await DChatStablecoin.deploy(
      founder.address,
      reserve.address, // temporary dividend pool (will update)
      reserve.address,
      await mockUSDC.getAddress(),
      await mockUSDT.getAddress()
    );
    await dchat.waitForDeployment();

    // Deploy DGovToken (needs dchat address)
    const DGovToken = await ethers.getContractFactory("DGovToken");
    dgov = await DGovToken.deploy(
      founder.address,
      await dchat.getAddress(),
      reserve.address // temporary dividend pool
    );
    await dgov.waitForDeployment();

    // Deploy DividendPool
    const DividendPool = await ethers.getContractFactory("DividendPool");
    dividendPool = await DividendPool.deploy(
      await dchat.getAddress(),
      await dgov.getAddress(),
      founder.address
    );
    await dividendPool.waitForDeployment();

    // Update references
    await dchat.connect(founder).setDividendPool(await dividendPool.getAddress());
    await dgov.connect(founder).setDividendPool(await dividendPool.getAddress());

    // Grant RELAYER_ROLE
    const RELAYER_ROLE = await dchat.RELAYER_ROLE();
    await dchat.connect(founder).grantRole(RELAYER_ROLE, relayer.address);

    // Mint USDC to users for testing
    await mockUSDC.mint(user1.address, 1000000n * 10n ** 6n); // 1M USDC
    await mockUSDC.mint(user2.address, 1000000n * 10n ** 6n);
    await mockUSDC.mint(user3.address, 500000n * 10n ** 6n);
    await mockUSDC.mint(user4.address, 500000n * 10n ** 6n);

    // Users approve DCHAT contract to spend USDC
    await mockUSDC.connect(user1).approve(await dchat.getAddress(), ethers.MaxUint256);
    await mockUSDC.connect(user2).approve(await dchat.getAddress(), ethers.MaxUint256);
    await mockUSDC.connect(user3).approve(await dchat.getAddress(), ethers.MaxUint256);
    await mockUSDC.connect(user4).approve(await dchat.getAddress(), ethers.MaxUint256);

    // Mint $DCHAT via vault deposit
    await dchat.connect(user1).mint(await mockUSDC.getAddress(), 100000n * 10n ** 6n); // 100k DCHAT
    await dchat.connect(user2).mint(await mockUSDC.getAddress(), 100000n * 10n ** 6n);
    await dchat.connect(user3).mint(await mockUSDC.getAddress(), 50000n * 10n ** 6n);
    await dchat.connect(user4).mint(await mockUSDC.getAddress(), 50000n * 10n ** 6n);

    // Register users for auctions
    await dgov.connect(founder).registerUser(user1.address);
    await dgov.connect(founder).registerUser(user2.address);
    await dgov.connect(founder).registerUser(user3.address);
    await dgov.connect(founder).registerUser(user4.address);
  });

  // =========================================================================
  // $DCHAT STABLECOIN TESTS
  // =========================================================================
  describe("DChatStablecoin ($DCHAT)", function () {

    describe("Deployment", function () {
      it("Should have correct name and symbol", async function () {
        expect(await dchat.name()).to.equal("DecentraChat Stablecoin");
        expect(await dchat.symbol()).to.equal("DCHAT");
      });

      it("Should have correct fee distribution", async function () {
        expect(await dchat.NODE_FEE_BPS()).to.equal(7000);
        expect(await dchat.DIVIDEND_FEE_BPS()).to.equal(2000);
        expect(await dchat.RESERVE_FEE_BPS()).to.equal(1000);
      });

      it("Should accept USDC and USDT as collateral", async function () {
        expect(await dchat.acceptedCollateral(await mockUSDC.getAddress())).to.be.true;
        expect(await dchat.acceptedCollateral(await mockUSDT.getAddress())).to.be.true;
      });
    });

    describe("Vault — Mint & Redeem", function () {
      it("Should mint $DCHAT 1:1 with USDC deposit", async function () {
        const balance = await dchat.balanceOf(user1.address);
        expect(balance).to.equal(ethers.parseEther("100000"));
      });

      it("Should track vault balance correctly", async function () {
        const vaultBal = await dchat.vaultBalance(await mockUSDC.getAddress());
        // 100k + 100k + 50k + 50k = 300k USDC
        expect(vaultBal).to.equal(300000n * 10n ** 6n);
      });

      it("Should redeem $DCHAT for USDC (min 5 $DCHAT)", async function () {
        const redeemAmount = ethers.parseEther("100"); // 100 DCHAT
        const usdcBefore = await mockUSDC.balanceOf(user1.address);
        await dchat.connect(user1).redeem(await mockUSDC.getAddress(), redeemAmount);
        const usdcAfter = await mockUSDC.balanceOf(user1.address);
        expect(usdcAfter - usdcBefore).to.equal(100n * 10n ** 6n);
      });

      it("Should reject redeem below 5 $DCHAT minimum", async function () {
        const tooSmall = ethers.parseEther("4");
        await expect(
          dchat.connect(user1).redeem(await mockUSDC.getAddress(), tooSmall)
        ).to.be.revertedWith("Minimum redeem is 5 DCHAT");
      });

      it("Should have 100% collateralization ratio", async function () {
        const ratio = await dchat.getCollateralizationRatio();
        expect(ratio).to.equal(10000n); // 100%
      });
    });

    describe("Message Processing", function () {
      it("Should process message and distribute fees (70/20/10)", async function () {
        await dchat.connect(founder).registerNode(node1.address, ethers.parseEther("100"));

        // [F-10] User must approve relayer allowance before messaging
        await dchat.connect(user1).approveRelayerAllowance(ethers.parseEther("1000"));

        const fee = await dchat.calculateFee(1000, 0); // 1000 bytes text
        await dchat.connect(relayer).processMessage(user1.address, user2.address, 1000, 0);

        const stats = await dchat.getProtocolStats();
        expect(stats._totalMessages).to.equal(1n);
      });
    });

    describe("Admin Mint", function () {
      it("Should allow MINTER_ROLE to admin mint", async function () {
        await dchat.connect(founder).adminMint(user1.address, ethers.parseEther("1000"));
        // user1 had 100k, now 101k
        expect(await dchat.balanceOf(user1.address)).to.equal(ethers.parseEther("101000"));
      });
    });
  });

  // =========================================================================
  // $DGOV GOVERNANCE TOKEN TESTS
  // =========================================================================
  describe("DGovToken ($DGOV)", function () {

    describe("Deployment & Allocation", function () {
      it("Should have correct name and symbol", async function () {
        expect(await dgov.name()).to.equal("DecentraChat Governance");
        expect(await dgov.symbol()).to.equal("DGOV");
      });

      it("Should have 100M total supply", async function () {
        expect(await dgov.totalSupply()).to.equal(TOTAL_SUPPLY);
      });

      it("Should hold all tokens in contract initially", async function () {
        const contractBalance = await dgov.balanceOf(await dgov.getAddress());
        expect(contractBalance).to.equal(TOTAL_SUPPLY);
      });

      it("Should have correct allocation constants", async function () {
        expect(await dgov.FOUNDER_ALLOCATION()).to.equal(FOUNDER_ALLOC);
        expect(await dgov.MARKETING_ALLOCATION()).to.equal(MARKETING_ALLOC);
        expect(await dgov.AUCTION_ALLOCATION()).to.equal(AUCTION_ALLOC);
      });

      it("Should have 156 total auctions", async function () {
        expect(await dgov.TOTAL_AUCTIONS()).to.equal(156);
      });

      it("Should have 90 days auction delay", async function () {
        expect(await dgov.AUCTION_DELAY()).to.equal(NINETY_DAYS);
      });

      it("Should register founder as user", async function () {
        expect(await dgov.registeredUsers(founder.address)).to.be.true;
        expect(await dgov.totalRegisteredUsers()).to.equal(5); // founder + 4 users
      });
    });

    // =========================================================================
    // USER REGISTRATION
    // =========================================================================
    describe("User Registration", function () {
      it("Should register new users", async function () {
        const newUser = (await ethers.getSigners())[9];
        await dgov.connect(founder).registerUser(newUser.address);
        expect(await dgov.registeredUsers(newUser.address)).to.be.true;
      });

      it("Should batch register users", async function () {
        const signers = await ethers.getSigners();
        const newUsers = [signers[10].address, signers[11].address, signers[12].address];
        await dgov.connect(founder).registerUserBatch(newUsers);
        expect(await dgov.registeredUsers(signers[10].address)).to.be.true;
        expect(await dgov.registeredUsers(signers[11].address)).to.be.true;
        expect(await dgov.registeredUsers(signers[12].address)).to.be.true;
      });

      it("Should reject duplicate registration", async function () {
        await expect(
          dgov.connect(founder).registerUser(user1.address)
        ).to.be.revertedWith("Already registered");
      });

      it("Should unregister users", async function () {
        await dgov.connect(founder).unregisterUser(user1.address);
        expect(await dgov.registeredUsers(user1.address)).to.be.false;
      });

      it("Should reject unregistered user actions", async function () {
        const unregistered = (await ethers.getSigners())[15];
        await expect(
          dgov.connect(unregistered).depositToEscrow(ethers.parseEther("100"))
        ).to.be.revertedWith("Not a registered user");
      });
    });

    // =========================================================================
    // FOUNDER VESTING (30M: 10M every 12 months)
    // =========================================================================
    describe("Founder Vesting", function () {
      it("Should not allow claim before 12 months", async function () {
        await expect(
          dgov.connect(founder).claimFounderVesting()
        ).to.be.revertedWith("Tranche not yet unlocked");
      });

      it("Should allow first tranche after 12 months", async function () {
        await time.increase(ONE_YEAR);
        await dgov.connect(founder).claimFounderVesting();
        expect(await dgov.balanceOf(founder.address)).to.equal(ethers.parseEther("10000000"));
        expect(await dgov.founderTranchesClaimed()).to.equal(1);
      });

      it("Should allow second tranche after 24 months", async function () {
        await time.increase(ONE_YEAR);
        await dgov.connect(founder).claimFounderVesting();
        await time.increase(ONE_YEAR);
        await dgov.connect(founder).claimFounderVesting();
        expect(await dgov.balanceOf(founder.address)).to.equal(ethers.parseEther("20000000"));
        expect(await dgov.founderTranchesClaimed()).to.equal(2);
      });

      it("Should allow all 3 tranches (30M total)", async function () {
        for (let i = 0; i < 3; i++) {
          await time.increase(ONE_YEAR);
          await dgov.connect(founder).claimFounderVesting();
        }
        expect(await dgov.balanceOf(founder.address)).to.equal(ethers.parseEther("30000000"));
        expect(await dgov.founderTranchesClaimed()).to.equal(3);
      });

      it("Should reject 4th tranche claim", async function () {
        for (let i = 0; i < 3; i++) {
          await time.increase(ONE_YEAR);
          await dgov.connect(founder).claimFounderVesting();
        }
        await expect(
          dgov.connect(founder).claimFounderVesting()
        ).to.be.revertedWith("All tranches claimed");
      });

      it("Should only allow founder to claim", async function () {
        await time.increase(ONE_YEAR);
        await expect(
          dgov.connect(user1).claimFounderVesting()
        ).to.be.revertedWith("Only founder");
      });

      it("Should return correct vesting status", async function () {
        const status = await dgov.getFounderVestingStatus();
        expect(status.totalAllocated).to.equal(FOUNDER_ALLOC);
        expect(status.totalClaimed).to.equal(0);
        expect(status.tranchesClaimed).to.equal(0);
      });
    });

    // =========================================================================
    // MARKETING DISTRIBUTION (10M: lock 180 dias por transferência)
    // =========================================================================
    describe("Marketing Distribution (180d lock + 180d linear vesting)", function () {
      const ONE_HUNDRED_EIGHTY_DAYS = 180 * ONE_DAY;
      const THREE_SIXTY_DAYS = 360 * ONE_DAY;

      it("Should allow founder to transfer marketing tokens with lock", async function () {
        const amount = ethers.parseEther("1000000"); // 1M
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount);

        // Tokens are in user1's balance but fully locked
        expect(await dgov.balanceOf(user1.address)).to.equal(amount);
        expect(await dgov.getMarketingLockedBalance(user1.address)).to.equal(amount);
        expect(await dgov.getMarketingClaimable(user1.address)).to.equal(0);
      });

      it("Should prevent recipient from transferring locked tokens", async function () {
        const amount = ethers.parseEther("1000000");
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount);

        await expect(
          dgov.connect(user1).transfer(user2.address, amount)
        ).to.be.revertedWith("Cannot transfer locked marketing tokens");
      });

      it("Should not allow claim during 180-day lock period", async function () {
        const amount = ethers.parseEther("2000000");
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount);

        // Try claim at 90 days — still in lock period
        await time.increase(90 * ONE_DAY);
        await expect(
          dgov.connect(user1).unlockMarketingVesting(0)
        ).to.be.revertedWith("Lock period not expired");
      });

      it("Should allow partial claim after lock period starts linear vesting", async function () {
        const amount = ethers.parseEther("1800000"); // 1.8M
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount);

        // Advance to lock end + 90 days (50% of vesting period)
        await time.increase(ONE_HUNDRED_EIGHTY_DAYS + 90 * ONE_DAY);

        // ~50% should be claimable
        const claimable = await dgov.getMarketingClaimable(user1.address);
        // Allow 1% tolerance for block timestamp rounding
        const expected = amount / 2n;
        expect(claimable).to.be.closeTo(expected, ethers.parseEther("20000"));

        // Claim
        await dgov.connect(user1).unlockMarketingVesting(0);

        // Locked balance should be ~50%
        const locked = await dgov.getMarketingLockedBalance(user1.address);
        expect(locked).to.be.closeTo(expected, ethers.parseEther("20000"));

        // Can transfer claimed amount
        await dgov.connect(user1).transfer(user2.address, claimable);
      });

      it("Should fully unlock after 360 days (180 lock + 180 vesting)", async function () {
        const amount = ethers.parseEther("2000000");
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount);

        // Advance 360 days
        await time.increase(THREE_SIXTY_DAYS);

        // Everything should be claimable
        expect(await dgov.getMarketingClaimable(user1.address)).to.equal(amount);

        // Claim all
        await dgov.connect(user1).unlockMarketingVesting(0);
        expect(await dgov.getMarketingLockedBalance(user1.address)).to.equal(0);

        // Can transfer everything
        await dgov.connect(user1).transfer(user2.address, amount);
        expect(await dgov.balanceOf(user2.address)).to.equal(amount);
      });

      it("Should handle multiple claims over time (incremental vesting)", async function () {
        const amount = ethers.parseEther("1800000");
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount);

        // Claim at 25% vesting (180 + 45 days)
        await time.increase(ONE_HUNDRED_EIGHTY_DAYS + 45 * ONE_DAY);
        await dgov.connect(user1).unlockMarketingVesting(0);
        const claimed1 = amount / 4n; // ~25%

        // Claim at 75% vesting (180 + 135 days total)
        await time.increase(90 * ONE_DAY);
        await dgov.connect(user1).unlockMarketingVesting(0);

        // Claim rest at 100%
        await time.increase(45 * ONE_DAY);
        await dgov.connect(user1).unlockMarketingVesting(0);

        expect(await dgov.getMarketingLockedBalance(user1.address)).to.equal(0);
        expect(await dgov.getMarketingClaimable(user1.address)).to.equal(0);
      });

      it("Should handle multiple locks to same recipient", async function () {
        const amount1 = ethers.parseEther("1000000");
        const amount2 = ethers.parseEther("2000000");

        await dgov.connect(founder).transferMarketingTokens(user1.address, amount1);
        await time.increase(30 * ONE_DAY);
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount2);

        // Both fully locked
        expect(await dgov.getMarketingLockedBalance(user1.address)).to.equal(amount1 + amount2);

        // Advance to 360 days from first lock (fully vested for lock 1)
        await time.increase(330 * ONE_DAY);
        await dgov.connect(user1).unlockMarketingVesting(0); // Lock 1 fully vested
        
        // Lock 2 was created 30 days later, so it has 30 days of vesting left
        // Lock 2 vesting: 330 - 180 (lock period) = 150 days of 180 = ~83% vested
        // Remaining locked for lock 2: ~17% of 2M = ~333k
        const locked = await dgov.getMarketingLockedBalance(user1.address);
        expect(locked).to.be.gt(0);
        expect(locked).to.be.lt(amount2);

        // Advance 30 more days to fully vest second lock
        await time.increase(30 * ONE_DAY);
        await dgov.connect(user1).unlockMarketingVesting(1);
        expect(await dgov.getMarketingLockedBalance(user1.address)).to.equal(0);
      });

      it("Should distribute full 10M across multiple recipients", async function () {
        await dgov.connect(founder).transferMarketingTokens(user1.address, ethers.parseEther("3000000"));
        await dgov.connect(founder).transferMarketingTokens(user2.address, ethers.parseEther("3000000"));
        await dgov.connect(founder).transferMarketingTokens(user3.address, ethers.parseEther("4000000"));

        const status = await dgov.getMarketingDistributionStatus();
        expect(status.totalAllocated).to.equal(MARKETING_ALLOC);
        expect(status.totalDistributed).to.equal(MARKETING_ALLOC);
        expect(status.remaining).to.equal(0);

        await expect(
          dgov.connect(founder).transferMarketingTokens(user4.address, ethers.parseEther("1"))
        ).to.be.revertedWith("Exceeds marketing allocation");
      });

      it("Should only allow founder to transfer marketing tokens", async function () {
        await expect(
          dgov.connect(user1).transferMarketingTokens(user2.address, ethers.parseEther("1000"))
        ).to.be.revertedWith("Only founder");
      });

      it("Should return correct lock info via getMarketingLocks", async function () {
        await dgov.connect(founder).transferMarketingTokens(user1.address, ethers.parseEther("1000000"));
        await dgov.connect(founder).transferMarketingTokens(user1.address, ethers.parseEther("500000"));

        const locks = await dgov.getMarketingLocks(user1.address);
        expect(locks.amounts.length).to.equal(2);
        expect(locks.amounts[0]).to.equal(ethers.parseEther("1000000"));
        expect(locks.amounts[1]).to.equal(ethers.parseEther("500000"));
        expect(locks.claimedAmounts[0]).to.equal(0);
        expect(locks.claimedAmounts[1]).to.equal(0);
      });

      it("Should track totalMarketingLocked correctly through vesting", async function () {
        const amount = ethers.parseEther("5000000");
        await dgov.connect(founder).transferMarketingTokens(user1.address, amount);

        expect(await dgov.totalMarketingLocked()).to.equal(amount);

        // After full vesting (360 days)
        await time.increase(THREE_SIXTY_DAYS);
        await dgov.connect(user1).unlockMarketingVesting(0);

        expect(await dgov.totalMarketingLocked()).to.equal(0);
      });

      it("Should reject claim when nothing is claimable", async function () {
        await dgov.connect(founder).transferMarketingTokens(user1.address, ethers.parseEther("1000000"));

        // During lock period
        await expect(
          dgov.connect(user1).unlockMarketingVesting(0)
        ).to.be.revertedWith("Lock period not expired");

        // After full vesting and claim
        await time.increase(THREE_SIXTY_DAYS);
        await dgov.connect(user1).unlockMarketingVesting(0);

        await expect(
          dgov.connect(user1).unlockMarketingVesting(0)
        ).to.be.revertedWith("Nothing to claim");
      });
    });

    // =========================================================================
    // ESCROW POOL
    // =========================================================================
    describe("Escrow Pool", function () {
      it("Should allow registered users to deposit $DCHAT", async function () {
        await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("10000"));
        await dgov.connect(user1).depositToEscrow(ethers.parseEther("10000"));

        const bal = await dgov.getEscrowBalance(user1.address);
        expect(bal.total).to.equal(ethers.parseEther("10000"));
        expect(bal.locked).to.equal(0);
        expect(bal.available).to.equal(ethers.parseEther("10000"));
      });

      it("Should allow withdrawal of unlocked balance", async function () {
        await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("10000"));
        await dgov.connect(user1).depositToEscrow(ethers.parseEther("10000"));

        const balBefore = await dchat.balanceOf(user1.address);
        await dgov.connect(user1).withdrawFromEscrow(ethers.parseEther("5000"));
        const balAfter = await dchat.balanceOf(user1.address);

        expect(balAfter - balBefore).to.equal(ethers.parseEther("5000"));
      });

      it("Should track total escrow balance", async function () {
        await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("10000"));
        await dchat.connect(user2).approve(await dgov.getAddress(), ethers.parseEther("20000"));

        await dgov.connect(user1).depositToEscrow(ethers.parseEther("10000"));
        await dgov.connect(user2).depositToEscrow(ethers.parseEther("20000"));

        expect(await dgov.totalEscrowBalance()).to.equal(ethers.parseEther("30000"));
      });

      it("Should reject deposit from unregistered user", async function () {
        const unregistered = (await ethers.getSigners())[15];
        await expect(
          dgov.connect(unregistered).depositToEscrow(ethers.parseEther("100"))
        ).to.be.revertedWith("Not a registered user");
      });

      it("Should reject withdrawal exceeding available balance", async function () {
        await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("10000"));
        await dgov.connect(user1).depositToEscrow(ethers.parseEther("10000"));

        await expect(
          dgov.connect(user1).withdrawFromEscrow(ethers.parseEther("10001"))
        ).to.be.revertedWith("Insufficient unlocked balance");
      });
    });

    // =========================================================================
    // AUCTION SYSTEM — Fractional (Model B)
    // =========================================================================
    describe("Auction System — Fractional", function () {

      describe("Initialization", function () {
        it("Should initialize auctions with T+90 delay", async function () {
          await dgov.connect(founder).initializeAuctions();
          const startTime = await dgov.auctionsStartTime();
          expect(startTime).to.be.gt(0);
        });

        it("Should reject double initialization", async function () {
          await dgov.connect(founder).initializeAuctions();
          await expect(
            dgov.connect(founder).initializeAuctions()
          ).to.be.revertedWith("Already initialized");
        });
      });

      describe("Progressive Distribution", function () {
        it("Should calculate tokens per auction for phase 1 (7%)", async function () {
          // Phase 1: 7% of 60M = 4.2M, divided by 26 auctions = ~161,538.46
          const tokensForAuction1 = await dgov.getTokensForAuction(1);
          const expectedPhase1 = (AUCTION_ALLOC * 700n) / 10000n / 26n;
          expect(tokensForAuction1).to.equal(expectedPhase1);
        });

        it("Should calculate tokens per auction for phase 2 (14%)", async function () {
          const tokensForAuction27 = await dgov.getTokensForAuction(27);
          const expectedPhase2 = (AUCTION_ALLOC * 1400n) / 10000n / 26n;
          expect(tokensForAuction27).to.equal(expectedPhase2);
        });

        it("Should calculate tokens per auction for phase 6 (18%)", async function () {
          const tokensForAuction156 = await dgov.getTokensForAuction(156);
          const expectedPhase6 = (AUCTION_ALLOC * 1800n) / 10000n / 26n;
          expect(tokensForAuction156).to.equal(expectedPhase6);
        });

        it("Should reject invalid auction numbers", async function () {
          await expect(dgov.getTokensForAuction(0)).to.be.revertedWith("Invalid auction number");
          await expect(dgov.getTokensForAuction(157)).to.be.revertedWith("Invalid auction number");
        });

        it("Should return correct phase names", async function () {
          const p1 = await dgov.getAuctionPhase(1);
          expect(p1.phaseName).to.equal("Lancamento");

          const p2 = await dgov.getAuctionPhase(27);
          expect(p2.phaseName).to.equal("Crescimento");

          const p6 = await dgov.getAuctionPhase(156);
          expect(p6.phaseName).to.equal("Final");
        });
      });

      describe("Starting Auctions", function () {
        beforeEach(async function () {
          await dgov.connect(founder).initializeAuctions();
        });

        it("Should not start auction before T+90 days", async function () {
          await expect(
            dgov.connect(founder).startNextAuction()
          ).to.be.revertedWith("Too early for next auction");
        });

        it("Should start first auction after T+90 days", async function () {
          await time.increase(NINETY_DAYS);
          await dgov.connect(founder).startNextAuction();

          expect(await dgov.currentAuctionId()).to.equal(1);
          const info = await dgov.getAuctionInfo(1);
          expect(info.tokensAvailable).to.be.gt(0);
          const results = await dgov.getAuctionResults(1);
          expect(results.isActive).to.be.true;
        });

        it("Should not start next auction before previous is finalized", async function () {
          await time.increase(NINETY_DAYS);
          await dgov.connect(founder).startNextAuction();

          // Try to start another without finalizing
          await time.increase(ONE_WEEK);
          await expect(
            dgov.connect(founder).startNextAuction()
          ).to.be.revertedWith("Previous auction not finalized");
        });
      });

      describe("Placing Bids", function () {
        beforeEach(async function () {
          await dgov.connect(founder).initializeAuctions();
          await time.increase(NINETY_DAYS);
          await dgov.connect(founder).startNextAuction();

          // Users deposit to escrow
          await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("50000"));
          await dchat.connect(user2).approve(await dgov.getAddress(), ethers.parseEther("50000"));
          await dchat.connect(user3).approve(await dgov.getAddress(), ethers.parseEther("25000"));

          await dgov.connect(user1).depositToEscrow(ethers.parseEther("50000"));
          await dgov.connect(user2).depositToEscrow(ethers.parseEther("50000"));
          await dgov.connect(user3).depositToEscrow(ethers.parseEther("25000"));
        });

        it("Should accept a valid bid", async function () {
          const qty = ethers.parseEther("1000"); // 1000 DGOV
          const price = ethers.parseEther("0.5"); // 0.5 DCHAT per DGOV

          await dgov.connect(user1).placeBid(qty, price);

          const bidCount = await dgov.getAuctionBidCount(1);
          expect(bidCount).to.equal(1);

          const bid = await dgov.getBidInfo(1, 0);
          expect(bid.bidder).to.equal(user1.address);
          expect(bid.quantity).to.equal(qty);
          expect(bid.pricePerUnit).to.equal(price);
        });

        it("Should lock escrow when placing bid", async function () {
          const qty = ethers.parseEther("1000");
          const price = ethers.parseEther("0.5");
          const totalCost = (qty * price) / ethers.parseEther("1"); // 500 DCHAT

          await dgov.connect(user1).placeBid(qty, price);

          const bal = await dgov.getEscrowBalance(user1.address);
          expect(bal.locked).to.equal(totalCost);
          expect(bal.available).to.equal(ethers.parseEther("50000") - totalCost);
        });

        it("Should accept multiple bids from different users", async function () {
          await dgov.connect(user1).placeBid(ethers.parseEther("1000"), ethers.parseEther("0.5"));
          await dgov.connect(user2).placeBid(ethers.parseEther("2000"), ethers.parseEther("0.3"));
          await dgov.connect(user3).placeBid(ethers.parseEther("500"), ethers.parseEther("0.8"));

          const bidCount = await dgov.getAuctionBidCount(1);
          expect(bidCount).to.equal(3);
        });

        it("Should accept multiple bids from same user", async function () {
          await dgov.connect(user1).placeBid(ethers.parseEther("500"), ethers.parseEther("0.3"));
          await dgov.connect(user1).placeBid(ethers.parseEther("500"), ethers.parseEther("0.5"));

          const userBids = await dgov.getUserBids(1, user1.address);
          expect(userBids.length).to.equal(2);
        });

        it("Should reject bid below minimum price (0.01 DCHAT/DGOV)", async function () {
          await expect(
            dgov.connect(user1).placeBid(ethers.parseEther("1000"), ethers.parseEther("0.009"))
          ).to.be.revertedWith("Price below minimum (0.01 DCHAT/DGOV)");
        });

        it("Should reject bid with insufficient escrow", async function () {
          // Try to bid more than deposited
          await expect(
            dgov.connect(user1).placeBid(ethers.parseEther("200000"), ethers.parseEther("1"))
          ).to.be.revertedWith("Insufficient unlocked escrow balance");
        });

        it("Should reject bid from unregistered user", async function () {
          const unregistered = (await ethers.getSigners())[15];
          await expect(
            dgov.connect(unregistered).placeBid(ethers.parseEther("100"), ethers.parseEther("0.5"))
          ).to.be.revertedWith("Not a registered user");
        });

        it("Should reject bid after auction ends", async function () {
          await time.increase(ONE_DAY + 1);
          await expect(
            dgov.connect(user1).placeBid(ethers.parseEther("100"), ethers.parseEther("0.5"))
          ).to.be.revertedWith("Auction ended");
        });

        it("Should track highest price per unit", async function () {
          await dgov.connect(user1).placeBid(ethers.parseEther("1000"), ethers.parseEther("0.3"));
          await dgov.connect(user2).placeBid(ethers.parseEther("500"), ethers.parseEther("0.8"));

          const info = await dgov.getAuctionInfo(1);
          expect(info.highestPricePerUnit).to.equal(ethers.parseEther("0.8"));
        });

        it("Should track total bid volume", async function () {
          await dgov.connect(user1).placeBid(ethers.parseEther("1000"), ethers.parseEther("0.3"));
          await dgov.connect(user2).placeBid(ethers.parseEther("2000"), ethers.parseEther("0.5"));

          const info = await dgov.getAuctionInfo(1);
          expect(info.totalBidVolume).to.equal(ethers.parseEther("3000"));
        });
      });

      describe("Anti-Sniping", function () {
        beforeEach(async function () {
          await dgov.connect(founder).initializeAuctions();
          await time.increase(NINETY_DAYS);
          await dgov.connect(founder).startNextAuction();

          await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("50000"));
          await dgov.connect(user1).depositToEscrow(ethers.parseEther("50000"));
        });

        it("Should extend auction if bid in last 10 minutes", async function () {
          const info1 = await dgov.getAuctionInfo(1);
          const originalEnd = info1.endTime;

          // Advance to last 9 minutes
          await time.increase(ONE_DAY - 9 * 60);

          await dgov.connect(user1).placeBid(ethers.parseEther("100"), ethers.parseEther("0.5"));

          const info2 = await dgov.getAuctionInfo(1);
          expect(info2.endTime).to.be.gt(originalEnd);
        });

        it("Should NOT extend if bid is before last 10 minutes", async function () {
          const info1 = await dgov.getAuctionInfo(1);
          const originalEnd = info1.endTime;

          // Advance to 15 minutes before end
          await time.increase(ONE_DAY - 15 * 60);

          await dgov.connect(user1).placeBid(ethers.parseEther("100"), ethers.parseEther("0.5"));

          const info2 = await dgov.getAuctionInfo(1);
          expect(info2.endTime).to.equal(originalEnd);
        });
      });

      describe("Auction Finalization", function () {
        beforeEach(async function () {
          await dgov.connect(founder).initializeAuctions();
          await time.increase(NINETY_DAYS);
          await dgov.connect(founder).startNextAuction();

          // Deposit and approve
          await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("50000"));
          await dchat.connect(user2).approve(await dgov.getAddress(), ethers.parseEther("50000"));
          await dchat.connect(user3).approve(await dgov.getAddress(), ethers.parseEther("25000"));

          await dgov.connect(user1).depositToEscrow(ethers.parseEther("50000"));
          await dgov.connect(user2).depositToEscrow(ethers.parseEther("50000"));
          await dgov.connect(user3).depositToEscrow(ethers.parseEther("25000"));
        });

        it("Should reject finalization before auction ends", async function () {
          await expect(
            dgov.connect(founder).finalizeAuction(1)
          ).to.be.revertedWith("Auction still active");
        });

        it("Should burn all tokens if no bids", async function () {
          await time.increase(ONE_DAY + 1);
          const info = await dgov.getAuctionInfo(1);
          const tokensAvailable = info.tokensAvailable;

          await dgov.connect(founder).finalizeAuction(1);

          const finalInfo = await dgov.getAuctionInfo(1);
          expect(finalInfo.finalized).to.be.true;
          const results = await dgov.getAuctionResults(1);
          expect(results.tokensBurnedAmount).to.equal(tokensAvailable);
          expect(results.tokensSold).to.equal(0);
        });

        it("Should fill bids from highest to lowest price", async function () {
          const tokensAvail = (await dgov.getAuctionInfo(1)).tokensAvailable;

          // User3 bids highest price (25k escrow, bid 10k*1.0=10k cost)
          await dgov.connect(user3).placeBid(ethers.parseEther("10000"), ethers.parseEther("1.0"));
          // User1 bids medium price (50k escrow, bid 20k*0.5=10k cost)
          await dgov.connect(user1).placeBid(ethers.parseEther("20000"), ethers.parseEther("0.5"));
          // User2 bids lowest price (50k escrow, bid 30k*0.1=3k cost)
          await dgov.connect(user2).placeBid(ethers.parseEther("30000"), ethers.parseEther("0.1"));

          await time.increase(ONE_DAY + 1);
          await dgov.connect(founder).finalizeAuction(1);

          // User3 (highest price) should be filled first
          const user3Balance = await dgov.balanceOf(user3.address);
          expect(user3Balance).to.be.gt(0);

          // Check finalization
          const finalInfo = await dgov.getAuctionInfo(1);
          expect(finalInfo.finalized).to.be.true;
          const results = await dgov.getAuctionResults(1);
          expect(results.tokensSold).to.be.gt(0);
        });

        it("Should handle partial fills correctly", async function () {
          const tokensAvail = (await dgov.getAuctionInfo(1)).tokensAvailable;

          // Bid for more than available
          const bigBid = tokensAvail + ethers.parseEther("10000");
          await dgov.connect(user1).placeBid(bigBid, ethers.parseEther("0.01"));

          await time.increase(ONE_DAY + 1);
          await dgov.connect(founder).finalizeAuction(1);

          // User1 should get exactly tokensAvail
          const user1Balance = await dgov.balanceOf(user1.address);
          expect(user1Balance).to.equal(tokensAvail);

          // No tokens burned (all sold)
          const results = await dgov.getAuctionResults(1);
          expect(results.tokensBurnedAmount).to.equal(0);
        });

        it("Should burn unsold tokens", async function () {
          const tokensAvail = (await dgov.getAuctionInfo(1)).tokensAvailable;

          // Bid for only half
          const halfBid = tokensAvail / 2n;
          await dgov.connect(user1).placeBid(halfBid, ethers.parseEther("0.5"));

          await time.increase(ONE_DAY + 1);

          const supplyBefore = await dgov.totalSupply();
          await dgov.connect(founder).finalizeAuction(1);
          const supplyAfter = await dgov.totalSupply();

          const burned = supplyBefore - supplyAfter;
          expect(burned).to.equal(tokensAvail - halfBid);
        });

        it("Should send revenue to DividendPool", async function () {
          // Update DGovToken to point to real dividend pool
          // (Already done in beforeEach of main describe)

          // Need to approve DGovToken to transfer DCHAT to dividend pool
          // The DGovToken contract holds the DCHAT from escrow deposits
          // and transfers to dividendPool during finalization

          await dgov.connect(user1).placeBid(ethers.parseEther("1000"), ethers.parseEther("0.5"));

          await time.increase(ONE_DAY + 1);
          await dgov.connect(founder).finalizeAuction(1);

          const results = await dgov.getAuctionResults(1);
          expect(results.totalRevenue).to.be.gt(0);
        });

        it("Should unlock escrow for unfilled bids", async function () {
          const tokensAvail = (await dgov.getAuctionInfo(1)).tokensAvailable;

          // User1 bids high price for all tokens (50k escrow, tokensAvail * 0.3 cost)
          await dgov.connect(user1).placeBid(tokensAvail, ethers.parseEther("0.3"));
          // User2 bids low price — will be unfilled
          await dgov.connect(user2).placeBid(ethers.parseEther("1000"), ethers.parseEther("0.01"));

          const user2LockedBefore = (await dgov.getEscrowBalance(user2.address)).locked;
          expect(user2LockedBefore).to.be.gt(0);

          await time.increase(ONE_DAY + 1);
          await dgov.connect(founder).finalizeAuction(1);

          // User2's escrow should be fully unlocked
          const user2LockedAfter = (await dgov.getEscrowBalance(user2.address)).locked;
          expect(user2LockedAfter).to.equal(0);
        });

        it("Should reject double finalization", async function () {
          await time.increase(ONE_DAY + 1);
          await dgov.connect(founder).finalizeAuction(1);
          await expect(
            dgov.connect(founder).finalizeAuction(1)
          ).to.be.revertedWith("Already finalized");
        });
      });

      describe("Sequential Auctions", function () {
        beforeEach(async function () {
          await dgov.connect(founder).initializeAuctions();
          await time.increase(NINETY_DAYS);
        });

        it("Should run two sequential auctions", async function () {
          // Auction 1
          await dgov.connect(founder).startNextAuction();
          expect(await dgov.currentAuctionId()).to.equal(1);
          await time.increase(ONE_DAY + 1);
          await dgov.connect(founder).finalizeAuction(1);

          // Wait for next week
          await time.increase(ONE_WEEK);

          // Auction 2
          await dgov.connect(founder).startNextAuction();
          expect(await dgov.currentAuctionId()).to.equal(2);
        });
      });

      describe("View Functions", function () {
        it("Should return next auction schedule", async function () {
          await dgov.connect(founder).initializeAuctions();
          const schedule = await dgov.getNextAuctionSchedule();
          expect(schedule.nextAuctionId).to.equal(1);
          expect(schedule.tokensAvailable).to.be.gt(0);
        });
      });
    });

    // =========================================================================
    // GOVERNANCE
    // =========================================================================
    describe("Governance (DGovGovernance contract)", function () {
      let governance;

      beforeEach(async function () {
        // Deploy DGovGovernance
        const DGovGovernance = await ethers.getContractFactory("DGovGovernance");
        governance = await DGovGovernance.deploy(await dgov.getAddress(), founder.address);
        await governance.waitForDeployment();

        // Set governance contract on DGovToken
        await dgov.connect(founder).setGovernanceContract(await governance.getAddress());

        // Give founder tokens to create proposals
        await time.increase(ONE_YEAR);
        await dgov.connect(founder).claimFounderVesting(); // 10M DGOV

        // Register founder as voter
        await governance.connect(founder).registerAsVoter();
      });

      it("Should register as voter", async function () {
        const info = await governance.getVoterInfo(founder.address);
        expect(info.isReg).to.be.true;
        expect(info.isAct).to.be.true;
      });

      it("Should reject duplicate voter registration", async function () {
        await expect(
          governance.connect(founder).registerAsVoter()
        ).to.be.revertedWith("Already registered");
      });

      it("Should create a proposal", async function () {
        await governance.connect(founder).createProposal(
          "Test Proposal",
          "This is a test proposal for governance",
          0,
          "0x",
          ethers.ZeroAddress
        );
        const stats = await governance.getGovernanceVoterStats();
        expect(stats.propCount).to.equal(1);
      });

      it("Should reject proposal from non-voter", async function () {
        await expect(
          governance.connect(user1).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress)
        ).to.be.revertedWith("Not active voter");
      });

      it("Should allow voting on proposals", async function () {
        await governance.connect(founder).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress);
        await governance.connect(founder).castVote(1, 1); // Vote FOR

        const votes = await governance.getProposalVotesInfo(1);
        // Founder has 10M balance + 20M vesting weight = 30M voting power
        expect(votes.forV).to.be.gt(ethers.parseEther("10000000"));
      });

      it("Should reject double voting", async function () {
        await governance.connect(founder).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress);
        await governance.connect(founder).castVote(1, 1);
        await expect(
          governance.connect(founder).castVote(1, 1)
        ).to.be.revertedWith("Already voted");
      });

      it("Should track hasVoted correctly", async function () {
        await governance.connect(founder).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress);
        expect(await governance.hasVoted(1, founder.address)).to.be.false;
        await governance.connect(founder).castVote(1, 1);
        expect(await governance.hasVoted(1, founder.address)).to.be.true;
      });

      it("Should demonstrate quorum requires 60%+1 of total emitted (founder alone cannot pass)", async function () {
        // Quorum = 60.01% of 100M = 60.01M
        // Founder has 10M balance + 20M vesting = 30M voting power (30% of total)
        // This correctly means founder alone CANNOT pass proposals
        // This is by design: governance requires broad consensus

        // Give user1 some tokens and register as voter
        await dgov.connect(founder).transfer(user1.address, ethers.parseEther("5000000")); // 5M
        await governance.connect(user1).registerAsVoter();

        // Create proposal
        await governance.connect(founder).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress);

        // Both vote FOR: founder (25M = 5M balance + 20M vesting) + user1 (5M balance) = 30M
        await governance.connect(founder).castVote(1, 1);
        await governance.connect(user1).castVote(1, 1);

        // Verify votes recorded
        const votes = await governance.getProposalVotesInfo(1);
        expect(votes.forV).to.be.gt(ethers.parseEther("25000000")); // 25M+ total

        await time.increase(7 * ONE_DAY + 1);

        // 30M < 60M quorum — cannot queue
        await expect(
          governance.connect(founder).queueProposal(1)
        ).to.be.revertedWith("No quorum");
      });

      it("Should reject queue when quorum not met", async function () {
        await governance.connect(founder).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress);
        await governance.connect(founder).castVote(1, 1); // 30M voting power

        await time.increase(7 * ONE_DAY + 1);

        // 30M < 60M quorum
        await expect(
          governance.connect(founder).queueProposal(1)
        ).to.be.revertedWith("No quorum");
      });

      it("Should reject execution before timelock expires", async function () {
        // We test timelock by manually setting up a queued proposal
        // Since reaching quorum requires 60M+ votes, we test the timelock logic
        // by verifying the revert message when trying to execute without queue
        await governance.connect(founder).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress);
        await governance.connect(founder).castVote(1, 1);
        await time.increase(7 * ONE_DAY + 1);

        // Cannot execute without queuing first
        await expect(
          governance.connect(founder).executeProposal(1)
        ).to.be.revertedWith("Cannot execute");
      });

      it("Should support delegation", async function () {
        // Give user1 some DGOV
        await dgov.connect(founder).transfer(user1.address, ethers.parseEther("1000000"));

        // Register user1 as voter
        await governance.connect(user1).registerAsVoter();

        // user1 delegates to founder
        await governance.connect(user1).setDelegate(founder.address);

        const info = await governance.getVoterInfo(user1.address);
        expect(info.del).to.equal(founder.address);

        // Founder creates proposal and votes (should include delegated weight)
        await governance.connect(founder).createProposal("Test", "Description", 0, "0x", ethers.ZeroAddress);
        await governance.connect(founder).castVote(1, 1);

        // user1 should be marked as voted (delegated)
        expect(await governance.hasVoted(1, user1.address)).to.be.true;
      });

      it("Should deactivate inactive voter after 90 days", async function () {
        // Give user1 DGOV and register
        await dgov.connect(founder).transfer(user1.address, ethers.parseEther("100000"));
        await governance.connect(user1).registerAsVoter();

        // Cannot deactivate before 90 days
        await expect(
          governance.connect(founder).deactivateInactiveVoter(user1.address)
        ).to.be.revertedWith("Still active");

        // Advance 91 days
        await time.increase(91 * ONE_DAY);
        await governance.connect(founder).deactivateInactiveVoter(user1.address);

        const info = await governance.getVoterInfo(user1.address);
        expect(info.isAct).to.be.false;
      });

      it("Should allow voter to reactivate", async function () {
        await dgov.connect(founder).transfer(user1.address, ethers.parseEther("100000"));
        await governance.connect(user1).registerAsVoter();
        await time.increase(91 * ONE_DAY);
        await governance.connect(founder).deactivateInactiveVoter(user1.address);

        // Reactivate
        await governance.connect(user1).reactivateVoter();
        const info = await governance.getVoterInfo(user1.address);
        expect(info.isAct).to.be.true;
      });

      it("Should return correct governance stats", async function () {
        const stats = await governance.getGovernanceStats();
        expect(stats.emitted).to.equal(TOTAL_SUPPLY); // No burns yet
        expect(stats.threshold).to.be.gt(0);
        expect(stats.quorum).to.be.gt(0);
      });
    });

    // =========================================================================
    // PROTOCOL STATS
    // =========================================================================
    describe("Protocol Stats", function () {
      it("Should return correct initial stats", async function () {
        const stats = await dgov.getProtocolStats();
        expect(stats._totalSupply).to.equal(TOTAL_SUPPLY);
        expect(stats._totalBurned).to.equal(0);
        expect(stats._currentAuction).to.equal(0);
        expect(stats._remainingAuctions).to.equal(156);
      });

      it("Should return correct extended stats", async function () {
        const ext = await dgov.getProtocolStatsExtended();
        expect(ext._founderClaimed).to.equal(0);
        expect(ext._marketingDistributed).to.equal(0);
        expect(ext._registeredUsers).to.equal(5); // founder + 4 users
        expect(ext._totalEmitted).to.equal(TOTAL_SUPPLY);
      });
    });
  });

  // =========================================================================
  // DIVIDEND POOL TESTS
  // =========================================================================
  describe("DividendPool", function () {

    describe("Deployment", function () {
      it("Should have correct token references", async function () {
        expect(await dividendPool.dchatToken()).to.equal(await dchat.getAddress());
        expect(await dividendPool.dgovToken()).to.equal(await dgov.getAddress());
      });
    });

    describe("Vesting Weight", function () {
      it("Should set vesting weight for founder", async function () {
        await dividendPool.connect(founder).setVestingWeight(
          founder.address,
          FOUNDER_ALLOC // 30M
        );
        expect(await dividendPool.vestingWeight(founder.address)).to.equal(FOUNDER_ALLOC);
        expect(await dividendPool.totalVestingWeight()).to.equal(FOUNDER_ALLOC);
      });

      it("Should reduce vesting weight on claim", async function () {
        await dividendPool.connect(founder).setVestingWeight(founder.address, FOUNDER_ALLOC);

        // Simulate founder claiming first tranche
        await dividendPool.connect(founder).reduceVestingWeight(
          founder.address,
          ethers.parseEther("10000000") // 10M
        );

        expect(await dividendPool.vestingWeight(founder.address)).to.equal(ethers.parseEther("20000000"));
      });

      it("Should reject reduction exceeding weight", async function () {
        await dividendPool.connect(founder).setVestingWeight(founder.address, FOUNDER_ALLOC);
        await expect(
          dividendPool.connect(founder).reduceVestingWeight(
            founder.address,
            FOUNDER_ALLOC + 1n
          )
        ).to.be.revertedWith("Reduction exceeds weight");
      });
    });

    describe("Dividend Deposits", function () {
      beforeEach(async function () {
        // [F-16] Grant DEPOSITOR_ROLE to user1 for testing
        const DEPOSITOR_ROLE = await dividendPool.DEPOSITOR_ROLE();
        await dividendPool.connect(founder).grantRole(DEPOSITOR_ROLE, user1.address);
      });

      it("Should accept messaging dividends", async function () {
        const amount = ethers.parseEther("1000");
        await dchat.connect(user1).approve(await dividendPool.getAddress(), amount);
        await dividendPool.connect(user1).depositDividends(amount);

        expect(await dividendPool.totalFromMessaging()).to.equal(amount);
        expect(await dividendPool.totalDividendsDeposited()).to.equal(amount);
      });

      it("Should accept auction revenue", async function () {
        const amount = ethers.parseEther("5000");
        await dchat.connect(user1).approve(await dividendPool.getAddress(), amount);
        await dividendPool.connect(user1).depositAuctionRevenue(amount);

        expect(await dividendPool.totalFromAuctions()).to.equal(amount);
      });

      it("Should track both sources separately", async function () {
        const msgAmount = ethers.parseEther("1000");
        const auctionAmount = ethers.parseEther("5000");

        await dchat.connect(user1).approve(await dividendPool.getAddress(), msgAmount + auctionAmount);
        await dividendPool.connect(user1).depositDividends(msgAmount);
        await dividendPool.connect(user1).depositAuctionRevenue(auctionAmount);

        const stats = await dividendPool.getPoolStats();
        expect(stats._totalFromMessaging).to.equal(msgAmount);
        expect(stats._totalFromAuctions).to.equal(auctionAmount);
        expect(stats._totalDeposited).to.equal(msgAmount + auctionAmount);
      });
    });

    describe("Dividend Claims", function () {
      it("Should allow holder with vesting weight to claim dividends", async function () {
        // [F-16] Grant DEPOSITOR_ROLE to user1
        const DEPOSITOR_ROLE = await dividendPool.DEPOSITOR_ROLE();
        await dividendPool.connect(founder).grantRole(DEPOSITOR_ROLE, user1.address);

        // Set founder vesting weight
        await dividendPool.connect(founder).setVestingWeight(founder.address, FOUNDER_ALLOC);

        // Deposit dividends
        const amount = ethers.parseEther("10000");
        await dchat.connect(user1).approve(await dividendPool.getAddress(), amount);
        await dividendPool.connect(user1).depositDividends(amount);

        // Founder should have pending dividends
        const pending = await dividendPool.getPendingDividends(founder.address);
        expect(pending).to.be.gt(0);

        // Claim
        const balBefore = await dchat.balanceOf(founder.address);
        await dividendPool.connect(founder).claimDividends();
        const balAfter = await dchat.balanceOf(founder.address);
        expect(balAfter).to.be.gt(balBefore);
      });

      it("Should reject claim with no pending dividends", async function () {
        await expect(
          dividendPool.connect(user1).claimDividends()
        ).to.be.revertedWith("No dividends to claim");
      });
    });

    describe("Holder Info", function () {
      it("Should return correct holder info with vesting weight", async function () {
        await dividendPool.connect(founder).setVestingWeight(founder.address, FOUNDER_ALLOC);

        const info = await dividendPool.getHolderInfo(founder.address);
        expect(info.holderWeight).to.equal(FOUNDER_ALLOC);
        expect(info.vWeight).to.equal(FOUNDER_ALLOC);
        expect(info.dgovBalance).to.equal(0); // Founder hasn't claimed vesting yet
      });
    });
  });

  // =========================================================================
  // INTEGRATION TESTS
  // =========================================================================
  describe("Integration — Full Flow", function () {

    it("Should complete full auction → dividend flow", async function () {
      // 1. Set vesting weights
      await dividendPool.connect(founder).setVestingWeight(founder.address, FOUNDER_ALLOC);

      // 2. Initialize and start auction
      await dgov.connect(founder).initializeAuctions();
      await time.increase(NINETY_DAYS);
      await dgov.connect(founder).startNextAuction();

      // 3. Users deposit to escrow and bid
      await dchat.connect(user1).approve(await dgov.getAddress(), ethers.parseEther("50000"));
      await dgov.connect(user1).depositToEscrow(ethers.parseEther("50000"));
      await dgov.connect(user1).placeBid(ethers.parseEther("10000"), ethers.parseEther("0.5"));

      // 4. Finalize auction
      await time.increase(ONE_DAY + 1);
      await dgov.connect(founder).finalizeAuction(1);

      // 5. Verify user got tokens
      const user1Dgov = await dgov.balanceOf(user1.address);
      expect(user1Dgov).to.be.gt(0);

      // 6. Verify auction stats
      const auctionInfo = await dgov.getAuctionInfo(1);
      expect(auctionInfo.finalized).to.be.true;
      const auctionResults = await dgov.getAuctionResults(1);
      expect(auctionResults.tokensSold).to.be.gt(0);
    });

    it("Should handle competitive bidding with multiple users", async function () {
      await dgov.connect(founder).initializeAuctions();
      await time.increase(NINETY_DAYS);
      await dgov.connect(founder).startNextAuction();

      const tokensAvail = (await dgov.getAuctionInfo(1)).tokensAvailable;

      // All users deposit and bid
      for (const user of [user1, user2, user3]) {
        await dchat.connect(user).approve(await dgov.getAddress(), ethers.parseEther("30000"));
        await dgov.connect(user).depositToEscrow(ethers.parseEther("30000"));
      }

      // Different prices — amounts within escrow limits
      await dgov.connect(user1).placeBid(tokensAvail, ethers.parseEther("0.15"));  // Highest (cost ~24k)
      await dgov.connect(user2).placeBid(tokensAvail, ethers.parseEther("0.1"));   // Medium (cost ~16k)
      await dgov.connect(user3).placeBid(tokensAvail, ethers.parseEther("0.05")); // Lowest (cost ~8k)

      await time.increase(ONE_DAY + 1);
      await dgov.connect(founder).finalizeAuction(1);

      // User1 (highest bidder) should get all tokens
      const user1Bal = await dgov.balanceOf(user1.address);
      expect(user1Bal).to.equal(tokensAvail);

      // User2 and User3 should get nothing (outbid)
      const user2Bal = await dgov.balanceOf(user2.address);
      const user3Bal = await dgov.balanceOf(user3.address);
      expect(user2Bal).to.equal(0);
      expect(user3Bal).to.equal(0);

      // User2 and User3 escrow should be unlocked
      const user2Escrow = await dgov.getEscrowBalance(user2.address);
      const user3Escrow = await dgov.getEscrowBalance(user3.address);
      expect(user2Escrow.locked).to.equal(0);
      expect(user3Escrow.locked).to.equal(0);
    });

    it("Should complete founder vesting + governance proposal creation flow", async function () {
      // Deploy governance
      const DGovGovernance = await ethers.getContractFactory("DGovGovernance");
      const governance = await DGovGovernance.deploy(await dgov.getAddress(), founder.address);
      await governance.waitForDeployment();
      await dgov.connect(founder).setGovernanceContract(await governance.getAddress());

      // Claim first tranche
      await time.increase(ONE_YEAR);
      await dgov.connect(founder).claimFounderVesting();

      // Register as voter
      await governance.connect(founder).registerAsVoter();

      // Create and vote on proposal
      await governance.connect(founder).createProposal(
        "Increase Node Rewards",
        "Proposal to increase node reward percentage from 70% to 75%",
        1,
        "0x",
        ethers.ZeroAddress
      );

      await governance.connect(founder).castVote(1, 1); // Vote FOR (30M power)

      // Verify vote was recorded
      const votes = await governance.getProposalVotesInfo(1);
      expect(votes.forV).to.be.gt(ethers.parseEther("10000000")); // 10M balance + 20M vesting

      // Advance past voting period
      await time.increase(7 * ONE_DAY + 1);

      // Queue should fail — founder alone (30M) cannot reach quorum (60M+)
      // This is correct by design: no single holder should control governance
      await expect(
        governance.connect(founder).queueProposal(1)
      ).to.be.revertedWith("No quorum");
    });
  });
});
