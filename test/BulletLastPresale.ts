import {
    impersonateAccount,
    loadFixture,
    setBalance,
    time,
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { BulletLastPresale, BulletLastToken } from "../typechain-types";

type Round = [bigint, bigint, bigint, bigint];
type Vesting = [bigint, bigint];

describe("BulletLastPresale", function () {
    const version = ethers.encodeBytes32String("1.0.0");
    const roundId = 1n;
    const roundDuration = 60n;
    const roundPrice = 200n; // 0.02 LEAD/USD
    const minSaleTokenAmount = ethers.parseUnits("5000", 18); // 5,000 LEAD
    const minSaleTokenPartialAmount = minSaleTokenAmount / 4n;
    const maxSaleTokenAmount = ethers.parseUnits("50000", 18); // 50,000 LEAD
    const minEtherAmount = ethers.parseEther("0.04"); // 0.04 ETH
    const maxEtherAmount = ethers.parseEther("0.4"); // 0.0 ETH
    const minUSDTAmount = ethers.parseUnits("100", 6); // 100 USDT
    const maxUSDTAmount = ethers.parseUnits("1000", 6); // 1,000 USDT
    const priceFeedRoundAnswers: Array<[bigint, bigint]> = [
        [1n, 200_000_000_000n], // 1 round => 2,000 ETH/USD
        [2n, 250_000_000_000n], // 2 round => 2,500 ETH/USD
    ];

    async function deployFixture() {
        const [deployer, executor, grantee, roundManager, buyer] = await ethers.getSigners();

        const treasuryAddress = "0x3951b3a254a4285683abc08e63b2e632a4aa3752";
        await impersonateAccount(treasuryAddress);
        await setBalance(treasuryAddress, ethers.parseEther("10000"));
        const treasury = await ethers.provider.getSigner(treasuryAddress);

        const BulletLastToken = await ethers.getContractFactory("BulletLastToken");
        const bulletLastToken = await BulletLastToken.deploy(treasury.address);
        const bulletLastTokenAddress = await bulletLastToken.getAddress();

        const EtherPriceFeedMock = await ethers.getContractFactory("EtherPriceFeedMock");
        const etherPriceFeedMock = await EtherPriceFeedMock.deploy(priceFeedRoundAnswers);
        const etherPriceFeedMockAddress = await etherPriceFeedMock.getAddress();

        const USDTTokenMock = await ethers.getContractFactory("USDTTokenMock");
        const usdtTokenMock = await USDTTokenMock.deploy(buyer.address, maxUSDTAmount);
        const usdtTokenMockAddress = await usdtTokenMock.getAddress();

        const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
        const bulletLastPresale = await upgrades.deployProxy(BulletLastPresale, [
            bulletLastTokenAddress,
            etherPriceFeedMockAddress,
            usdtTokenMockAddress,
            treasury.address,
        ]);
        const bulletLastPresaleAddress = await bulletLastPresale.getAddress();

        const defaultAdminRole = await bulletLastPresale.DEFAULT_ADMIN_ROLE();
        const roundManagerRole = await bulletLastPresale.ROUND_MANAGER_ROLE();

        await bulletLastPresale.grantRole(roundManagerRole, roundManager);
        await (bulletLastToken.connect(treasury) as BulletLastToken).approve(
            bulletLastPresaleAddress,
            maxSaleTokenAmount
        );

        return {
            bulletLastPresale,
            bulletLastPresaleAddress,
            bulletLastToken,
            bulletLastTokenAddress,
            etherPriceFeedMock,
            etherPriceFeedMockAddress,
            usdtTokenMock,
            usdtTokenMockAddress,
            deployer,
            executor,
            grantee,
            roundManager,
            treasury,
            buyer,
            defaultAdminRole,
            roundManagerRole,
        };
    }

    describe("Deploy the contract", function () {
        describe("Validations", function () {
            it("Should revert with the right error if passing the zero vesting token address", async function () {
                const {
                    bulletLastPresale,
                    etherPriceFeedMockAddress,
                    usdtTokenMockAddress,
                    treasury,
                } = await loadFixture(deployFixture);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                const promise = upgrades.deployProxy(BulletLastPresale, [
                    ethers.ZeroAddress,
                    etherPriceFeedMockAddress,
                    usdtTokenMockAddress,
                    treasury.address,
                ]);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroSaleToken")
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

            it("Should return the right admin role managing the  manager role", async function () {
                const { bulletLastPresale, defaultAdminRole, roundManagerRole } =
                    await loadFixture(deployFixture);

                const currentAdminRole: string =
                    await bulletLastPresale.getRoleAdmin(roundManagerRole);
                expect(currentAdminRole).to.equal(defaultAdminRole);
            });

            it("Should return the right sale token address", async function () {
                const { bulletLastPresale, bulletLastTokenAddress } =
                    await loadFixture(deployFixture);

                const currentSaleTokenAddress: string = await bulletLastPresale.saleToken();
                expect(currentSaleTokenAddress).to.equal(bulletLastTokenAddress);
            });

            it("Should return the right treasury address", async function () {
                const { bulletLastPresale, treasury } = await loadFixture(deployFixture);

                const currentTreasuryAddress: string = await bulletLastPresale.treasury();
                expect(currentTreasuryAddress).to.equal(treasury.address);
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

    describe("Create a round", function () {
        describe("Validations", function () {});

        describe("Events", function () {
            it("Should emit the RoundCreated event", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                const promise = bulletLastPresale.createRound(
                    roundId,
                    startTime,
                    endTime,
                    roundPrice
                );
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoundCreated")
                    .withArgs(roundId, startTime, endTime, roundPrice);
            });
        });

        describe("Checks", function () {
            it("Should return the right round", async function () {
                const { bulletLastPresale } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);

                const [currentRoundId, currentStartTime, currentEndTime, currentPrice]: Round =
                    await bulletLastPresale.rounds(roundId);
                expect(currentRoundId).to.equal(roundId);
                expect(currentStartTime).to.equal(startTime);
                expect(currentEndTime).to.equal(endTime);
                expect(currentPrice).to.equal(roundPrice);
            });
        });
    });

    describe("Buy with Ether", function () {
        describe("Validations", function () {});

        describe("Events", function () {
            it("Should emit the BoughtWithEther event if buying the minimum amount", async function () {
                const { bulletLastPresale, buyer } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (
                    bulletLastPresale.connect(buyer) as BulletLastPresale
                ).buyWithEther(minSaleTokenAmount, { value: minEtherAmount });
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithEther")
                    .withArgs(buyer.address, roundId, minSaleTokenAmount, minEtherAmount);
            });

            it("Should emit the BoughtWithEther event if buying the maximum amount", async function () {
                const { bulletLastPresale, buyer } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (
                    bulletLastPresale.connect(buyer) as BulletLastPresale
                ).buyWithEther(maxSaleTokenAmount, { value: maxEtherAmount });
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithEther")
                    .withArgs(buyer.address, roundId, maxSaleTokenAmount, maxEtherAmount);
            });
        });

        describe("Checks", function () {
            it("Should return the right Ether balances", async function () {
                const { bulletLastPresale, buyer, treasury } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                const promise = (
                    bulletLastPresale.connect(buyer) as BulletLastPresale
                ).buyWithEther(minSaleTokenAmount, { value: maxEtherAmount });
                await expect(promise).to.changeEtherBalances(
                    [buyer, treasury, bulletLastPresale],
                    [-minEtherAmount, minEtherAmount, 0n]
                );
            });

            it("Should return the right user vestings", async function () {
                const { bulletLastPresale, buyer } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;
                const vestingDuration: bigint = await bulletLastPresale.VESTING_DURATION();

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );

                for (let i = 0n; i < 3n; i++) {
                    const [currentAmount, currentStartTime]: Vesting =
                        await bulletLastPresale.userVestings(buyer.address, roundId, i);
                    expect(currentAmount).to.equal(minSaleTokenPartialAmount);
                    expect(currentStartTime).to.equal(startTime + (i + 1n) * vestingDuration);
                }
            });

            it("Should return the right claimable amount if reaching the next vesting period", async function () {
                const { bulletLastPresale, buyer } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithEther(
                    minSaleTokenAmount,
                    { value: minEtherAmount }
                );
                const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    buyer.address,
                    roundId
                );
                expect(claimableAmount).to.equal(0n);

                for (let i = 0n; i < 3n; i++) {
                    const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                        buyer.address,
                        roundId,
                        i
                    );
                    await time.increaseTo(currentStartTime);
                    const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                        buyer.address,
                        roundId
                    );
                    expect(claimableAmount).to.equal(minSaleTokenPartialAmount * (i + 1n));
                }
            });
        });
    });

    describe("Buy with USDT", function () {
        describe("Validations", function () {});

        describe("Events", function () {
            it("Should emit the BoughtWithUSDT event if buying the minimum amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, minUSDTAmount);

                const promise = (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithUSDT")
                    .withArgs(buyer.address, roundId, minSaleTokenAmount, minUSDTAmount);
            });

            it("Should emit the BoughtWithUSDT event if buying the maximum amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, maxUSDTAmount);

                const promise = (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    maxSaleTokenAmount
                );
                await expect(promise)
                    .to.emit(bulletLastPresale, "BoughtWithUSDT")
                    .withArgs(buyer.address, roundId, maxSaleTokenAmount, maxUSDTAmount);
            });
        });

        describe("Checks", function () {
            it("Should return the right tokens balances", async function () {
                const {
                    bulletLastPresale,
                    bulletLastPresaleAddress,
                    bulletLastToken,
                    usdtTokenMock,
                    buyer,
                    treasury,
                } = await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, minUSDTAmount);

                const promise = (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );
                await expect(promise).to.changeTokenBalances(
                    usdtTokenMock,
                    [buyer, treasury, bulletLastPresale],
                    [-minUSDTAmount, minUSDTAmount, 0n]
                );
                await expect(promise).to.changeTokenBalances(
                    bulletLastToken,
                    [buyer, treasury, bulletLastPresale],
                    [minSaleTokenPartialAmount, -minSaleTokenPartialAmount, 0n]
                );
            });

            it("Should return the right user vestings", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;
                const vestingDuration: bigint = await bulletLastPresale.VESTING_DURATION();

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, minUSDTAmount);

                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                for (let i = 0n; i < 3n; i++) {
                    const [currentAmount, currentStartTime]: Vesting =
                        await bulletLastPresale.userVestings(buyer.address, roundId, i);
                    expect(currentAmount).to.equal(minSaleTokenPartialAmount);
                    expect(currentStartTime).to.equal(startTime + (i + 1n) * vestingDuration);
                }
            });

            it("Should return the right claimable amount if reaching the next vesting period", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, minUSDTAmount);

                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    buyer.address,
                    roundId
                );
                expect(claimableAmount).to.equal(0n);

                for (let i = 0n; i < 3n; i++) {
                    const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                        buyer.address,
                        roundId,
                        i
                    );
                    await time.increaseTo(currentStartTime);

                    const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                        buyer.address,
                        roundId
                    );
                    expect(claimableAmount).to.equal(minSaleTokenPartialAmount * (i + 1n));
                }
            });
        });
    });

    describe("Claim", function () {
        describe("Validations", function () {
            it("Should return the right error if having the zero claimable amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    buyer.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime - 2n);

                const promise = bulletLastPresale.claim(buyer.address, roundId);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroClaimableAmount")
                    .withArgs(buyer.address, roundId);
            });

            it("Should return the right error if claiming the same vesting period twice", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    buyer.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime);

                await bulletLastPresale.claim(buyer.address, roundId);

                const promise = bulletLastPresale.claim(buyer.address, roundId);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroClaimableAmount")
                    .withArgs(buyer.address, roundId);
            });
        });

        describe("Events", function () {
            it("Should emit the Claimed event", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    buyer.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime);

                const claimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    buyer.address,
                    roundId
                );

                const promise = bulletLastPresale.claim(buyer.address, roundId);
                await expect(promise)
                    .to.emit(bulletLastPresale, "Claimed")
                    .withArgs(buyer.address, roundId, claimableAmount);
            });
        });

        describe("Checks", function () {
            it("Should return the right claimable amount", async function () {
                const { bulletLastPresale, bulletLastPresaleAddress, usdtTokenMock, buyer } =
                    await loadFixture(deployFixture);

                const startTime = BigInt(await time.latest());
                const endTime = startTime + roundDuration;

                await bulletLastPresale.createRound(roundId, startTime, endTime, roundPrice);
                await bulletLastPresale.setActiveRoundId(roundId);

                await usdtTokenMock.connect(buyer).approve(bulletLastPresaleAddress, maxUSDTAmount);
                await (bulletLastPresale.connect(buyer) as BulletLastPresale).buyWithUSDT(
                    minSaleTokenAmount
                );

                const [_, currentStartTime]: Vesting = await bulletLastPresale.userVestings(
                    buyer.address,
                    roundId,
                    0n
                );
                await time.increaseTo(currentStartTime);

                const initialClaimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    buyer.address,
                    roundId
                );
                await bulletLastPresale.claim(buyer.address, roundId);

                const currentClaimableAmount: bigint = await bulletLastPresale.getClaimableAmount(
                    buyer.address,
                    roundId
                );
                expect(currentClaimableAmount).not.to.equal(initialClaimableAmount);
                expect(currentClaimableAmount).to.equal(0n);
            });
        });
    });
});
