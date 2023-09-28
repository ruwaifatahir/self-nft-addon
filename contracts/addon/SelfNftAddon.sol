// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

//=================External Imports=======================
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//=================Internal Imports=======================
import "../interfaces/ISelfNft.sol";
import {SelfNftAddonStorage} from "./SelfNftAddonStorage.sol";

contract SelfNftAddon is
    SelfNftAddonStorage,
    Ownable,
    Pausable,
    ReentrancyGuard,
    IERC721Receiver
{
    using SafeERC20 for IERC20;

    /**
     * @title SelfNft
     * @author Self dev team
     * @custom:version v2.3.1
     * @custom:date 28 sept 2023

    ------------v2.3.1 changes------------
    - update NameRegistered event to include agent and payment token address
    - update removeChainlinkPricefeed to transfer the collected tokens of the respective price feed to the owner.
    - imporved UX in _handleAgentCommission
    
     */

    /**
     * The SelfNftMultitokenAddon smart contract serves as an extension to the SelfNft.sol contract, enhancing its capabilities by allowing users to register names as Non-Fungible Tokens (NFTs) using multiple types of tokens, rather than being restricted to a single token. This is made possible through real-time price feeds provided by Chainlink oracles, which ensure that the cost of name registration is accurately calculated in the chosen token at the time of purchase. It also incorporates a server-maintained $SELF price to ensure accurate and up-to-date pricing for name registrations.
     *
     * 
     * * Multi-Token Support: Unlike the original SelfNft.sol contract, which allows name registration using only a single type of token, this addon enables payment with various supported tokens.
     
     * * Dynamic Pricing: Utilizes Chainlink oracles to fetch real-time prices of supported tokens, ensuring fair and up-to-date pricing for name registrations.

     * * Server-Maintained $SELF Price: Due to the absence of a Chainlink price feed for the $SELF token, our smart contract incorporates a server-maintained pricing mechanism specifically for $SELF. This ensures that the $SELF token price is always current and reliable, offering a complementary layer of accuracy alongside Chainlink's real-time price feeds for other tokens.
     
     * * Enhanced Agent Commissions: In addition to allowing third-party agents to earn commissions from facilitating name registrations, this addon extends that capability by enabling agents to earn commissions in multiple types of tokens, not just a single one as was the case in the original contract.


     */

    //=================Setup===================

    /**
     * * SETUP ADMIN
     *
     * Deploy SelfNftMultitokenAddon.sol with the following params:
     * _selfToken: 0x0
     * _selfNft: 0x0
     *
     * set $SELF price feed
     * add payment token price feeds with correct params
     * approve $SELF tokens to SelfNftMultitokenAddon.sol so you can deposit them
     * deposit $SELF tokens to SelfNftMultitokenAddon.sol
     * approve $SELF tokens to SelfNft.sol (using approveSelfTokens() function ) so this contract can register name.
     * SETUP USER
     * approve payment tokens to SelfNftMultitokenAddon.sol so you can register names using them
     * call registerName() with the name you want to register and the payment token you want to use
     *
     */

    constructor(address _selfToken, address _selfNft) {
        if (_selfToken == address(0)) revert ZeroAddressError();
        if (_selfNft == address(0)) revert ZeroAddressError();

        selfToken = IERC20(_selfToken);
        selfNft = ISelfNft(_selfNft);
    }

    /**
     * @notice Registers a name(NFT) for the caller and transfers the corresponding NFT.
     * @dev This function performs several checks and operations:
     *      1. Validates the name price in SELF tokens.
     *      2. Checks for sufficient deposited SELF tokens.
     *      3. Calculates the price in the specified buyToken.
     *      4. Handles agent commission if applicable.
     *      5. Transfers the buyToken from the user to this contract.
     *      6. Registers the name in the selfNft contract.
     *      7. Transfers the corresponding NFT to the user.
     * @param _name The name to be registered.
     * @param _paymentToken The token to be used for payment.
     * @param _agentAddress The address of the agent, if any, to handle the commission.
     * @return A boolean value indicating whether the operation was successful.
     */
    function registerName(
        string calldata _name,
        address _paymentToken,
        address _agentAddress
    ) external whenNotPaused nonReentrant returns (bool) {
        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert UnsupportedPaymentToken();
        // Validate the price of the name in SELF tokens
        uint256 priceInSelf = selfNft.getPrice(_name);
        // priceInSelf is in 10^6 so we are upscaling it to 10 **18

        priceInSelf = priceInSelf * (10 ** (18 - SELF_NFT_PRICE_DECIMALS));

        // Check for sufficient deposited SELF tokens
        if (depositedSelfTokens < priceInSelf)
            revert InsufficientSelfTokens(depositedSelfTokens, priceInSelf);

        // Calculate the price in the specified buyToken
        uint256 priceInPaymentTkn = _getPrice(_paymentToken, priceInSelf);

        if (priceInPaymentTkn == 0) revert InvlaidPrice();

        // Handle agent commission if applicable
        uint256 netPrice = _handleAgentCommission(
            _agentAddress,
            priceInPaymentTkn,
            _paymentToken
        );

        // Update the total collected tokens for the specified buyToken
        chainlinkPriceFeeds[_paymentToken].collectedTokens += netPrice;

        // Transfer the buyToken from the user to this contract
        IERC20(_paymentToken).safeTransferFrom(
            msg.sender,
            address(this),
            priceInPaymentTkn
        );

        // Register the name in the selfNft contract
        selfNft.registerName(_name);

        // Transfer the corresponding NFT to the user
        selfNft.safeTransferFrom(address(this), msg.sender, _hashString(_name));

        // Emit an event to log the successful name registration
        emit NameRegistered(msg.sender, _name, _agentAddress, _paymentToken);

        return true;
    }

    /**
     * @notice Adds a new agent with a specified commission rate.
     * @dev Only the contract owner can add an agent. The function checks for:
     *      1. Existing agent status.
     *      2. Validity of the agent address.
     *      3. Validity of the commission rate.
     * @param _agentAddress The address of the agent to be added.
     * @param _commissionRate The commission rate for the agent in percentage (0-100). It must be multiplied by 10^6 for better precision.
     */
    function addAgent(
        address _agentAddress,
        uint256 _commissionRate
    ) external onlyOwner {
        // Check for zero address
        if (_agentAddress == address(0)) revert ZeroAddressError();

        // Check if the address is already an agent
        if (agents[_agentAddress].commissionRate != 0) revert AlreadyAgent();

        // Validate the commission rate (should be between 1e6 and 100e6)
        if (_commissionRate == 0 || _commissionRate > 100e6)
            revert InvalidCommissionRate();

        // Add the agent with the specified commission rate
        agents[_agentAddress].commissionRate = _commissionRate;

        // Emit an event to log the agent addition
        emit AgentAdded(_agentAddress, _commissionRate);
    }

    /**
     * @notice Updates the commission rate for an existing agent.
     * @dev Only the contract owner can update an agent's commission rate. The function checks for:
     *      1. Existing agent status.
     *      2. Validity of the new commission rate.
     * @param _agentAddress The address of the agent whose commission rate is to be updated.
     * @param _commissionRate The new commission rate for the agent in percentage (0-100).It must be multiplied by 10^6 for better precision.
     */
    function updateAgentCommission(
        address _agentAddress,
        uint256 _commissionRate
    ) external onlyOwner {
        // Check for zero address
        if (_agentAddress == address(0)) revert ZeroAddressError();

        // Validate the new commission rate (should be between 1e6 and 100e6)
        if (_commissionRate == 0 || _commissionRate > 100e6)
            revert InvalidCommissionRate();

        // Check if the address is already an agent
        if (agents[_agentAddress].commissionRate == 0) revert NotAnAgent();

        // Update the agent's commission rate
        agents[_agentAddress].commissionRate = _commissionRate;

        // Emit an event to log the commission rate update
        emit AgentCommisionUpdated(_agentAddress, _commissionRate);
    }

    /**
     * @notice Removes an existing agent from the contract.
     * @dev Only the contract owner can remove an agent. The function checks for:
     *      1. Validity of the agent address.
     *      2. Existing agent status.
     * @param _agentAddress The address of the agent to be removed.
     */
    function removeAgent(address _agentAddress) external onlyOwner {
        // Check for zero address
        if (_agentAddress == address(0)) revert ZeroAddressError();

        // Check if the address is already an agent
        if (agents[_agentAddress].commissionRate == 0) revert NotAnAgent();

        // Remove the agent by setting their commission rate to 0
        agents[_agentAddress].commissionRate = 0;

        // Emit an event to log the agent removal
        emit AgentRemoved(_agentAddress);
    }

    /**
     * @notice Allows an agent to withdraw their earned commission.
     * @dev The function performs several checks:
     *      1. Checks if the agent has earned any commission for the specified token.
     *      2. Resets the agent's earned commission for the token to zero.
     *      3. Transfers the commission to the agent.
     * @param _paymentToken The token in which the commission is to be withdrawn.
     */
    function withdrawCommission(address _paymentToken) external nonReentrant {
        //Check if caller is an agent
        if (agents[msg.sender].commissionRate == 0) revert NotAnAgent();

        // Validate the commission amount
        uint256 commission = agents[msg.sender].earnedCommissions[
            _paymentToken
        ];
        if (commission == 0) revert InvalidCommissionAmount();

        // Reset the agent's earned commission for the token to zero
        agents[msg.sender].earnedCommissions[_paymentToken] = 0;

        // Transfer the commission to the agent
        IERC20(_paymentToken).safeTransfer(msg.sender, commission);

        // Emit an event to log the commission withdrawal
        emit CommisionWithdrawn(msg.sender, _paymentToken, commission);
    }

    /**
     * @notice Approves a specified amount of SELF tokens to be spent by the selfNft contract.
     * @dev Only the contract owner can approve SELF tokens. The function checks for:
     *      1. Validity of the approval amount.
     * @param _amount The amount of SELF tokens to approve.
     */
    function approveSelfTokens(uint _amount) external onlyOwner {
        // Approve the SELF tokens for the selfNft contract
        selfToken.approve(address(selfNft), _amount);

        // Emit an event to log the approval
        emit SelfTokensApproved(address(selfNft), _amount);
    }

    /**
     * @notice Deposits a specified amount of SELF tokens into the contract.
     * @dev Only the contract owner can deposit SELF tokens. The function performs the following steps:
     *      1. Validates the deposit amount.
     *      2. Updates the total deposited SELF tokens.
     *      3. Transfers the SELF tokens from the owner to this contract.
     * @param _amount The amount of SELF tokens to deposit.
     */
    function depositSelfTokens(uint _amount) external onlyOwner {
        // Validate the deposit amount
        if (_amount == 0) revert InvalidDepositAmount();

        // Update the total deposited SELF tokens
        depositedSelfTokens += _amount;

        // Transfer the SELF tokens from the owner to this contract
        selfToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Emit an event to log the deposit
        emit SelfTokensDeposited(_amount);
    }

    /**
     * @notice Withdraws all deposited SELF tokens from the contract back to the owner.
     * @dev Only the contract owner can withdraw SELF tokens. The function performs the following steps:
     *      1. Validates the withdrawal amount.
     *      2. Transfers the deposited SELF tokens back to the owner.
     *      3. Resets the total deposited SELF tokens to zero.
     */
    function withdrawSelfTokens() external onlyOwner {
        uint256 _depositedSelfTokens = depositedSelfTokens;
        // Validate the withdrawal amount
        if (_depositedSelfTokens == 0) revert InvalidWithdrawAmount();

        // Reset the total deposited SELF tokens to zero
        depositedSelfTokens = 0;

        // Transfer the deposited SELF tokens back to the owner
        selfToken.safeTransfer(msg.sender, _depositedSelfTokens);

        // Emit an event to log the withdrawal
        emit SelfTokensWithdrawn(_depositedSelfTokens);
    }

    /**
     * @notice Updates the address of the selfNft contract.
     * @param _selfNft The new address of the selfNft contract.
     */
    function setSelfNft(address _selfNft) external onlyOwner {
        // Validate the new selfNft address
        if (_selfNft == address(0)) revert ZeroAddressError();

        // Update the selfNft contract address
        selfNft = ISelfNft(_selfNft);

        // Emit an event to log the selfNft address update
        emit SelfNftUpdated(_selfNft);
    }

    /**
     * @notice Adds a new Chainlink price feed for a specific payment token.
     * @dev Only the contract owner can add a Chainlink price feed. The function performs the following checks:
     *      1. Validates the payment token address.
     *      2. Validates the price feed address.
     *      3. Validates the decimals for the payment token.
     *      4. Checks if a price feed already exists for the payment token.
     * @param _paymentToken The address of the payment token.
     * @param _priceFeed The address of the Chainlink price feed.
     * @param _decimals The number of decimals for the payment token.
     */
    function addChainlinkPricefeed(
        address _paymentToken,
        address _priceFeed,
        uint8 _decimals
    ) external onlyOwner {
        // Validate the payment token address
        if (_paymentToken == address(0)) revert ZeroAddressError();

        // Validate the new price feed address
        if (_priceFeed == address(0)) revert ZeroAddressError();

        // Validate the decimals for the payment token
        if (_decimals < 6) revert InvalidTokenDecimals();

        // Check if a price feed already exists for the payment token
        if (chainlinkPriceFeeds[_paymentToken].paymentToken != address(0))
            revert PriceFeedAlreadyAdded();

        // Add the new Chainlink price feed for the payment token
        chainlinkPriceFeeds[_paymentToken] = PaymentToken(
            AggregatorV3Interface(_priceFeed),
            _paymentToken,
            _decimals,
            0
        );

        // Emit an event to log the addition of the new Chainlink price feed
        emit ChainlinkPriceFeedAdded(_paymentToken, _priceFeed);
    }

    /**
     * @notice Updates an existing Chainlink price feed for a specific payment token.
     * @dev Only the contract owner can update a Chainlink price feed. The function performs the following checks:
     *      1. Validates the payment token address.
     *      2. Validates the new price feed address.
     *      3. Validates the decimals for the payment token.
     *      4. Checks if a price feed already exists for the payment token. If it doesn't revert.
     * @param _paymentToken The address of the payment token.
     * @param _priceFeed The new address of the Chainlink price feed.
     * @param _decimals The number of decimals for the payment token.
     */
    function updateChainlinkPricefeed(
        address _paymentToken,
        address _priceFeed,
        uint8 _decimals
    ) external onlyOwner {
        // Validate the payment token address
        if (_paymentToken == address(0)) revert ZeroAddressError();

        // Validate the new price feed address
        if (_priceFeed == address(0)) revert ZeroAddressError();

        // Validate the decimals for the payment token
        if (_decimals < 6) revert InvalidTokenDecimals();

        // Check if a price feed already exists for the payment token
        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert NotAPriceFeed();

        // Update the Chainlink price feed for the payment token
        chainlinkPriceFeeds[_paymentToken] = PaymentToken(
            AggregatorV3Interface(_priceFeed),
            _paymentToken,
            _decimals,
            chainlinkPriceFeeds[_paymentToken].collectedTokens
        );

        // Emit an event to log the update of the Chainlink price feed
        emit ChainlinkPriceFeedUpdated(_paymentToken, _priceFeed);
    }

    /**
     * @notice Removes an existing Chainlink price feed for a specific payment token.
     * @dev Only the contract owner can remove a Chainlink price feed. The function performs the following checks:
     *      1. Validates the payment token address.
     *      2. Checks if a price feed already exists for the payment token.
     * @param _paymentToken The address of the payment token.
     */
    function removeChainlinkPricefeed(
        address _paymentToken
    ) external onlyOwner {
        // Validate the payment token address
        if (_paymentToken == address(0)) revert ZeroAddressError();

        // Check if a price feed already exists for the payment token
        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert NotAPriceFeed();

        // Remove the Chainlink price feed for the payment token
        chainlinkPriceFeeds[_paymentToken].paymentToken = address(0);

        // Transfer the collected tokens to the contract owner if any
        uint _collectedTokens = chainlinkPriceFeeds[_paymentToken]
            .collectedTokens;

        if (_collectedTokens > 0)
            IERC20(_paymentToken).safeTransfer(msg.sender, _collectedTokens);

        // Emit an event to log the removal of the Chainlink price feed
        emit ChainlinkPriceFeedRemoved(_paymentToken);
    }

    /**
     * @notice Forwards the collected payment tokens to the contract owner.
     * @dev Only the contract owner can forward collected tokens. The function performs the following checks:
     *      1. Validates the payment token address.
     *      2. Checks if a price feed exists for the payment token.
     *      3. Validates the amount of collected tokens.
     * @param _paymentToken The address of the payment token.
     */
    function forwardCollectedTokens(address _paymentToken) external onlyOwner {
        // Validate the payment token address
        if (_paymentToken == address(0)) revert ZeroAddressError();

        // Check if a price feed exists for the payment token
        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert NotAPriceFeed();

        // Get the amount of collected tokens
        uint256 _collectedTokens = chainlinkPriceFeeds[_paymentToken]
            .collectedTokens;

        // Validate the amount of collected tokens
        if (_collectedTokens == 0) revert InsufficientCollectedTokens();

        // Reset the collected tokens to zero
        chainlinkPriceFeeds[_paymentToken].collectedTokens = 0;

        // Transfer the collected tokens to the contract owner
        IERC20(_paymentToken).safeTransfer(msg.sender, _collectedTokens);

        // Emit an event to log the forwarding of collected tokens
        emit CollectedTokensForwarded(msg.sender, _collectedTokens);
    }

    /**
     * @notice Updates the price of the SELF token.
     * @param _price The new price of the SELF token.
     * @dev _price must be multiplied by 10**18
     */
    function setSelfPrice(uint256 _price) external onlyOwner {
        // Validate the new SELF token price
        if (_price == 0) revert InvalidSelfPrice();

        // Update the SELF token price
        selfPrice = _price;

        // Emit an event to log the update of the SELF token price
        emit SelfPriceUpdated(_price);
    }

    /// @notice Pauses the contract, disabling name registration and other functions.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, enabling name registration and other functions.
    function unpause() external onlyOwner {
        _unpause();
    }

    function getEarnedCommision(
        address _agent,
        address _payToken
    ) external view returns (uint256) {
        return agents[_agent].earnedCommissions[_payToken];
    }

    /**
     * @notice Retrieves the price of a given name in a specified payment token.
     * @dev This function uses Chainlink price feeds to get the price of the payment token in USD.
     *      It then calls the `_calculatePriceInPaymentToken` function to get the final price.
     *      The function performs the following checks:
     *      1. Checks if the payment token is supported.
     * @param _name The name whose price needs to be fetched.
     * @param _paymentToken The address of the token in which the price will be returned.
     * @return The price of the name in the specified payment token, adjusted to its decimals.
     */
    function getPrice(
        string memory _name,
        address _paymentToken
    ) public view returns (uint256) {
        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert UnsupportedPaymentToken();

        uint namePrice = selfNft.getPrice(_name);

        namePrice = namePrice * (10 ** (18 - SELF_NFT_PRICE_DECIMALS));

        return _getPrice(_paymentToken, namePrice);
    }

    function _getPrice(
        address _paymentToken,
        uint256 _namePrice
    ) internal view returns (uint) {
        // Fetch the Chainlink price feed for the payment token
        PaymentToken memory token = chainlinkPriceFeeds[_paymentToken];

        // Calculate and return the price of the name in the specified payment token
        return
            _calculatePriceInPaymentToken(
                _namePrice, // Name price in SELF tokens
                selfPrice, // SELF token price in USD
                uint256(_getLatestData(token.priceFeed)), // Payment token price in USD
                token.decimals // Payment token decimals
            );
    }

    /**
     * @notice Handles the commission for agents during a name registration transaction.
     * @dev This internal function calculates the commission for an agent based on the provided rate and adjusts the final price accordingly.
     *      The function performs the following checks:
     *      1. Checks if an agent address is provided.
     *      2. Validates the agent's commission rate.
     * @param _agentAddress The address of the agent.
     * @param _price The original price of the name registration.
     * @param _paymentToken The address of the payment token used for the transaction.
     * @return The adjusted price after deducting the agent's commission.
     */
    function _handleAgentCommission(
        address _agentAddress,
        uint256 _price,
        address _paymentToken
    ) internal returns (uint256) {
        // Check if an agent address is provided
        if (
            _agentAddress == address(0) ||
            agents[_agentAddress].commissionRate == 0
        ) {
            return _price; // No agent, return the original price
        }

        // Fetch the agent's details
        Agent storage agent = agents[_agentAddress];

        // Calculate the agent's commission
        uint256 commission = ((_price * agent.commissionRate) / 100) / 10 ** 6;

        // Add the calculated commission to the agent's earned commissions
        agent.earnedCommissions[_paymentToken] += commission;

        // Return the price after deducting the agent's commission
        return _price - commission;
    }

    /**
     * @notice Calculates the price of a name in a specific payment token.
     * @dev Adjusts for different decimal places in each token and performs the calculation.
     * @param _namePrice Price of the name in SELF token (1 8 decimals).
     * @param _selfPrice Price of the SELF token in USD (18 decimals).
     * @param _payTokenPrice Price of the payment token in USD (dynamic decimals).
     * @param _payDecimals Number of decimals for the payment token.
     * @return The price of the name in the payment token, adjusted to its decimals.
     */
    function _calculatePriceInPaymentToken(
        uint256 _namePrice,
        uint256 _selfPrice,
        uint256 _payTokenPrice,
        uint8 _payDecimals
    ) internal pure returns (uint256) {
        // Revert transaction if any token price is zero
        if (_namePrice == 0) revert InvalidNamePrice();

        if (_selfPrice == 0 || _payTokenPrice == 0) revert InvalidTokenPrice();

        if (_payDecimals < 6) revert InvalidTokenDecimals();

        // Adjust the price of the payment token to 18 decimals
        uint256 adjPayPrice = _payTokenPrice * 10 ** (18 - CHAINLINK_DECIMALS);

        // Perform the price calculation with all values in 18 decimals
        uint256 calcPrice = (_namePrice * _selfPrice) / adjPayPrice;

        // Adjust the calculated price back to the payment token's decimals
        return (calcPrice * 10 ** (_payDecimals)) / 10 ** 18;
    }

    /**
     * @notice Retrieves the latest price data from a Chainlink Aggregator.
     * @dev This function calls the `latestRoundData()` method on the provided Chainlink Aggregator contract
     *      and returns the latest price. It ignores other data returned by `latestRoundData()`.
     * @param _priceFeed The Chainlink Aggregator contract from which to fetch the latest price.
     * @return The latest price as an integer.
     */
    function _getLatestData(
        AggregatorV3Interface _priceFeed
    ) internal view returns (int) {
        // Fetch the latest round data from the Chainlink Aggregator
        // Note: Ignoring other returned values except for 'answer'
        // prettier-ignore
        // Check if the payment token is supported
        if (_priceFeed == AggregatorV3Interface(address(0)))
            revert NotAPriceFeed();

        (
            ,
            /* uint80 roundID */ int answer /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = _priceFeed.latestRoundData();

        // Return the latest price
        return answer;
    }

    function _hashString(string memory _str) private pure returns (uint256) {
        return uint256(keccak256(bytes(_str)));
    }

    //=================Required by solidity===================
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
