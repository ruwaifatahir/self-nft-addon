import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { expect } from "chai";
import anyValue from "@nomicfoundation/hardhat-chai-matchers/withArgs";

import {
  BTC_PRICE,
  ETH_PRICE,
  SELF_PRICE,
  USDT_PRICE,
  ZERO_ADDRESS,
  deployAddonSuite,
  format,
  parse,
} from "./utils/deployHelpers";
import { calculateNamePrice, getTotalCollected } from "./utils/ContractHelpers";

describe.only("SelfNftMultitokenAddon", () => {
  describe.only("registerName(string, address)", () => {
    describe("Checks", () => {
      it("should revert if price of name is invalid", async () => {
        // Arrange
        const { addon, selfNft } = await loadFixture(deployAddonSuite);
        await selfNft.setPrice(7, 0);

        // Act
        const action = async () => {
          return addon.registerNameSelf("ruwaifa", ZERO_ADDRESS);
        };

        // Assert
        await expect(action()).to.be.revertedWithCustomError(
          addon,
          "InvlaidPrice"
        );
      });
      it("should revert if there are not enough self tokens", async () => {
        // Arrange
        const { addon, selfNft } = await loadFixture(deployAddonSuite);
        await addon.withdrawSelfTokens();

        // Act
        const action = async () => {
          return addon.registerNameSelf("ruwaifa", ZERO_ADDRESS);
        };

        // Assert
        await expect(action()).to.be.revertedWithCustomError(
          addon,
          "InsufficientSelfTokens"
        );
      });
    });

    describe("Effects", () => {
      it("should update the agent commision", async () => {
        // Arrange: Load fixture, approve USDT tokens, add an agent, and register a name
        const { addon, selfToken, selfNft, otherAccount } = await loadFixture(
          deployAddonSuite
        );
        await selfToken.approve(addon.address, parse("1000000", 18));
        await addon.addAgent(otherAccount.address, parse("20", 6));
        await addon.registerNameSelf("ruwaifa", otherAccount.address);

        // Act: Calculate the expected price and agent commission, then get the earned commission
        const price = 1000;
        const agentCommision = ((price * 20) / 100).toFixed(1);
        const earnedCommision = await addon.getEarnedCommision(
          otherAccount.address,
          selfToken.address
        );

        // Assert: Verify that the earned commission matches the expected commission
        expect(format(earnedCommision, 18)).to.equal(agentCommision);
      });

      it("should update the collected self", async () => {
        // Arrange: Load fixture, approve USDT tokens, add an agent, and register a name
        const { addon, selfToken, otherAccount } = await loadFixture(
          deployAddonSuite
        );
        await selfToken.approve(addon.address, parse("1000000", 18));
        await addon.addAgent(otherAccount.address, parse("20", 6));
        await addon.registerNameSelf("ruwaifa", otherAccount.address);

        // Act: Calculate the expected price and agent commission, then get the earned commission
        const price = 1000;
        const agentCommision = Number((price * 20) / 100);
        const totalCollected = price - agentCommision;

        const collectedSelf = await addon.collectedSelf();

        // Assert: Verify that the earned commission matches the expected commission
        expect(Number(format(collectedSelf, 18)).toFixed(0)).to.equal(
          totalCollected.toString()
        );
      });
    });

    describe("Interactions", () => {
      it("should transfer name(NFT) to caller", async () => {
        // Arrange: Load fixture, approve USDT tokens, and register a name
        const { addon, selfToken, selfNft, owner } = await loadFixture(
          deployAddonSuite
        );
        await selfToken.approve(addon.address, parse("1000000", 18));
        await addon.registerNameSelf("ruwaifa", ZERO_ADDRESS);

        // Act: Calculate the name ID and retrieve the owner of the name
        const nameId = keccak256(toUtf8Bytes("ruwaifa"));
        const ownerOf = await selfNft.ownerOf(nameId);

        // Assert: Verify that the owner of the name is the caller
        expect(ownerOf).to.equal(owner.address);
      });
    });

    it.only("should register name with no agent", async () => {
      // Arrange: Load fixture, approve USDT tokens, add an agent, and register a name
      const { addon, selfToken } = await loadFixture(deployAddonSuite);
      await selfToken.approve(addon.address, parse("1000000", 18));
      await addon.registerNameSelf("ruwaifa", ZERO_ADDRESS);

      // Act: Calculate the expected price and agent commission, then get the earned commission

      const totalCollected = 1000;

      const collectedSelf = await addon.collectedSelf();

      // Assert: Verify that the earned commission matches the expected commission
      expect(Number(format(collectedSelf, 18)).toFixed(0)).to.equal(
        totalCollected.toString()
      );
    });
  });
  describe("registerName(string, address, address)", () => {
    describe("Checks", () => {
      it("should revert if payment token is not supported", async () => {
        // Arrange
        const { addon, usdt, otherAccount } = await loadFixture(
          deployAddonSuite
        );

        // Act
        const action = async () => {
          return addon.registerName(
            "ruwaifa",
            otherAccount.address,
            ZERO_ADDRESS
          );
        };

        // Assert
        await expect(action()).to.be.revertedWithCustomError(
          addon,
          "UnsupportedPaymentToken"
        );
      });

      it("should revert if name price is invalid", async () => {
        // Arrange: Load fixture, set name price to 0, and approve tokens
        const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);
        await selfNft.setPrice(5, 0);

        // Act & Assert: Attempt to register a name and expect it to revert with a custom error
        await expect(
          addon.registerName("ruwai", usdt.address, usdt.address)
        ).to.be.revertedWithCustomError(addon, "InvalidNamePrice");
      });

      it("should revert if there are not enough $SELF tokens to register a name", async () => {
        //Arrange
        const { addon, usdt } = await loadFixture(deployAddonSuite);
        await addon.withdrawSelfTokens();

        //Act & Assert
        await expect(
          addon.registerName("ruwai", usdt.address, ZERO_ADDRESS)
        ).to.be.revertedWithCustomError(addon, "InsufficientSelfTokens");
      });

      it("should let the caller register the name even provided address is not an agent and not cut any commsion", async () => {
        // Arrange
        const { addon, usdt, selfNft, owner, otherAccount } = await loadFixture(
          deployAddonSuite
        );
        await usdt.approve(addon.address, parse("1000000", 6));

        // Act
        await addon.registerName("ruwaifa", usdt.address, otherAccount.address);

        // Assert
        const price = await calculateNamePrice(
          selfNft,
          "ruwaifa",
          SELF_PRICE,
          USDT_PRICE
        );
        const collectedTokens = await getTotalCollected(addon, usdt);

        // Assert: Verify that the total collected tokens match the expected price
        expect(collectedTokens).to.equal(parse(price, 6));

        const nameId = keccak256(toUtf8Bytes("ruwaifa"));
        const ownerOf = await selfNft.ownerOf(nameId);
        expect(ownerOf).to.equal(owner.address);
      });

      it("should revert if $SELF token price is invalid", async () => {
        // Arrange: Load fixture, set $SELF price to 0, and approve tokens
        const { addon, usdt, addonMock } = await loadFixture(deployAddonSuite);
        await addonMock.__setSelfPrice(0);

        // Act & Assert: Attempt to register a name and expect it to revert with a custom error
        await expect(
          addonMock.registerName("ruwai", usdt.address, usdt.address)
        ).to.be.revertedWithCustomError(addon, "InvalidTokenPrice");
      });

      it("should revert if payment token price is invalid", async () => {
        // Arrange: Load fixture, set payment token price to 0, and approve tokens
        const { addon, usdt, usdtPricefeedMock } = await loadFixture(
          deployAddonSuite
        );
        await usdtPricefeedMock.setPrice(0);

        // Act & Assert: Attempt to register a name and expect it to revert with a custom error
        await expect(
          addon.registerName("ruwai", usdt.address, usdt.address)
        ).to.be.revertedWithCustomError(addon, "InvalidTokenPrice");
      });

      it("should revert if name contains invalid characters", async () => {
        // Arrange: Load fixture
        const { addon, usdt, owner } = await loadFixture(deployAddonSuite);

        const balance = await usdt.balanceOf(owner.address);

        await usdt.approve(addon.address, parse("1000000", 6));

        // Act & Assert: Attempt to register a name containing invalid characters and expect it to revert with a custom error
        await expect(
          addon.registerName("ruwai!", usdt.address, ZERO_ADDRESS)
        ).to.be.revertedWith("SELF: Invalid Character!");
      });
    });
    describe("Effects", () => {
      it("should update collectedTokens with total price of name", async () => {
        // Arrange: Load fixture, approve USDT tokens, and register a name
        const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);
        await usdt.approve(addon.address, parse("1000000", 6));
        await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

        // Act: Calculate the expected price and get the total collected tokens
        const price = await calculateNamePrice(
          selfNft,
          "ruwaifa",
          SELF_PRICE,
          USDT_PRICE
        );
        const collectedTokens = await getTotalCollected(addon, usdt);

        // Assert: Verify that the total collected tokens match the expected price
        expect(collectedTokens).to.equal(parse(price, 6));
      });

      it("should transfer agent fee to agent", async () => {
        // Arrange: Load fixture, approve USDT tokens, add an agent, and register a name
        const { addon, usdt, selfNft, otherAccount } = await loadFixture(
          deployAddonSuite
        );
        await usdt.approve(addon.address, parse("1000000", 6));
        await addon.addAgent(otherAccount.address, parse("20", 6));
        await addon.registerName("ruwaifa", usdt.address, otherAccount.address);

        // Act: Calculate the expected price and agent commission, then get the earned commission
        const price = await calculateNamePrice(
          selfNft,
          "ruwaifa",
          SELF_PRICE,
          USDT_PRICE
        );
        const agentCommision = ((Number(price) * 20) / 100).toFixed(2);
        const earnedCommision = await addon.getEarnedCommision(
          otherAccount.address,
          usdt.address
        );

        // Assert: Verify that the earned commission matches the expected commission
        expect(format(earnedCommision, 6)).to.equal(agentCommision);
      });

      it("should update the total collected tokens after agent fee is deducted", async () => {
        // Arrange: Load fixture, approve USDT tokens, add an agent, and register a name
        const { addon, usdt, selfNft, otherAccount } = await loadFixture(
          deployAddonSuite
        );
        await usdt.approve(addon.address, parse("1000000", 6));
        await addon.addAgent(otherAccount.address, parse("20", 6));
        await addon.registerName("ruwaifa", usdt.address, otherAccount.address);

        // Act: Calculate the expected price and agent commission, then get the total collected tokens
        const price = await calculateNamePrice(
          selfNft,
          "ruwaifa",
          SELF_PRICE,
          USDT_PRICE
        );
        const calCollectedTokens = ((Number(price) * 80) / 100).toFixed(1);
        const collectedTokens = await getTotalCollected(addon, usdt);

        // Assert: Verify that the total collected tokens match the expected price minus the agent commission
        expect(format(collectedTokens, 6)).to.equal(calCollectedTokens);
      });
    });

    describe("Interaction", () => {
      it("should transfer payment tokens to the contract", async () => {
        // Arrange: Load fixture, approve USDT tokens, and calculate the expected price
        const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);
        await usdt.approve(addon.address, parse("1000000", 6));
        const calcPrice = await calculateNamePrice(
          selfNft,
          "ruwaifa",
          SELF_PRICE,
          USDT_PRICE
        );

        // Act & Assert: Register a name and verify that the token balance of the contract changes by the expected price
        await expect(
          addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS)
        ).changeTokenBalance(usdt, addon, parse(calcPrice, 6));
      });
      it("should transfer name(NFT) to caller", async () => {
        // Arrange: Load fixture, approve USDT tokens, and register a name
        const { addon, usdt, selfNft, owner } = await loadFixture(
          deployAddonSuite
        );
        await usdt.approve(addon.address, parse("1000000", 6));
        await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

        // Act: Calculate the name ID and retrieve the owner of the name
        const nameId = keccak256(toUtf8Bytes("ruwaifa"));
        const ownerOf = await selfNft.ownerOf(nameId);

        // Assert: Verify that the owner of the name is the caller
        expect(ownerOf).to.equal(owner.address);
      });
    });
  });

  describe("addAgent", () => {
    it("should revert if agent address is zero", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to add an agent with a zero address and expect it to revert with a custom error
      await expect(
        addon.addAgent(ZERO_ADDRESS, parse("20", 6))
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if agent commision rate is 0", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to add an agent with a zero fee and expect it to revert with a custom error
      await expect(
        addon.addAgent(otherAccount.address, parse("0", 6))
      ).to.be.revertedWithCustomError(addon, "InvalidCommissionRate");
    });

    it("should revert if agent commision rate is greater than 100", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to add an agent with a fee greater than 100 and expect it to revert with a custom error
      await expect(
        addon.addAgent(otherAccount.address, parse("101", 6))
      ).to.be.revertedWithCustomError(addon, "InvalidCommissionRate");
    });

    it("should revert if agent is already an agent", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);
      await addon.addAgent(otherAccount.address, parse("20", 6));

      // Act & Assert: Attempt to add an agent that is already an agent and expect it to revert with a custom error
      await expect(
        addon.addAgent(otherAccount.address, parse("20", 6))
      ).to.be.revertedWithCustomError(addon, "AlreadyAgent");
    });

    it("should add the agent", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act: Add an agent
      await addon.addAgent(otherAccount.address, parse("20", 6));
      // Assert: Verify that the agent was added
      expect(await addon.agents(otherAccount.address)).to.equal(parse("20", 6));
    });

    it("should emit the AgentAdded event", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Add an agent and verify that the AgentAdded event was emitted
      await expect(addon.addAgent(otherAccount.address, parse("20", 6)))
        .to.emit(addon, "AgentAdded")
        .withArgs(otherAccount.address, parse("20", 6));
    });
  });

  describe("updateAgentCommission", () => {
    it("should revert if agent address is invalid", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to update the commission of an invalid agent and expect it to revert with a custom error
      await expect(
        addon.updateAgentCommission(ZERO_ADDRESS, parse("20", 6))
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if commision rate is 0", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to update the commission of an agent with a zero fee and expect it to revert with a custom error
      await expect(
        addon.updateAgentCommission(otherAccount.address, parse("0", 6))
      ).to.be.revertedWithCustomError(addon, "InvalidCommissionRate");
    });

    it("should revert if commision rate is greater than 100", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to update the commission of an agent with a fee greater than 100 and expect it to revert with a custom error
      await expect(
        addon.updateAgentCommission(otherAccount.address, parse("101", 6))
      ).to.be.revertedWithCustomError(addon, "InvalidCommissionRate");
    });

    it("should revert if agent is not an agent", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to update the commission of an agent that is not an agent and expect it to revert with a custom error
      await expect(
        addon.updateAgentCommission(otherAccount.address, parse("20", 6))
      ).to.be.revertedWithCustomError(addon, "NotAnAgent");
    });

    it("should update the commision rate of the agent", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);
      await addon.addAgent(otherAccount.address, parse("20", 6));

      // Act: Update the commission rate of the agent
      await addon.updateAgentCommission(otherAccount.address, parse("30", 6));

      // Assert: Verify that the commission rate of the agent was updated
      expect(await addon.agents(otherAccount.address)).to.equal(parse("30", 6));
    });

    it("should emit the AgentCommisionUpdated event", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);
      await addon.addAgent(otherAccount.address, parse("20", 6));

      // Act & Assert: Update the commission rate of the agent and verify that the AgentCommisionUpdated event was emitted
      await expect(
        addon.updateAgentCommission(otherAccount.address, parse("30", 6))
      )
        .to.emit(addon, "AgentCommisionUpdated")
        .withArgs(otherAccount.address, parse("30", 6));
    });
  });

  describe("removeAgent", () => {
    it("should revert if agent address is invalid", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to remove an invalid agent and expect it to revert with a custom error
      await expect(
        addon.removeAgent(ZERO_ADDRESS)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if agent is not an agent", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to remove an agent that is not an agent and expect it to revert with a custom error
      await expect(
        addon.removeAgent(otherAccount.address)
      ).to.be.revertedWithCustomError(addon, "NotAnAgent");
    });

    it("should update the agent commission rate to 0", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);
      await addon.addAgent(otherAccount.address, parse("20", 6));

      // Act: Remove the agent
      await addon.removeAgent(otherAccount.address);

      // Assert: Verify that the commission rate of the agent was updated to 0
      expect(await addon.agents(otherAccount.address)).to.equal(parse("0", 6));
    });

    it("should emit the AgentRemoved event", async () => {
      // Arrange: Load fixture
      const { addon, otherAccount } = await loadFixture(deployAddonSuite);
      await addon.addAgent(otherAccount.address, parse("20", 6));

      // Act & Assert: Remove the agent and verify that the AgentRemoved event was emitted
      await expect(addon.removeAgent(otherAccount.address))
        .to.emit(addon, "AgentRemoved")
        .withArgs(otherAccount.address);
    });
  });

  describe("approveSelfTokens", () => {
    it("should set the allowance to param amount", async () => {
      // Arrange: Load fixture
      const { addon, selfNft, selfToken } = await loadFixture(deployAddonSuite);

      // Act: Approve the contract to transfer $SELF tokens
      await addon.approveSelfTokens(parse("10000"));

      // Assert: Verify that the allowance of the contract is zero
      expect(
        await selfToken.allowance(addon.address, selfNft.address)
      ).to.equal(parse("10000"));
    });

    it("should set the allowance to 0", async () => {
      // Arrange: Load fixture
      const { addon, selfNft, selfToken } = await loadFixture(deployAddonSuite);

      // Act: Approve the contract to transfer $SELF tokens
      await addon.approveSelfTokens(parse("10000"));
      await addon.approveSelfTokens(parse("0"));

      // Assert: Verify that the allowance of the contract is zero
      expect(
        await selfToken.allowance(addon.address, selfNft.address)
      ).to.equal(parse("0"));
    });

    it("should emit SelfTokensApproved event", async () => {
      // Arrange: Load fixture
      const { addon, selfNft, selfToken } = await loadFixture(deployAddonSuite);

      // Act & Assert: Approve the contract to transfer $SELF tokens and verify that the SelfTokensApproved event was emitted
      await expect(addon.approveSelfTokens(parse("10000")))
        .to.emit(addon, "SelfTokensApproved")
        .withArgs(selfNft.address, parse("10000"));
    });
  });

  describe("depositSelfTokens", () => {
    it("should revert if deposit amount is invalid", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to deposit an invalid amount of $SELF tokens and expect it to revert with a custom error
      await expect(
        addon.depositSelfTokens(parse("0"))
      ).to.be.revertedWithCustomError(addon, "InvalidDepositAmount");
    });

    it("should update the depositedSelfTokens ", async () => {
      // Arrange: Load fixture
      const { addon, selfToken } = await loadFixture(deployAddonSuite);
      await addon.withdrawSelfTokens();
      await selfToken.approve(addon.address, parse("1000000", 18));

      // Act: Deposit $SELF tokens
      await addon.depositSelfTokens(parse("10000"));

      // Assert: Verify that the depositedSelfTokens was updated
      expect(await addon.depositedSelfTokens()).to.equal(parse("10000"));
    });

    it("should transfer $SELF tokens to the contract", async () => {
      // Arrange: Load fixture
      const { addon, selfToken } = await loadFixture(deployAddonSuite);
      await selfToken.approve(addon.address, parse("1000000", 18));

      // Act & Assert: Deposit $SELF tokens and verify that the token balance of the contract changes by the deposited amount
      await expect(addon.depositSelfTokens(parse("10000"))).changeTokenBalance(
        selfToken,
        addon,
        parse("10000")
      );
    });

    it("should emit SelfTokensDeposited event", async () => {
      // Arrange: Load fixture
      const { addon, selfToken } = await loadFixture(deployAddonSuite);
      await selfToken.approve(addon.address, parse("1000000", 18));

      // Act & Assert: Deposit $SELF tokens and verify that the SelfTokensDeposited event was emitted
      await expect(addon.depositSelfTokens(parse("10000")))
        .to.emit(addon, "SelfTokensDeposited")
        .withArgs(parse("10000"));
    });
  });

  describe("withdrawSelfTokens", () => {
    it("should revert if there are no deposited self tokens", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      await addon.withdrawSelfTokens();

      // Act & Assert: Attempt to withdraw $SELF tokens and expect it to revert with a custom error
      await expect(addon.withdrawSelfTokens()).to.be.revertedWithCustomError(
        addon,
        "InvalidWithdrawAmount"
      );
    });

    it("should transfer $SELF tokens to the owner", async () => {
      // Arrange: Load fixture
      const { addon, selfToken, owner } = await loadFixture(deployAddonSuite);
      await selfToken.approve(addon.address, parse("1000000", 18));
      await addon.withdrawSelfTokens();
      await addon.depositSelfTokens(parse("10000"));

      // Act & Assert: Withdraw $SELF tokens and verify that the token balance of the owner changes by the deposited amount
      await expect(addon.withdrawSelfTokens()).changeTokenBalance(
        selfToken,
        owner,
        parse("10000")
      );
    });

    it("should update the depositedSelfTokens to 0", async () => {
      // Arrange: Load fixture
      const { addon, selfToken } = await loadFixture(deployAddonSuite);
      await selfToken.approve(addon.address, parse("1000000", 18));
      await addon.withdrawSelfTokens();
      await addon.depositSelfTokens(parse("10000"));

      // Act: Withdraw $SELF tokens
      await addon.withdrawSelfTokens();

      // Assert: Verify that the depositedSelfTokens was updated to 0
      expect(await addon.depositedSelfTokens()).to.equal(parse("0"));
    });

    it("should emit SelfTokensWithdrawn event", async () => {
      // Arrange: Load fixture
      const { addon, selfToken } = await loadFixture(deployAddonSuite);
      await selfToken.approve(addon.address, parse("1000000", 18));
      await addon.withdrawSelfTokens();
      await addon.depositSelfTokens(parse("10000"));

      // Act & Assert: Withdraw $SELF tokens and verify that the SelfTokensWithdrawn event was emitted
      await expect(addon.withdrawSelfTokens())
        .to.emit(addon, "SelfTokensWithdrawn")
        .withArgs(parse("10000"));
    });
  });

  describe("setSelfNft", () => {
    it("should revert if selfNft address is invalid", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to set an invalid selfNft address and expect it to revert with a custom error
      await expect(
        addon.setSelfNft(ZERO_ADDRESS)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should update the selfNft address", async () => {
      // Arrange: Load fixture
      const { addon, selfNft, otherAccount } = await loadFixture(
        deployAddonSuite
      );

      // Act: Set the selfNft address
      await addon.setSelfNft(otherAccount.address);

      // Assert: Verify that the selfNft address was updated
      expect(await addon.selfNft()).to.equal(otherAccount.address);
    });

    it("should emit SelfNftUpdated event", async () => {
      // Arrange: Load fixture
      const { addon, selfNft, otherAccount } = await loadFixture(
        deployAddonSuite
      );

      // Act & Assert: Set the selfNft address and verify that the SelfNftUpdated event was emitted
      await expect(addon.setSelfNft(otherAccount.address))
        .to.emit(addon, "SelfNftUpdated")
        .withArgs(otherAccount.address);
    });
  });

  describe("addChainlinkPricefeed", () => {
    it("should revert if payment token is invalid", async () => {
      // Arrange: Load fixture
      const { addon, usdt, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to add a chainlink pricefeed with an invalid payment token and expect it to revert with a custom error
      await expect(
        addon.addChainlinkPricefeed(ZERO_ADDRESS, otherAccount.address, 6)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if price feed is invalid", async () => {
      // Arrange: Load fixture
      const { addon, usdt } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to add a chainlink pricefeed with an invalid price feed and expect it to revert with a custom error
      await expect(
        addon.addChainlinkPricefeed(usdt.address, ZERO_ADDRESS, 6)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if pay token decimals are less than 6", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );
      await usdtPricefeedMock.setPrice(0);

      // Act & Assert: Attempt to add a chainlink pricefeed with an invalid pay token decimals and expect it to revert with a custom error
      await expect(
        addon.addChainlinkPricefeed(usdt.address, usdt.address, 5)
      ).to.be.revertedWithCustomError(addon, "InvalidTokenDecimals");
    });

    it("should revert if price feed is already added", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act & Assert: Attempt to add a chainlink pricefeed that is already added and expect it to revert with a custom error
      await expect(
        addon.addChainlinkPricefeed(usdt.address, usdtPricefeedMock.address, 6)
      ).to.be.revertedWithCustomError(addon, "PriceFeedAlreadyAdded");
    });

    it("should add the payment token of the price feed", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act: Add a chainlink pricefeed
      await addon.addChainlinkPricefeed(
        usdtPricefeedMock.address,
        usdtPricefeedMock.address,
        6
      );

      // Assert: Verify that the payment token of the price feed was updated
      expect(
        (await addon.chainlinkPriceFeeds(usdtPricefeedMock.address))
          .paymentToken
      ).to.equal(usdtPricefeedMock.address);
    });

    it("should add the price feed address", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act: Add a chainlink pricefeed
      await addon.addChainlinkPricefeed(
        usdtPricefeedMock.address,
        usdt.address,
        6
      );

      // Assert: Verify that the price feed address was updated
      expect(
        (await addon.chainlinkPriceFeeds(usdtPricefeedMock.address)).priceFeed
      ).to.equal(usdt.address);
    });

    it("should add the payment token decimals", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act: Add a chainlink pricefeed
      await addon.addChainlinkPricefeed(
        usdtPricefeedMock.address,
        usdt.address,
        6
      );

      // Assert: Verify that the payment token decimals was updated
      expect(
        (await addon.chainlinkPriceFeeds(usdtPricefeedMock.address)).decimals
      ).to.equal(6);
    });

    it("should not update the price feed collectedTokens", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act: Add a chainlink pricefeed
      await addon.addChainlinkPricefeed(
        usdtPricefeedMock.address,
        usdt.address,
        6
      );

      // Assert: Verify that the price feed collectedTokens was not updated
      expect(
        (await addon.chainlinkPriceFeeds(usdtPricefeedMock.address))
          .collectedTokens
      ).to.equal(parse("0"));
    });

    it("should emit the ChainlinkPriceFeedAdded event", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act & Assert: Add a chainlink pricefeed and verify that the ChainlinkPriceFeedAdded event was emitted
      await expect(
        addon.addChainlinkPricefeed(usdtPricefeedMock.address, usdt.address, 6)
      )
        .to.emit(addon, "ChainlinkPriceFeedAdded")
        .withArgs(usdtPricefeedMock.address, usdt.address);
    });
  });

  describe("updateChainlinkPricefeed", () => {
    it("should revert if payment token is invalid", async () => {
      // Arrange: Load fixture
      const { addon, usdt, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to update a chainlink pricefeed with an invalid payment token and expect it to revert with a custom error
      await expect(
        addon.updateChainlinkPricefeed(ZERO_ADDRESS, otherAccount.address, 6)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if price feed is invalid", async () => {
      // Arrange: Load fixture
      const { addon, usdt } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to update a chainlink pricefeed with an invalid price feed and expect it to revert with a custom error
      await expect(
        addon.updateChainlinkPricefeed(usdt.address, ZERO_ADDRESS, 6)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if payment token decimals are less than 6", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act & Assert: Attempt to update a chainlink pricefeed with an invalid payment token decimals and expect it to revert with a custom error
      await expect(
        addon.updateChainlinkPricefeed(usdt.address, usdt.address, 5)
      ).to.be.revertedWithCustomError(addon, "InvalidTokenDecimals");
    });

    it("should revert if price feed is not added", async () => {
      // Arrange: Load fixture
      const { addon, usdtPricefeedMock } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to update a chainlink pricefeed that is not added and expect it to revert with a custom error
      await expect(
        addon.updateChainlinkPricefeed(
          usdtPricefeedMock.address,
          usdtPricefeedMock.address,
          6
        )
      ).to.be.revertedWithCustomError(addon, "NotAPriceFeed");
    });

    it("should update the price feed address", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock, otherAccount } =
        await loadFixture(deployAddonSuite);

      // Act: Update a chainlink pricefeed
      await addon.updateChainlinkPricefeed(
        usdt.address,
        otherAccount.address,
        6
      );

      // Assert: Verify that the price feed address was updated
      expect(
        (await addon.chainlinkPriceFeeds(usdt.address)).priceFeed
      ).to.equal(otherAccount.address);
    });

    it("should update the decimals of pay token", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act: Update a chainlink pricefeed
      await addon.updateChainlinkPricefeed(usdt.address, usdt.address, 9);

      // Assert: Verify that the decimals of pay token was updated
      expect((await addon.chainlinkPriceFeeds(usdt.address)).decimals).to.equal(
        9
      );
    });

    it("should keep the collected tokens of the price feed same after updating", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock, selfNft } = await loadFixture(
        deployAddonSuite
      );

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

      const price = await calculateNamePrice(
        selfNft,
        "ruwaifa",
        SELF_PRICE,
        USDT_PRICE
      );

      // Act: Update a chainlink pricefeed
      await addon.updateChainlinkPricefeed(
        usdt.address,
        usdtPricefeedMock.address,
        6
      );

      // Assert: Verify that the collected tokens of the price feed was not updated
      expect(
        (await addon.chainlinkPriceFeeds(usdt.address)).collectedTokens
      ).to.equal(parse(price, 6));
    });

    it("should emit the ChainlinkPriceFeedUpdated event", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act & Assert: Update a chainlink pricefeed and verify that the ChainlinkPriceFeedUpdated event was emitted
      await expect(
        addon.updateChainlinkPricefeed(usdt.address, usdt.address, 6)
      )
        .to.emit(addon, "ChainlinkPriceFeedUpdated")
        .withArgs(usdt.address, usdt.address);
    });
  });

  describe("removeChainlinkPricefeed", () => {
    it("should revert if payment token is invalid", async () => {
      // Arrange: Load fixture
      const { addon, usdt, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to remove a chainlink pricefeed with an invalid payment token and expect it to revert with a custom error
      await expect(
        addon.removeChainlinkPricefeed(ZERO_ADDRESS)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert price feed does not exist already", async () => {
      // Arrange: Load fixture
      const { addon, usdt, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to remove a chainlink pricefeed that does not exist and expect it to revert with a custom error
      await expect(
        addon.removeChainlinkPricefeed(otherAccount.address)
      ).to.be.revertedWithCustomError(addon, "NotAPriceFeed");
    });

    it("should remove the payment token of the price feed", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act: Remove a chainlink pricefeed
      await addon.removeChainlinkPricefeed(usdt.address);

      // Assert: Verify that the payment token of the price feed was updated
      expect(
        (await addon.chainlinkPriceFeeds(usdtPricefeedMock.address))
          .paymentToken
      ).to.equal(ZERO_ADDRESS);
    });

    it("should transfer the collected token of the price feed to the owner", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock, owner, selfNft } =
        await loadFixture(deployAddonSuite);

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

      const price = await calculateNamePrice(
        selfNft,
        "ruwaifa",
        SELF_PRICE,
        USDT_PRICE
      );

      // Act & Assert: Remove a chainlink pricefeed and verify that the token balance of the owner changes by the collected amount
      await expect(
        addon.removeChainlinkPricefeed(usdt.address)
      ).changeTokenBalance(usdt, owner, parse(price, 6));
    });

    it("should reset the collectedTokens var", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock, owner, selfNft } =
        await loadFixture(deployAddonSuite);

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

      const price = await calculateNamePrice(
        selfNft,
        "ruwaifa",
        SELF_PRICE,
        USDT_PRICE
      );

      // Act & Assert: Remove a chainlink pricefeed and verify that the token balance of the owner changes by the collected amount
      await addon.removeChainlinkPricefeed(usdt.address);

      expect(
        (await addon.chainlinkPriceFeeds(usdt.address)).collectedTokens
      ).to.equal(0);
    });
    it("should emit the ChainlinkPriceFeedRemoved event", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock } = await loadFixture(
        deployAddonSuite
      );

      // Act & Assert: Remove a chainlink pricefeed and verify that the ChainlinkPriceFeedRemoved event was emitted
      await expect(addon.removeChainlinkPricefeed(usdt.address))
        .to.emit(addon, "ChainlinkPriceFeedRemoved")
        .withArgs(usdt.address);
    });
  });

  describe("forwardCollectedTokens", () => {
    it("should revert if payment token is invalid", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to forward collected tokens with an invalid payment token and expect it to revert with a custom error
      await expect(
        addon.forwardCollectedTokens(ZERO_ADDRESS)
      ).to.be.revertedWithCustomError(addon, "ZeroAddressError");
    });

    it("should revert if payment token is not supported", async () => {
      // Arrange: Load fixture
      const { addon, usdt, otherAccount } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to forward collected tokens with an unsupported payment token and expect it to revert with a custom error
      await expect(
        addon.forwardCollectedTokens(otherAccount.address)
      ).to.be.revertedWithCustomError(addon, "NotAPriceFeed");
    });

    it("should revert if there no collected tokens", async () => {
      // Arrange: Load fixture
      const { addon, usdt } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to forward collected tokens with no collected tokens and expect it to revert with a custom error
      await expect(
        addon.forwardCollectedTokens(usdt.address)
      ).to.be.revertedWithCustomError(addon, "InsufficientCollectedTokens");
    });

    it("should reset the collected tokens to zero", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock, selfNft } = await loadFixture(
        deployAddonSuite
      );

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

      // Act: Forward collected tokens
      await addon.forwardCollectedTokens(usdt.address);

      // Assert: Verify that the collected tokens was updated to zero
      expect(
        (await addon.chainlinkPriceFeeds(usdt.address)).collectedTokens
      ).to.equal(parse("0"));
    });

    it("should transfer the payment tokens to owner", async () => {
      // Arrange: Load fixture
      const { addon, usdt, usdtPricefeedMock, selfNft, owner } =
        await loadFixture(deployAddonSuite);

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

      const price = await calculateNamePrice(
        selfNft,
        "ruwaifa",
        SELF_PRICE,
        USDT_PRICE
      );

      // Act & Assert: Forward collected tokens and verify that the token balance of the owner changes by the collected amount
      await expect(
        addon.forwardCollectedTokens(usdt.address)
      ).changeTokenBalance(usdt, owner, parse(price, 6));
    });

    it("should emit the CollectedTokensForwarded", async () => {
      // Arrange: Load fixture
      const { addon, usdt, owner, selfNft } = await loadFixture(
        deployAddonSuite
      );

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);

      const price = await calculateNamePrice(
        selfNft,
        "ruwaifa",
        SELF_PRICE,
        USDT_PRICE
      );

      // Act & Assert: Forward collected tokens and verify that the CollectedTokensForwarded event was emitted
      await expect(addon.forwardCollectedTokens(usdt.address))
        .to.emit(addon, "CollectedTokensForwarded")
        .withArgs(owner.address, parse(price, 6));
    });
  });

  describe("setSelfPrice", () => {
    it("should revert if self price is invalid", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Attempt to set an invalid self price and expect it to revert with a custom error
      await expect(
        addon.setSelfPrice(parse("0"))
      ).to.be.revertedWithCustomError(addon, "InvalidSelfPrice");
    });
    it("should update the self price", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act: Set the self price
      await addon.setSelfPrice(parse("10000"));

      // Assert: Verify that the self price was updated
      expect(await addon.selfPrice()).to.equal(parse("10000"));
    });

    it("should emit SelfPriceUpdated event", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act & Assert: Set the self price and verify that the SelfPriceUpdated event was emitted
      await expect(addon.setSelfPrice(parse("10000")))
        .to.emit(addon, "SelfPriceUpdated")
        .withArgs(parse("10000"));
    });
  });

  describe("pause/unpause", () => {
    it("should pause the contract", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act: Pause the contract
      await addon.pause();

      // Assert: Verify that the contract is paused
      expect(await addon.paused()).to.equal(true);
    });
    it("should revert if tries to call when not paused function when paused", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act: Pause the contract
      await addon.pause();

      await expect(
        addon.registerName("ruwaifa", ZERO_ADDRESS, ZERO_ADDRESS)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("should unpause the contract", async () => {
      // Arrange: Load fixture
      const { addon } = await loadFixture(deployAddonSuite);

      // Act: Pause the contract
      await addon.pause();
      await addon.unpause();

      // Assert: Verify that the contract is paused
      expect(await addon.paused()).to.equal(false);
    });
  });

  describe("getPrice", () => {
    it("should return the correct price of name(5) in USDT", async function () {
      // Arrange: Load fixture
      const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);

      // // Assert: Verify that the price of the name is correct
      expect(await addon.getPrice("ruwai", usdt.address)).to.equal(
        parse(
          await calculateNamePrice(selfNft, "ruwai", SELF_PRICE, USDT_PRICE),
          6
        )
      );
    });

    it("should return the correct price of name(6) in USDT", async function () {
      // Arrange: Load fixture
      const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);

      // // Assert: Verify that the price of the name is correct
      expect(await addon.getPrice("ruwaif", usdt.address)).to.equal(
        parse(
          await calculateNamePrice(selfNft, "ruwaif", SELF_PRICE, USDT_PRICE),
          6
        )
      );
    });

    it("should return the correct price of name(7) in USDT", async function () {
      // Arrange: Load fixture
      const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);

      // // Assert: Verify that the price of the name is correct
      expect(await addon.getPrice("ruwaifa", usdt.address)).to.equal(
        parse(
          await calculateNamePrice(selfNft, "ruwaifa", SELF_PRICE, USDT_PRICE),
          6
        )
      );
    });

    it("should return the correct price of name(8) in USDT", async function () {
      // Arrange: Load fixture
      const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);

      // // Assert: Verify that the price of the name is correct
      expect(await addon.getPrice("ruwaifaa", usdt.address)).to.equal(
        parse(
          await calculateNamePrice(selfNft, "ruwaifaa", SELF_PRICE, USDT_PRICE),
          6
        )
      );
    });

    it("should return the correct price of name(9) in USDT", async function () {
      // Arrange: Load fixture
      const { addon, usdt, selfNft } = await loadFixture(deployAddonSuite);

      // // Assert: Verify that the price of the name is correct
      expect(await addon.getPrice("ruwaifaaa", usdt.address)).to.equal(
        parse(
          await calculateNamePrice(
            selfNft,
            "ruwaifaaa",
            SELF_PRICE,
            USDT_PRICE
          ),
          6
        )
      );
    });

    it("should return the correct price of name(5) in BTC", async function () {
      // Arrange: Load fixture
      const { addon, btc, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwai", btc.address), 8));
      // // Assert: Verify that the price of the name is correct
      expect(format(await addon.getPrice("ruwai", btc.address), 8)).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwai", SELF_PRICE, BTC_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(6) in BTC", async function () {
      // Arrange: Load fixture
      const { addon, btc, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaif", btc.address), 8));
      // // Assert: Verify that the price of the name is correct
      expect(format(await addon.getPrice("ruwaif", btc.address), 8)).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaif", SELF_PRICE, BTC_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(7) in BTC", async function () {
      // Arrange: Load fixture
      const { addon, btc, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaifa", btc.address), 8));
      // // Assert: Verify that the price of the name is correct
      expect(format(await addon.getPrice("ruwaifa", btc.address), 8)).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaifa", SELF_PRICE, BTC_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(8) in BTC", async function () {
      // Arrange: Load fixture
      const { addon, btc, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaifaa", btc.address), 8));
      // // Assert: Verify that the price of the name is correct
      expect(format(await addon.getPrice("ruwaifaa", btc.address), 8)).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaifaa", SELF_PRICE, BTC_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(9) in BTC", async function () {
      // Arrange: Load fixture
      const { addon, btc, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaifaaa", btc.address), 8));
      // // Assert: Verify that the price of the name is correct
      expect(
        format(await addon.getPrice("ruwaifaaa", btc.address), 8)
      ).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaifaaa", SELF_PRICE, BTC_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(5) in ETH", async function () {
      // Arrange: Load fixture
      const { addon, eth, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwai", eth.address), 18));
      // // Assert: Verify that the price of the name is correct
      expect(
        Number(format(await addon.getPrice("ruwai", eth.address), 18)).toFixed(
          8
        )
      ).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwai", SELF_PRICE, ETH_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(6) in ETH", async function () {
      // Arrange: Load fixture
      const { addon, eth, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaif", eth.address), 18));
      // // Assert: Verify that the price of the name is correct
      expect(
        Number(format(await addon.getPrice("ruwaif", eth.address), 18)).toFixed(
          8
        )
      ).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaif", SELF_PRICE, ETH_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(7) in ETH", async function () {
      // Arrange: Load fixture
      const { addon, eth, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaifa", eth.address), 18));
      // // Assert: Verify that the price of the name is correct
      expect(
        Number(
          format(await addon.getPrice("ruwaifa", eth.address), 18)
        ).toFixed(8)
      ).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaifa", SELF_PRICE, ETH_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(8) in ETH", async function () {
      // Arrange: Load fixture
      const { addon, eth, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaifaa", eth.address), 18));
      // // Assert: Verify that the price of the name is correct
      expect(
        Number(
          format(await addon.getPrice("ruwaifaa", eth.address), 18)
        ).toFixed(8)
      ).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaifaa", SELF_PRICE, ETH_PRICE)
        ).toFixed(8)
      );
    });

    it("should return the correct price of name(9) in ETH", async function () {
      // Arrange: Load fixture
      const { addon, eth, selfNft } = await loadFixture(deployAddonSuite);

      console.log(format(await addon.getPrice("ruwaifaaa", eth.address), 18));
      // // Assert: Verify that the price of the name is correct
      expect(
        Number(
          format(await addon.getPrice("ruwaifaaa", eth.address), 18)
        ).toFixed(8)
      ).to.equal(
        Number(
          await calculateNamePrice(selfNft, "ruwaifaaa", SELF_PRICE, ETH_PRICE)
        ).toFixed(8)
      );
    });
  });

  describe("_calculatePriceInPaymentToken", () => {
    it("should revert if name price is invalid", async () => {
      // Arrange: Load fixture, set name price to 0, and approve tokens
      const { addon, usdt, selfNft, addonMock } = await loadFixture(
        deployAddonSuite
      );
      await selfNft.setPrice(5, 0);

      // Act & Assert: Attempt to calculate the price of a name and expect it to revert with a custom error
      await expect(
        addonMock.calculatePriceInPaymentToken(
          0,
          parse(SELF_PRICE.toString(), 18),
          parse(USDT_PRICE.toString(), 6),

          6
        )
      ).to.be.revertedWithCustomError(addon, "InvalidNamePrice");
    });

    it("should revert if self price is zero", async () => {
      // Arrange: Load fixture, set self price to 0, and approve tokens
      const { addon, usdt, selfNft, addonMock } = await loadFixture(
        deployAddonSuite
      );
      await addonMock.__setSelfPrice(0);

      // Act & Assert: Attempt to calculate the price of a name and expect it to revert with a custom error
      await expect(
        addonMock.calculatePriceInPaymentToken(
          parse("10"),
          0,
          parse(USDT_PRICE.toString(), 6),
          6
        )
      ).to.be.revertedWithCustomError(addon, "InvalidTokenPrice");
    });

    it("should revert if payment token price is zero", async () => {
      // Arrange: Load fixture, set payment token price to 0, and approve tokens
      const { addon, usdt, usdtPricefeedMock, addonMock } = await loadFixture(
        deployAddonSuite
      );
      await usdtPricefeedMock.setPrice(0);

      // Act & Assert: Attempt to calculate the price of a name and expect it to revert with a custom error
      await expect(
        addonMock.calculatePriceInPaymentToken(
          parse("10"),
          parse(SELF_PRICE.toString(), 18),
          0,
          6
        )
      ).to.be.revertedWithCustomError(addon, "InvalidTokenPrice");
    });

    it("should revert if pay token decimals are less than 6", async () => {
      // Arrange: Load fixture, set payment token price to 0, and approve tokens
      const { addon, usdt, usdtPricefeedMock, addonMock } = await loadFixture(
        deployAddonSuite
      );
      await usdtPricefeedMock.setPrice(0);

      // Act & Assert: Attempt to calculate the price of a name and expect it to revert with a custom error
      await expect(
        addonMock.calculatePriceInPaymentToken(
          parse("10"),
          parse(SELF_PRICE.toString()),
          parse(USDT_PRICE.toString(), 6),
          5
        )
      ).to.be.revertedWithCustomError(addon, "InvalidTokenDecimals");
    });

    it("should return the correct price", async () => {
      // Arrange: Load fixture, set payment token price to 0, and approve tokens
      const { addon, usdt, usdtPricefeedMock, addonMock } = await loadFixture(
        deployAddonSuite
      );
      await usdtPricefeedMock.setPrice(parse("1", 8));

      // Act & Assert: Attempt to calculate the price of a name and expect it to revert with a custom error

      const price = await addonMock.calculatePriceInPaymentToken(
        parse("1000"),
        parse(SELF_PRICE.toString()),
        parse(USDT_PRICE.toString(), 6),
        6
      );

      // const calcPrice = await calculateNamePrice(
      //   addon,
      //   "ruwaifa",
      //   SELF_PRICE,
      //   USDT_PRICE
      // );

      // expect(price).to.equal(parse(calcPrice, 6));
    });
  });

  describe("_handleAgentCommission", () => {
    it("should not deduct the commission if the agent is zero address", async () => {
      const { addon, usdt, usdtPricefeedMock, selfNft } = await loadFixture(
        deployAddonSuite
      );

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, ZERO_ADDRESS);
      const collectedTokens = (await addon.chainlinkPriceFeeds(usdt.address))
        .collectedTokens;

      const calcPrice = await calculateNamePrice(
        selfNft,
        "ruwaifa",
        SELF_PRICE,
        USDT_PRICE
      );

      expect(collectedTokens).to.equal(parse(calcPrice, 6));
    });

    it("should give correct commision to agent and add remaining amount to collected tokens", async () => {
      const { addon, usdt, usdtPricefeedMock, selfNft, otherAccount } =
        await loadFixture(deployAddonSuite);

      await addon.addAgent(otherAccount.address, parse("25", 6));

      await usdt.approve(addon.address, parse("1000000", 6));

      await addon.registerName("ruwaifa", usdt.address, otherAccount.address);
      const collectedTokens = (await addon.chainlinkPriceFeeds(usdt.address))
        .collectedTokens;

      const calcPrice = parse(
        await calculateNamePrice(selfNft, "ruwaifa", SELF_PRICE, USDT_PRICE),
        6
      );

      const earnedCommision = await addon.getEarnedCommision(
        otherAccount.address,
        usdt.address
      );

      const calcCommision = calcPrice.mul(parse("25", 6)).div(parse("100", 6));

      expect(earnedCommision).to.equal(calcCommision);

      expect(collectedTokens).to.equal(calcPrice.sub(calcCommision));

      // expect(collectedTokens).to.equal(parse(calcPrice, 6).sub(parse("1000")));
    });
  });
});

/**
 *
 */
