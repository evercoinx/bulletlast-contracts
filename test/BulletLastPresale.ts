import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { BulletLastPresale } from "../typechain-types";
import { generateRandomAddress } from "../utils/account";

describe("BulletLastPresale", function () {
    const version = ethers.encodeBytes32String("1.0.0");

    async function deployBulletLastPresaleFixture() {
        const [deployer, executor, grantee, roundManager] = await ethers.getSigners();

        const BulletLast = await ethers.getContractFactory("BulletLast");
        const bulletLast = await BulletLast.deploy(deployer.address);
        const bulletLastAddress = await bulletLast.getAddress();

        const etherPriceFeedAddress = generateRandomAddress(ethers);
        const usdtTokenAddress = generateRandomAddress(ethers);

        const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
        const bulletLastPresale = await upgrades.deployProxy(BulletLastPresale, [
            bulletLastAddress,
            etherPriceFeedAddress,
            usdtTokenAddress,
        ]);
        const bulletLastPresaleAddress = await bulletLastPresale.getAddress();

        const defaultAdminRole = await bulletLastPresale.DEFAULT_ADMIN_ROLE();
        const roundManagerRole = await bulletLastPresale.ROUND_MANAGER_ROLE();

        await bulletLastPresale.grantRole(roundManagerRole, roundManager);

        return {
            bulletLastPresale,
            bulletLastPresaleAddress,
            bulletLast,
            bulletLastAddress,
            etherPriceFeedAddress,
            usdtTokenAddress,
            deployer,
            executor,
            grantee,
            roundManager,
            defaultAdminRole,
            roundManagerRole,
        };
    }

    describe("Deploy the contract", function () {
        describe("Validations", function () {
            it("Should revert with the right error if passing the zero vesting token address", async function () {
                const { bulletLastPresale, etherPriceFeedAddress, usdtTokenAddress } =
                    await loadFixture(deployBulletLastPresaleFixture);

                const BulletLastPresale = await ethers.getContractFactory("BulletLastPresale");
                const promise = upgrades.deployProxy(BulletLastPresale, [
                    ethers.ZeroAddress,
                    etherPriceFeedAddress,
                    usdtTokenAddress,
                ]);
                await expect(promise)
                    .to.be.revertedWithCustomError(bulletLastPresale, "ZeroSaleToken")
                    .withArgs();
            });
        });

        describe("Checks", function () {
            it("Should return the right version", async function () {
                const { bulletLastPresale } = await loadFixture(deployBulletLastPresaleFixture);

                const currentVersion: string = await bulletLastPresale.VERSION();
                expect(currentVersion).to.equal(version);
            });

            it("Should return the default admin role set for the deployer", async function () {
                const { bulletLastPresale, deployer, defaultAdminRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

                const hasDefaultAdminRole: boolean = await bulletLastPresale.hasRole(
                    defaultAdminRole,
                    deployer.address
                );
                expect(hasDefaultAdminRole).to.be.true;
            });

            it("Should return the right admin role managing the  manager role", async function () {
                const { bulletLastPresale, defaultAdminRole, roundManagerRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

                const currentAdminRole: string =
                    await bulletLastPresale.getRoleAdmin(roundManagerRole);
                expect(currentAdminRole).to.equal(defaultAdminRole);
            });

            it("Should return the right sale token address", async function () {
                const { bulletLastPresale, bulletLastAddress } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

                const currentSaleToken: string = await bulletLastPresale.saleToken();
                expect(currentSaleToken).to.equal(bulletLastAddress);
            });
        });
    });

    describe("Upgrade the contract", function () {
        describe("Checks", function () {
            it("Should return a new address of the implementation if upgrading the contract", async function () {
                const { bulletLastPresaleAddress } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
                const { bulletLastPresaleAddress } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
                const { bulletLastPresaleAddress, executor } = await loadFixture(
                    deployBulletLastPresaleFixture
                );
                const iface = new ethers.Interface(["function foo(uint256)"]);

                const promise = executor.sendTransaction({
                    to: bulletLastPresaleAddress,
                    data: iface.encodeFunctionData("foo", [1n]),
                });
                await expect(promise).to.be.revertedWithoutReason();
            });

            it("Should revert without a reason if sending arbitrary data", async function () {
                const { bulletLastPresaleAddress, executor } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
                    await loadFixture(deployBulletLastPresaleFixture);

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
                    await loadFixture(deployBulletLastPresaleFixture);

                const promise = bulletLastPresale.grantRole(roundManagerRole, grantee.address);
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoleGranted")
                    .withArgs(roundManagerRole, grantee.address, deployer.address);
            });
        });

        describe("Checks", function () {
            it("Should return the right granted role state", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
                    await loadFixture(deployBulletLastPresaleFixture);

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
                    await loadFixture(deployBulletLastPresaleFixture);

                await bulletLastPresale.grantRole(roundManagerRole, grantee.address);

                const promise = bulletLastPresale.revokeRole(roundManagerRole, grantee.address);
                await expect(promise)
                    .to.emit(bulletLastPresale, "RoleRevoked")
                    .withArgs(roundManagerRole, grantee.address, deployer.address);
            });

            it("Should skip emitting the RoleRevoked event without an upfront grant", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

                const promise = bulletLastPresale.revokeRole(roundManagerRole, grantee.address);
                await expect(promise).not.to.be.reverted;
            });
        });

        describe("Checks", function () {
            it("Should return the right revoked role state", async function () {
                const { bulletLastPresale, grantee, roundManagerRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
                const { bulletLastPresale, grantee, roundManagerRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
                const { bulletLastPresale, grantee, roundManagerRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
                const { bulletLastPresale, grantee, roundManagerRole } = await loadFixture(
                    deployBulletLastPresaleFixture
                );

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
});
