import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import {
    impersonateAccount,
    loadFixture,
    setBalance,
    time,
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { BulletLastPresale, BulletLastToken } from "../typechain-types";
import { generateRandomAddress } from "../utils/account";

type Round = [bigint, bigint, bigint];
type Vesting = [bigint, bigint];

describe("BulletLastPresale", function () {
    const version = ethers.encodeBytes32String("1.0.0");
    const roundId = 1n;
    const vestingPeriods = 3n;
    const roundDuration = 60n; // 1 minute
    const vestingDuration = 24n * 60n * 60n; // 1 day
    const roundPrice = 200n; // 0.02 LEAD/USD
    const minSaleTokenAmount = ethers.parseUnits("5000", 18); // 5,000 LEAD
    const minSaleTokenPartialAmount = minSaleTokenAmount / 4n;
    const maxSaleTokenAmount = ethers.parseUnits("50000", 18); // 50,000 LEAD
    const allocatedSaleTokenAmount = maxSaleTokenAmount;
    const minEtherAmount = ethers.parseEther("0.04"); // 0.04 ETH
    const maxEtherAmount = ethers.parseEther("0.4"); // 0.0 ETH
    const minUSDTAmount = ethers.parseUnits("100", 6); // 100 USDT
    const maxUSDTAmount = ethers.parseUnits("1000", 6); // 1,000 USDT
    const priceFeedRoundAnswers: Array<[bigint, bigint]> = [
        [1n, 200_000_000_000n], // 1 round => 2,000 ETH/USD
        [2n, 250_000_000_000n], // 2 round => 2,500 ETH/USD
    ];

    async function deployFixture() {
        const [deployer, executor, grantee, roundManager, user] = await ethers.getSigners();

        const treasuryAddress = "0x58Dd2a0F95E346b9b891E0ad23E55B892EE803d7";
        await impersonateAccount(treasuryAddress);
        await setBalance(treasuryAddress, ethers.parseEther("10000"));
        const treasury = await ethers.provider.getSigner(treasuryAddress);

        const BulletLastToken = await ethers.getContractFactory("BulletLastToken");
        const bulletLastToken = await BulletLastToken.deploy(treasury.address);
        const bulletLastTokenAddress = await bulletLastToken.getAddress();

        const EtherPriceFeedMock = await ethers.getContractFactory("EtherPriceFeedMock");
        const etherPriceFeedMock = await EtherPriceFeedMock.deploy(priceFeedRoundAnswers);
        const etherPriceFeedMockAddress = await etherPriceFeedMock.getAddress();

        const USDTToken = await ethers.getContractFactory("USDTToken");
        const usdtToken = await USDTToken.deploy(maxUSDTAmount);
        const usdtTokenAddress = await usdtToken.getAddress();

        const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
        const bulletLastPresale = await upgrades.deployProxy(BulletLastPresale, [
            bulletLastTokenAddress,
            etherPriceFeedMockAddress,
            usdtTokenAddress,
            treasury.address,
            vestingDuration,
        ]);
        const bulletLastPresaleAddress = await bulletLastPresale.getAddress();

        const Reverter = await ethers.getContractFactory("Reverter");
        const reverter = await Reverter.deploy(bulletLastPresaleAddress);
        const reverterAddress = await reverter.getAddress();

        const defaultAdminRole = await bulletLastPresale.DEFAULT_ADMIN_ROLE();
        const roundManagerRole = await bulletLastPresale.ROUND_MANAGER_ROLE();

        await (bulletLastToken.connect(treasury) as BulletLastToken).approve(
            bulletLastPresaleAddress,
            maxSaleTokenAmount
        );
        await usdtToken.transfer(user.address, maxUSDTAmount);
        await bulletLastPresale.grantRole(roundManagerRole, roundManager);
        await bulletLastPresale.setAllocatedAmount(allocatedSaleTokenAmount);

        return {
            bulletLastPresale,
            bulletLastPresaleAddress,
            bulletLastToken,
            bulletLastTokenAddress,
            etherPriceFeedMock,
            etherPriceFeedMockAddress,
            usdtToken,
            usdtTokenAddress,
            reverter,
            reverterAddress,
            deployer,
            executor,
            grantee,
            roundManager,
            treasury,
            user,
            defaultAdminRole,
            roundManagerRole,
        };
    }

    describe("Deploy the contract", function () {
        describe("Validations", function () {
            it("Should revert with the right error if passing the zero sale token address", async function () {
                const { bulletLastPresale, etherPriceFeedMockAddress, usdtTokenAddress, treasury } =
                    await loadFixture(deployFixture);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                const promise = upgrades.deployProxy(BulletLastPresale, [
                    ethers.ZeroAddress,
                    etherPriceFeedMockAddress,
                    usdtTokenAddress,
                    treasury.address,
                    vestingDuration,
                ]);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroSaleToken")
                    .withArgs();
            });

            it("Should revert with the right error if passing the zero Ether price feed address", async function () {
                const { bulletLastPresale, bulletLastTokenAddress, usdtTokenAddress, treasury } =
                    await loadFixture(deployFixture);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                const promise = upgrades.deployProxy(BulletLastPresale, [
                    bulletLastTokenAddress,
                    ethers.ZeroAddress,
                    usdtTokenAddress,
                    treasury.address,
                    vestingDuration,
                ]);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroPriceFeed")
                    .withArgs();
            });

            it("Should revert with the right error if passing the zero USDT token address", async function () {
                const {
                    bulletLastPresale,
                    bulletLastTokenAddress,
                    etherPriceFeedMockAddress,
                    treasury,
                } = await loadFixture(deployFixture);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                const promise = upgrades.deployProxy(BulletLastPresale, [
                    bulletLastTokenAddress,
                    etherPriceFeedMockAddress,
                    ethers.ZeroAddress,
                    treasury.address,
                    vestingDuration,
                ]);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroUSDTToken")
                    .withArgs();
            });

            it("Should revert with the right error if passing the zero treasury address", async function () {
                const {
                    bulletLastPresale,
                    bulletLastTokenAddress,
                    etherPriceFeedMockAddress,
                    usdtTokenAddress,
                } = await loadFixture(deployFixture);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                const promise = upgrades.deployProxy(BulletLastPresale, [
                    bulletLastTokenAddress,
                    etherPriceFeedMockAddress,
                    usdtTokenAddress,
                    ethers.ZeroAddress,
                    vestingDuration,
                ]);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroTreasury")
                    .withArgs();
            });

            it("Should revert with the right error if passing the zero vesting duration", async function () {
                const {
                    bulletLastPresale,
                    bulletLastTokenAddress,
                    etherPriceFeedMockAddress,
                    usdtTokenAddress,
                    treasury,
                } = await loadFixture(deployFixture);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                const promise = upgrades.deployProxy(BulletLastPresale, [
                    bulletLastTokenAddress,
                    etherPriceFeedMockAddress,
                    usdtTokenAddress,
                    treasury.address,
                    0n,
                ]);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroVestingDuration")
                    .withArgs();
            });
        });

        describe("Checks", function () {
            it("Should return the right version", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const currentVersion: string = await bulletLastPresale.VERSION();
                expect(currentVersion).to.equal(version);
            });

            it("Should return the default admin role set for the deployer", async function () {
                const { bulletLastPresale, deployer, defaultAdminRole } =
                    await loadFixture(deployFixture);

                const hasDefaultAdminRole: boolean = await bulletLastPresale.hasRole(
                    defaultAdminRole,
                    deployer.address
                );
                expect(hasDefaultAdminRole).to.be.true;
            });

            it("Should return the right admin role managing the round manager role", async function () {
                const { bulletLastPresale, defaultAdminRole, roundManagerRole } =
                    await loadFixture(deployFixture);

                const currentAdminRole: string =
                    await bulletLastPresale.getRoleAdmin(roundManagerRole);
                expect(currentAdminRole).to.equal(defaultAdminRole);
            });
            it("Should return the right active round id", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const currentActiveRoundId: bigint = await bulletLastPresale.activeRoundId();
                expect(currentActiveRoundId).to.equal(0n);
            });

            it("Should return the right vesting duration", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const currentVestingDuration: bigint = await bulletLastPresale.vestingDuration();
                expect(currentVestingDuration).to.equal(vestingDuration);
            });

            it("Should return the right allocated amount", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const currentAllocatedAmount: bigint = await bulletLastPresale.allocatedAmount();
                expect(currentAllocatedAmount).to.equal(allocatedSaleTokenAmount);
            });

            it("Should return the right sale token address", async function () {
                const { bulletLastPresale, bulletLastTokenAddress } =
                    await loadFixture(deployFixture);

                const currentSaleTokenAddress: string = await bulletLastPresale.saleToken();
                expect(currentSaleTokenAddress).to.equal(bulletLastTokenAddress);
            });

            it("Should return the right Ether price feed address", async function () {
                const { bulletLastPresale, etherPriceFeedMockAddress } =
                    await loadFixture(deployFixture);

                const currentEtherPriceFeedAddress: string =
                    await bulletLastPresale.etherPriceFeed();
                expect(currentEtherPriceFeedAddress).to.equal(etherPriceFeedMockAddress);
            });

            it("Should return the right USDT token address", async function () {
                const { bulletLastPresale, usdtToken } = await loadFixture(deployFixture);

                const currentUSDTTokenAddress: string = await bulletLastPresale.usdtToken();
                expect(currentUSDTTokenAddress).to.equal(usdtToken);
            });

            it("Should return the right treasury address", async function () {
                const { bulletLastPresale, treasury } = await loadFixture(deployFixture);

                const currentTreasuryAddress: string = await bulletLastPresale.treasury();
                expect(currentTreasuryAddress).to.equal(treasury.address);
            });

            it("Should return the right round id count", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const currentRoundIdCount: bigint = await bulletLastPresale.getRoundIdCount();
                expect(currentRoundIdCount).to.equal(0n);
            });
        });
    });

    describe("Upgrade the contract", function () {
        describe("Checks", function () {
            it("Should return a new address of the implementation if upgrading the contract", async function () {
                const { bulletLastPresaleAddress } = await loadFixture(deployFixture);

                const initialImplementationAddress =
                    await upgrades.erc1967.getImplementationAddress(bulletLastPresaleAddress);

                const BulletLastPresaleMock =
                    await ethers.getContractFactory("BulletLastPresaleMock");
                await upgrades.upgradeProxy(bulletLastPresaleAddress, BulletLastPresaleMock);

                const currentImplementationAddress =
                    await upgrades.erc1967.getImplementationAddress(bulletLastPresaleAddress);
                expect(initialImplementationAddress).not.to.equal(currentImplementationAddress);
            });

            it("Should return the same address of the implementation if not upgrading the contract", async function () {
                const { bulletLastPresaleAddress } = await loadFixture(deployFixture);

                const initialImplementationAddress =
                    await upgrades.erc1967.getImplementationAddress(bulletLastPresaleAddress);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                await upgrades.upgradeProxy(bulletLastPresaleAddress, BulletLastPresale);

                const currentImplementationAddress =
                    await upgrades.erc1967.getImplementationAddress(bulletLastPresaleAddress);
                expect(currentImplementationAddress).to.equal(initialImplementationAddress);
            });
        });
    });

    describe("Fallback", function () {
        describe("Validations", function () {
            it("Should revert without a reason if calling a non existing method", async function () {
                const { bulletLastPresaleAddress, executor } = await loadFixture(deployFixture);
                const iface = new ethers.Interface(["function foo(uint256)"]);

                const promise = executor.sendTransaction({
                    to: bulletLastPresaleAddress,
                    data: iface.encodeFunctionData("foo", [1n]),
                });
                await expect(promise).to.be.revertedWithoutReason();
            });

            it("Should revert without a reason if sending arbitrary data", async function () {
                const { bulletLastPresaleAddress, executor } = await loadFixture(deployFixture);

                const promise = executor.sendTransaction({
                    to: bulletLastPresaleAddress,
                    data: "0x01",
                });
                await expect(promise).to.be.revertedWithoutReason();
            });

            it("Should revert without a reason if sending some native token amount", async function () {
                const { bulletLastPresaleAddress, executor } = await loadFixture(deployFixture);

                const promise = executor.sendTransaction({
                    to: bulletLastPresaleAddress,
                    value: 1n,
                });
                await expect(promise).to.be.revertedWithoutReason();
            });

            it("Should revert without a reason if sending no native token amount", async function () {
                const { bulletLastPresaleAddress, executor } = await loadFixture(deployFixture);

                const promise = executor.sendTransaction({
                    to: bulletLastPresaleAddress,
                });
                await expect(promise).to.be.revertedWithoutReason();
            });
        });
    });

    describe("Grant a role", function () {
        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async function () {
                const { bulletLastPresale, grantee, defaultAdminRole, roundManagerRole } =
                    await loadFixture(deployFixture);

                const promise = (bulletLastPresale.connect(grantee) as BulletLastPresale).grantRole(
                    roundManagerRole,
                    grantee.address
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(grantee.address, defaultAdminRole);
            });
        });

        describe("Events", function () {
            it("Should emit the RoleGranted event for the package manager role", async function () {
                const { bulletLastPresale, deployer, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                const promise = bulletLastPresale.grantRole(roundManagerRole, grantee.address);
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoleGranted")
                    .withArgs(roundManagerRole, grantee.address, deployer.address);
            });
        });

        describe("Checks", function () {
            it("Should return the right granted role state", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);

                const hasGrantedRole = await bulletLastPresale.hasRole(
                    roundManagerRole,
                    grantee.address
                );
                expect(hasGrantedRole).to.be.true;
            });
        });
    });

    describe("Revoke a role", function () {
        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async function () {
                const { bulletLastPresale, grantee, defaultAdminRole, roundManagerRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);

                const promise = (
                    bulletLastPresale.connect(grantee) as BulletLastPresale
                ).revokeRole(roundManagerRole, grantee.address);
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(grantee.address, defaultAdminRole);
            });
        });

        describe("Events", function () {
            it("Should emit the RoleRevoked event", async function () {
                const { bulletLastPresale, deployer, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);

                const promise = bulletLastPresale.revokeRole(roundManagerRole, grantee.address);
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoleRevoked")
                    .withArgs(roundManagerRole, grantee.address, deployer.address);
            });

            it("Should skip emitting the RoleRevoked event without an upfront grant", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                const promise = bulletLastPresale.revokeRole(roundManagerRole, grantee.address);
                await expect(promise).not.to.be.reverted;
            });
        });

        describe("Checks", function () {
            it("Should return the right revoked role state", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);
                await bulletLastPresale.revokeRole(roundManagerRole, grantee.address);

                const hasRevokedRole = await bulletLastPresale.hasRole(
                    roundManagerRole,
                    grantee.address
                );
                expect(hasRevokedRole).to.be.false;
            });
        });
    });

    describe("Renounce a role", function () {
        describe("Validations", function () {
            it("Should revert with the right error if called by a non grantee", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);

                const promise = bulletLastPresale.renounceRole(roundManagerRole, grantee.address);
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlBadConfirmation"
                    )
                    .withArgs();
            });
        });

        describe("Events", function () {
            it("Should emit the RoleRevoked event", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);

                const promise = (
                    bulletLastPresale.connect(grantee) as BulletLastPresale
                ).renounceRole(roundManagerRole, grantee.address);
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoleRevoked")
                    .withArgs(roundManagerRole, grantee.address, grantee.address);
            });
        });

        describe("Checks", function () {
            it("Should return the renounced role unset", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);
                await (bulletLastPresale.connect(grantee) as BulletLastPresale).renounceRole(
                    roundManagerRole,
                    grantee.address
                );

                const hasRole: boolean = await bulletLastPresale.hasRole(
                    roundManagerRole,
                    grantee.address
                );
                expect(hasRole).to.be.false;
            });
        });
    });

    describe("Pause the contract", function () {
        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async function () {
                const { bulletLastPresale, executor, defaultAdminRole } =
                    await loadFixture(deployFixture);

                const promise = (bulletLastPresale.connect(executor) as BulletLastPresale).pause();
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(executor.address, defaultAdminRole);
            });

            it("Should revert with the right error if paused twice", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                await bulletLastPresale.pause();

                const promise = bulletLastPresale.pause();
                await expect(promise)
                    .to.revertedWithCustomError(bulletLastPresale, "EnforcedPause")
                    .withArgs();
            });
        });

        describe("Events", function () {
            it("Should emit the Paused event", async function () {
                const { bulletLastPresale, deployer } = await loadFixture(deployFixture);

                const promise = bulletLastPresale.pause();
                await expect(promise)
                    .to.emit(bulletLastPresale, "Paused")
                    .withArgs(deployer.address);
            });
        });

        describe("Checks", function () {
            it("Should return the right paused state", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                await bulletLastPresale.pause();

                const paused = await bulletLastPresale.paused();
                expect(paused).to.be.true;
            });
        });
    });

    describe("Unpause the contract", function () {
        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async function () {
                const { bulletLastPresale, executor, defaultAdminRole } =
                    await loadFixture(deployFixture);

                await bulletLastPresale.pause();

                const promise = (
                    bulletLastPresale.connect(executor) as BulletLastPresale
                ).unpause();
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(executor.address, defaultAdminRole);
            });

            it("Should revert with the right error if not paused earlier", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const promise = bulletLastPresale.unpause();
                await expect(promise)
                    .to.revertedWithCustomError(bulletLastPresale, "ExpectedPause")
                    .withArgs();
            });

            it("Should revert with the right error if unpaused twice", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                await bulletLastPresale.pause();
                await bulletLastPresale.unpause();

                const promise = bulletLastPresale.unpause();
                await expect(promise)
                    .to.revertedWithCustomError(bulletLastPresale, "ExpectedPause")
                    .withArgs();
            });
        });

        describe("Events", function () {
            it("Should emit the Unpaused event", async function () {
                const { bulletLastPresale, deployer } = await loadFixture(deployFixture);

                await bulletLastPresale.pause();

                const promise = bulletLastPresale.unpause();
                await expect(promise)
                    .to.emit(bulletLastPresale, "Unpaused")
                    .withArgs(deployer.address);
            });
        });

        describe("Checks", function () {
            it("Should return the right paused state", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                await bulletLastPresale.pause();
                await bulletLastPresale.unpause();

                const paused = await bulletLastPresale.paused();
                expect(paused).to.be.false;
            });
        });
    });

    describe("Set the active round id", function () {
        const activeRoundId = 255n;

        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async () => {
                const { bulletLastPresale, executor, roundManagerRole } =
                    await loadFixture(deployFixture);

                const promise = (
                    bulletLastPresale.connect(executor) as BulletLastPresale
                ).setActiveRoundId(activeRoundId);
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(executor.address, roundManagerRole);
            });

            it("Should revert with the right error if setting the zero active round id", async () => {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const activeRoundId = 0n;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).setActiveRoundId(activeRoundId);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidActiveRoundId")
                    .withArgs(activeRoundId);
            });

            it("Should revert with the right error if setting the same active round id", async () => {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                await (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).setActiveRoundId(activeRoundId);

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).setActiveRoundId(activeRoundId);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidActiveRoundId")
                    .withArgs(activeRoundId);
            });
        });

        describe("Events", function () {
            it("Should emit the ActiveRoundIdSet event", async () => {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).setActiveRoundId(activeRoundId);
                await expect(promise)
                    .to.emit(bulletLastPresale, "ActiveRoundIdSet")
                    .withArgs(activeRoundId);
            });
        });

        describe("Checks", function () {
            it("Should return the right active round id", async () => {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const initialActiveRoundId: bigint = await bulletLastPresale.activeRoundId();

                await bulletLastPresale.setActiveRoundId(activeRoundId);

                const currentActiveRoundId: bigint = await bulletLastPresale.activeRoundId();
                expect(currentActiveRoundId).not.to.equal(initialActiveRoundId);
                expect(currentActiveRoundId).to.equal(activeRoundId);
            });
        });
    });

    describe("Check to set the active round id", function () {
        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async () => {
                const { bulletLastPresale, executor, roundManagerRole } =
                    await loadFixture(deployFixture);

                const promise = (
                    bulletLastPresale.connect(executor) as BulletLastPresale
                ).checkToSetActiveRoundId();
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(executor.address, roundManagerRole);
            });
        });

        describe("Events", function () {
            it("Should emit the ActiveRoundIdSet event", async () => {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                let startTime = BigInt(await time.latest()) + 4n;
                let price = 200;

                for (let i = 1; i <= 3; i++) {
                    const endTime = startTime + roundDuration;
                    await bulletLastPresale.createRound(i, startTime, endTime, price);

                    startTime = endTime + 1n;
                    price += 10;
                }

                for (let i = 1; i <= 3; i++) {
                    const [currentStartTime]: Round = await bulletLastPresale.rounds(i);
                    await time.increaseTo(currentStartTime);

                    const promise = (
                        bulletLastPresale.connect(roundManager) as BulletLastPresale
                    ).checkToSetActiveRoundId();
                    await expect(promise)
                        .to.emit(bulletLastPresale, "ActiveRoundIdSet")
                        .withArgs(i);
                }
            });
        });

        describe("Checks", function () {
            it("Should return the right active round id", async () => {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                let startTime = BigInt(await time.latest()) + 4n;
                let price = 200;

                for (let i = 1; i <= 3; i++) {
                    const endTime = startTime + roundDuration;
                    await bulletLastPresale.createRound(i, startTime, endTime, price);

                    startTime = endTime + 1n;
                    price += 10;
                }

                for (let i = 1; i <= 3; i++) {
                    const [currentStartTime]: Round = await bulletLastPresale.rounds(i);
                    await time.increaseTo(currentStartTime);

                    await (
                        bulletLastPresale.connect(roundManager) as BulletLastPresale
                    ).checkToSetActiveRoundId();
                    const currentActiveRoundId: bigint = await bulletLastPresale.activeRoundId();
                    expect(currentActiveRoundId).to.equal(i);
                }
            });
        });
    });

    describe("Set an allocated amount", function () {
        const newAllocatedSaleTokenAmount = allocatedSaleTokenAmount * 2n;

        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async () => {
                const { bulletLastPresale, executor, roundManagerRole } =
                    await loadFixture(deployFixture);

                const promise = (
                    bulletLastPresale.connect(executor) as BulletLastPresale
                ).setAllocatedAmount(newAllocatedSaleTokenAmount);
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(executor.address, roundManagerRole);
            });
        });

        describe("Events", function () {
            it("Should emit the AllocatedAmountSet event", async () => {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).setAllocatedAmount(newAllocatedSaleTokenAmount);
                await expect(promise)
                    .to.emit(bulletLastPresale, "AllocatedAmountSet")
                    .withArgs(newAllocatedSaleTokenAmount);
            });
        });

        describe("Checks", function () {
            it("Should return the right allocated amount", async () => {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const initialAllocatedAmount: bigint = await bulletLastPresale.allocatedAmount();

                await bulletLastPresale.setAllocatedAmount(newAllocatedSaleTokenAmount);

                const currentAllocatedAmount: bigint = await bulletLastPresale.allocatedAmount();
                expect(currentAllocatedAmount).not.to.equal(initialAllocatedAmount);
                expect(currentAllocatedAmount).to.equal(newAllocatedSaleTokenAmount);
            });
        });
    });

    describe("Set the treasury address", function () {
        const newTreasuryAddress = generateRandomAddress(ethers);

        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async () => {
                const { bulletLastPresale, executor, defaultAdminRole } =
                    await loadFixture(deployFixture);

                const promise = (
                    bulletLastPresale.connect(executor) as BulletLastPresale
                ).setTreasury(newTreasuryAddress);
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(executor.address, defaultAdminRole);
            });

            it("Should revert with the right error if passing the zero address", async () => {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const promise = bulletLastPresale.setTreasury(ethers.ZeroAddress);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroTreasury")
                    .withArgs();
            });
        });

        describe("Events", function () {
            it("Should emit the TreasurySet event", async () => {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const promise = bulletLastPresale.setTreasury(newTreasuryAddress);
                await expect(promise)
                    .to.emit(bulletLastPresale, "TreasurySet")
                    .withArgs(newTreasuryAddress);
            });
        });

        describe("Checks", function () {
            it("Should return the right treasury address", async () => {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const initialTreasuryAddress: string = await bulletLastPresale.treasury();

                await bulletLastPresale.setTreasury(newTreasuryAddress);

                const currentTreasuryAddress: string = await bulletLastPresale.treasury();
                expect(currentTreasuryAddress).not.to.equal(initialTreasuryAddress);
                expect(currentTreasuryAddress).to.equal(newTreasuryAddress);
            });
        });
    });

    describe("Create a round", function () {
        describe("Validations", function () {
            it("Should revert with the right error if called by a non admin", async function () {
                const { bulletLastPresale, executor, roundManagerRole } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                const promise = (
                    bulletLastPresale.connect(executor) as BulletLastPresale
                ).createRound(roundId, startTime, endTime, roundPrice);
                await expect(promise)
                    .to.be.revertedWithCustomError(
                        bulletLastPresale,
                        "AccessControlUnauthorizedAccount"
                    )
                    .withArgs(executor.address, roundManagerRole);
            });

            it("Should revert with the right error if passing the zero round id", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(0n, startTime, endTime, roundPrice);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroRoundId")
                    .withArgs();
            });

            it("Should revert with the right error if passing the zero start time", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(roundId, 0n, endTime, roundPrice);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidTimePeriod")
                    .withArgs(0n, endTime);
            });

            it("Should revert with the right error if passing the zero end time", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(roundId, startTime, 0n, roundPrice);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidTimePeriod")
                    .withArgs(startTime, 0n);
            });

            it("Should revert with the right error if passing the end time equal to the start time", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(roundId, startTime, endTime, roundPrice);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidTimePeriod")
                    .withArgs(startTime, endTime);
            });

            it("Should revert with the right error if passing the end time higher than the start time", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime - 1n;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(roundId, startTime, endTime, roundPrice);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidTimePeriod")
                    .withArgs(startTime, endTime);
            });

            it("Should revert with the right error if passing the zero price", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(roundId, startTime, endTime, 0n);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroPrice")
                    .withArgs();
            });
        });

        describe("Events", function () {
            it("Should emit the RoundCreated event", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(roundId, startTime, endTime, roundPrice);
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoundCreated")
                    .withArgs(roundId, startTime, endTime, roundPrice);
            });

            it("Should emit the RoundUpdated event", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const initialStartTime = BigInt(await time.latest());
                const initialEndTime = initialStartTime + roundDuration;
                const initialRoundPrice = roundPrice;

                await (bulletLastPresale.connect(roundManager) as BulletLastPresale).createRound(
                    roundId,
                    initialStartTime,
                    initialEndTime,
                    initialRoundPrice
                );

                const newStartTime = initialStartTime + 1n;
                const newEndTime = initialEndTime + 1n;
                const newRoundPrice = initialRoundPrice + 1n;

                const promise = (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).createRound(roundId, newStartTime, newEndTime, newRoundPrice);
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoundUpdated")
                    .withArgs(roundId, newStartTime, newEndTime, newRoundPrice);
            });
        });

        describe("Checks", function () {
            it("Should return the right round if creating a new round", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await (bulletLastPresale.connect(roundManager) as BulletLastPresale).createRound(
                    roundId,
                    startTime,
                    endTime,
                    roundPrice
                );

                const [currentStartTime, currentEndTime, currentPrice]: Round =
                    await bulletLastPresale.rounds(roundId);
                expect(currentStartTime).to.equal(startTime);
                expect(currentEndTime).to.equal(endTime);
                expect(currentPrice).to.equal(roundPrice);
            });

            it("Should return the right active round if creating a new round", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await (bulletLastPresale.connect(roundManager) as BulletLastPresale).createRound(
                    roundId,
                    startTime,
                    endTime,
                    roundPrice
                );
                await (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).setActiveRoundId(roundId);

                const [currentStartTime, currentEndTime, currentPrice]: Round =
                    await bulletLastPresale.getActiveRound();
                expect(currentStartTime).to.equal(startTime);
                expect(currentEndTime).to.equal(endTime);
                expect(currentPrice).to.equal(roundPrice);
            });

            it("Should return the right round if updating an existing round", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const initialStartTime = BigInt(await time.latest());
                const initialEndTime = initialStartTime + roundDuration;
                const initialRoundPrice = roundPrice;

                await (bulletLastPresale.connect(roundManager) as BulletLastPresale).createRound(
                    roundId,
                    initialStartTime,
                    initialEndTime,
                    initialRoundPrice
                );

                const newStartTime = initialStartTime + 1n;
                const newEndTime = initialEndTime + 1n;
                const newRoundPrice = initialRoundPrice + 1n;

                await bulletLastPresale.createRound(
                    roundId,
                    newStartTime,
                    newEndTime,
                    newRoundPrice
                );

                const [currentStartTime, currentEndTime, currentPrice]: Round =
                    await bulletLastPresale.rounds(roundId);
                expect(currentStartTime).not.to.equal(initialStartTime);
                expect(currentStartTime).to.equal(newStartTime);
                expect(currentEndTime).not.to.equal(initialEndTime);
                expect(currentEndTime).to.equal(newEndTime);
                expect(currentPrice).not.to.equal(initialRoundPrice);
                expect(currentPrice).to.equal(newRoundPrice);
            });

            it("Should return the right active round if updating an existing round", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const initialStartTime = BigInt(await time.latest());
                const initialEndTime = initialStartTime + roundDuration;
                const initialRoundPrice = roundPrice;

                await (bulletLastPresale.connect(roundManager) as BulletLastPresale).createRound(
                    roundId,
                    initialStartTime,
                    initialEndTime,
                    initialRoundPrice
                );

                const newStartTime = initialStartTime + 1n;
                const newEndTime = initialEndTime + 1n;
                const newRoundPrice = initialRoundPrice + 1n;

                await bulletLastPresale.createRound(
                    roundId,
                    newStartTime,
                    newEndTime,
                    newRoundPrice
                );
                await (
                    bulletLastPresale.connect(roundManager) as BulletLastPresale
                ).setActiveRoundId(roundId);

                const [currentStartTime, currentEndTime, currentPrice]: Round =
                    await bulletLastPresale.getActiveRound();
                expect(currentStartTime).not.to.equal(initialStartTime);
                expect(currentStartTime).to.equal(newStartTime);
                expect(currentEndTime).not.to.equal(initialEndTime);
                expect(currentEndTime).to.equal(newEndTime);
                expect(currentPrice).not.to.equal(initialRoundPrice);
                expect(currentPrice).to.equal(newRoundPrice);
            });

            it("Should return the right round id if creating a new round", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await (bulletLastPresale.connect(roundManager) as BulletLastPresale).createRound(
                    roundId,
                    startTime,
                    endTime,
                    roundPrice
                );

                const currentRoundId: bigint = await bulletLastPresale.roundIds(0n);
                expect(currentRoundId).to.equal(roundId);
            });

            it("Should return the right round id if updating an existing round", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const initialStartTime = BigInt(await time.latest());
                const initialEndTime = initialStartTime + roundDuration;
                const initialRoundPrice = roundPrice;

                await (bulletLastPresale.connect(roundManager) as BulletLastPresale).createRound(
                    roundId,
                    initialStartTime,
                    initialEndTime,
                    initialRoundPrice
                );

                const newStartTime = initialStartTime + 1n;
                const newEndTime = initialEndTime + 1n;
                const newRoundPrice = initialRoundPrice + 1n;

                await bulletLastPresale.createRound(
                    roundId,
                    newStartTime,
                    newEndTime,
                    newRoundPrice
                );

                const currentRoundId: bigint = await bulletLastPresale.roundIds(0n);
                expect(currentRoundId).to.equal(roundId);
            });

            it("Should return the right round id count", async function () {
                const { bulletLastPresale, roundManager } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                for (let i = 1; i <= 3; i++) {
                    await (
                        bulletLastPresale.connect(roundManager) as BulletLastPresale
                    ).createRound(i, startTime, endTime, roundPrice);

                    const currentRoundIdCount: bigint = await bulletLastPresale.getRoundIdCount();
                    expect(currentRoundIdCount).to.equal(i);
                }
            });
        });
    });

    describe("Buy with Ether", function () {
        describe("Validations", function () {
            it("Should revert with the right error if paused", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                await bulletLastPresale.pause();

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await expect(promise).to.be.revertedWithCustomError(
                    bulletLastPresale,
                    "EnforcedPause"
                );
            });

            it("Should revert with the right error if having no round", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "RoundNotFound")
                    .withArgs();
            });

            it("Should revert with the right error if not reaching the round start", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest()) + 4n;
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidBuyPeriod")
                    .withArgs(anyValue, startTime, endTime);
            });

            it("Should revert with the right error if reaching the round end", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await time.increaseTo(endTime);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidBuyPeriod")
                    .withArgs(anyValue, startTime, endTime);
            });

            it.skip("Should revert with the right error if buying amount below the minimum", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const lowSaleTokenAmount = minSaleTokenAmount - 1n;
                const lowEtherAmount = minEtherAmount - 1n;

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    lowSaleTokenAmount,
                    { value: lowEtherAmount }
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "TooLowEtherBuyAmount")
                    .withArgs(lowEtherAmount, lowSaleTokenAmount);
            });

            it("Should revert with the right error if buying amount above the maximum", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const highSaleTokenAmount = maxSaleTokenAmount * 2n;
                const highEtherAmount = maxEtherAmount * 2n;

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    highSaleTokenAmount,
                    { value: highEtherAmount }
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "TooHighEtherBuyAmount")
                    .withArgs(highEtherAmount, highSaleTokenAmount);
            });

            it("Should revert with the right error if passing insufficient Ether amount", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const lowEtherAmount = minEtherAmount - 1n;

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: lowEtherAmount }
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InsufficientEtherAmount")
                    .withArgs(minEtherAmount, lowEtherAmount);
            });

            it.skip("Should revert with the right error if having an insufficient allocated amount", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    maxSaleTokenAmount,
                    { value: maxEtherAmount }
                );

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InsufficientAllocatedAmount")
                    .withArgs(minSaleTokenAmount, 0n);
            });

            it.skip("Should revert with the right error if unable to send Ether to the caller", async function () {
                const { bulletLastPresale, reverter, reverterAddress } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const highEtherAmount = minEtherAmount + 1n;

                const promise = reverter.buyWithEther(minSaleTokenAmount, {
                    value: highEtherAmount,
                });
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "EtherTransferFailed")
                    .withArgs(reverterAddress, highEtherAmount - minEtherAmount);
            });
        });

        describe("Events", function () {
            it("Should emit the BoughtWithEther event if buying the minimum amount", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithEther")
                    .withArgs(user.address, roundId, minSaleTokenAmount, minEtherAmount);
            });

            it.skip("Should emit the BoughtWithEther event if buying the maximum amount", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    maxSaleTokenAmount,
                    { value: maxEtherAmount }
                );
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithEther")
                    .withArgs(user.address, roundId, maxSaleTokenAmount, maxEtherAmount);
            });
        });

        describe("Checks", function () {
            it("Should return the right Ether and token balances", async function () {
                const { bulletLastPresale, bulletLastToken, user, treasury } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await expect(promise).to.changeEtherBalances(
                    [user, treasury, bulletLastPresale],
                    [-minEtherAmount, minEtherAmount, 0n]
                );
                await expect(promise).to.changeTokenBalances(
                    bulletLastToken,
                    [user, treasury, bulletLastPresale],
                    [minSaleTokenPartialAmount, -minSaleTokenPartialAmount, 0n]
                );
            });

            it("Should return the right Ether balances if having exceeded Ether sent", async function () {
                const { bulletLastPresale, user, treasury } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const highEtherAmount = maxEtherAmount;

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: highEtherAmount }
                );
                await expect(promise).to.changeEtherBalances(
                    [user, treasury, bulletLastPresale],
                    [-minEtherAmount, minEtherAmount, 0n]
                );
            });

            it("Should return the right allocated amount", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                for (let i = 1n; i <= vestingPeriods; i++) {
                    await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                        minSaleTokenAmount,
                        { value: minEtherAmount }
                    );

                    const currentAllocatedAmount: bigint =
                        await bulletLastPresale.allocatedAmount();
                    expect(currentAllocatedAmount).to.equal(
                        allocatedSaleTokenAmount - minSaleTokenAmount * i
                    );
                }
            });

            it("Should return the right user vestings if buying once", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [currentAmount, currentStartTime]: Vesting =
                        await bulletLastPresale.userVestings(user.address, roundId, i);
                    expect(currentAmount).to.equal(minSaleTokenPartialAmount);
                    expect(currentStartTime).to.equal(startTime + (i + 1n) * vestingDuration);
                }
            });

            it("Should return the right user vestings if buying twice", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [currentAmount, currentStartTime]: Vesting =
                        await bulletLastPresale.userVestings(user.address, roundId, i);
                    expect(currentAmount).to.equal(minSaleTokenPartialAmount * 2n);
                    expect(currentStartTime).to.equal(startTime + (i + 1n) * vestingDuration);
                }
            });

            it("Should return the right claimable amount if reaching the next vesting period", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    user.address
                );
                expect(claimableAmount).to.equal(0n);

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                        user.address,
                        roundId,
                        i
                    );
                    await time.increaseTo(currentStartTime);
                    const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                        user.address
                    );
                    expect(claimableAmount).to.equal(minSaleTokenPartialAmount * (i + 1n));
                }
            });
        });
    });

    describe("Buy with USDT", function () {
        describe("Validations", function () {
            it("Should revert with the right error if paused", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                await bulletLastPresale.pause();

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise).to.be.revertedWithCustomError(
                    bulletLastPresale,
                    "EnforcedPause"
                );
            });

            it("Should revert with the right error if having no round", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "RoundNotFound")
                    .withArgs();
            });

            it("Should revert with the right error if not reaching the round start", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest()) + 4n;
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidBuyPeriod")
                    .withArgs(anyValue, startTime, endTime);
            });

            it("Should revert with the right error if reaching the round end", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await time.increaseTo(endTime);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "InvalidBuyPeriod")
                    .withArgs(anyValue, startTime, endTime);
            });

            it("Should revert with the right error if buying amount below the minimum", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const lowSaleTokenAmount = minSaleTokenAmount - 1n;
                const lowUSDTAmount = minUSDTAmount - 1n;

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    lowSaleTokenAmount
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "TooLowUSDTBuyAmount")
                    .withArgs(lowUSDTAmount, lowSaleTokenAmount);
            });

            it("Should revert with the right error if buying amount above the maximum", async function () {
                const { bulletLastPresale, user } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);
                await bulletLastPresale.setAllocatedAmount(allocatedSaleTokenAmount + 1n);

                const highSaleTokenAmount = maxSaleTokenAmount * 2n;
                const highUSDTAmount = maxUSDTAmount * 2n;

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    highSaleTokenAmount
                );
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "TooHighUSDTBuyAmount")
                    .withArgs(highUSDTAmount, highSaleTokenAmount);
            });
        });

        describe("Events", function () {
            it("Should emit the BoughtWithUSDT event if buying the minimum amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, minUSDTAmount);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithUSDT")
                    .withArgs(user.address, roundId, minSaleTokenAmount, minUSDTAmount);
            });

            it("Should emit the BoughtWithUSDT event if buying the maximum amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    maxSaleTokenAmount
                );
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithUSDT")
                    .withArgs(user.address, roundId, maxSaleTokenAmount, maxUSDTAmount);
            });
        });

        describe("Checks", function () {
            it("Should return the right tokens balances", async function () {
                const {
                    bulletLastPresale,
                    bulletLastPresaleAddress,
                    bulletLastToken,
                    usdtToken,
                    user,
                    treasury,
                } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, minUSDTAmount);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise).to.changeTokenBalances(
                    usdtToken,
                    [user, treasury, bulletLastPresale],
                    [-minUSDTAmount, minUSDTAmount, 0n]
                );
                await expect(promise).to.changeTokenBalances(
                    bulletLastToken,
                    [user, treasury, bulletLastPresale],
                    [minSaleTokenPartialAmount, -minSaleTokenPartialAmount, 0n]
                );
            });

            it("Should return the right allocated amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);

                for (let i = 1n; i <= vestingPeriods; i++) {
                    await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                        minSaleTokenAmount
                    );

                    const currentAllocatedAmount: bigint =
                        await bulletLastPresale.allocatedAmount();
                    expect(currentAllocatedAmount).to.equal(
                        allocatedSaleTokenAmount - minSaleTokenAmount * i
                    );
                }
            });

            it("Should return the right user vestings if buying once", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, minUSDTAmount);

                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [currentAmount, currentStartTime]: Vesting =
                        await bulletLastPresale.userVestings(user.address, roundId, i);
                    expect(currentAmount).to.equal(minSaleTokenPartialAmount);
                    expect(currentStartTime).to.equal(startTime + (i + 1n) * vestingDuration);
                }
            });

            it("Should return the right user vestings if buying twice", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, minUSDTAmount * 2n);

                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [currentAmount, currentStartTime]: Vesting =
                        await bulletLastPresale.userVestings(user.address, roundId, i);
                    expect(currentAmount).to.equal(minSaleTokenPartialAmount * 2n);
                    expect(currentStartTime).to.equal(startTime + (i + 1n) * vestingDuration);
                }
            });

            it("Should return the right claimable amount if reaching the next vesting period", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, minUSDTAmount);

                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    user.address
                );
                expect(claimableAmount).to.equal(0n);

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                        user.address,
                        roundId,
                        i
                    );
                    await time.increaseTo(currentStartTime);

                    const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                        user.address
                    );
                    expect(claimableAmount).to.equal(minSaleTokenPartialAmount * (i + 1n));
                }
            });
        });
    });

    describe("Claim", function () {
        describe("Validations", function () {
            it("Should revert with the right error if paused", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    user.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime);

                await bulletLastPresale.pause();

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).claim();
                await expect(promise).to.be.revertedWithCustomError(
                    bulletLastPresale,
                    "EnforcedPause"
                );
            });

            it("Should return the right error if having the zero claimable amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    user.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime - 2n);

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).claim();
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroClaimableAmount")
                    .withArgs(user.address);
            });

            it("Should return the right error if claiming the same vesting period twice", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    user.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime);

                await (bulletLastPresale.connect(user) as BulletLastPresale).claim();

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).claim();
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroClaimableAmount")
                    .withArgs(user.address);
            });
        });

        describe("Events", function () {
            it("Should emit the Claimed event", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    user.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime);

                const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    user.address
                );

                const promise = (bulletLastPresale.connect(user) as BulletLastPresale).claim();
                await expect(promise)
                    .to.emit(bulletLastPresale, "Claimed")
                    .withArgs(user.address, claimableAmount);
            });
        });

        describe("Checks", function () {
            it("Should return the right token balances", async function () {
                const {
                    bulletLastPresale,
                    bulletLastPresaleAddress,
                    bulletLastToken,
                    usdtToken,
                    user,
                    treasury,
                } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                        user.address,
                        roundId,
                        i
                    );
                    await time.increaseTo(currentStartTime);

                    const currentClaimableAmount: bigint =
                        await bulletLastPresale.getClaimableAmount(user.address);

                    const promise = (bulletLastPresale.connect(user) as BulletLastPresale).claim();
                    await expect(promise).to.changeTokenBalances(
                        bulletLastToken,
                        [user, treasury, bulletLastPresale],
                        [currentClaimableAmount, -currentClaimableAmount, 0n]
                    );
                }
            });

            it("Should return the right claimable amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtToken, user } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtToken.connect(user).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(user) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                for (let i = 0n; i < vestingPeriods; i++) {
                    const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                        user.address,
                        roundId,
                        i
                    );
                    await time.increaseTo(currentStartTime);

                    const initialClaimableAmount: bigint =
                        await bulletLastPresale.getClaimableAmount(user.address);
                    await (bulletLastPresale.connect(user) as BulletLastPresale).claim();

                    const currentClaimableAmount: bigint =
                        await bulletLastPresale.getClaimableAmount(user.address);
                    expect(currentClaimableAmount).not.to.equal(initialClaimableAmount);
                    expect(currentClaimableAmount).to.equal(0n);
                }
            });
        });
    });
});
