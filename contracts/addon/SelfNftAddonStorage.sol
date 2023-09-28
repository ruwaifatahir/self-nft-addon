// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/ISelfNft.sol";

contract SelfNftAddonStorage {
    //=================Datatypes===================

    /// @dev This struct represents a payment token type within the contract
    struct PaymentToken {
        AggregatorV3Interface priceFeed; // The Chainlink price feed aggregator contract for real-time price updates
        address paymentToken; // The ERC20 token address used for payments
        uint8 decimals; // The number of decimals for the payment token, for precision
        uint256 collectedTokens; // The total amount of this token collected for payments
    }

    /// @dev This struct represents an Agent type within the contract.
    struct Agent {
        uint256 commissionRate; // The commission rate for the agent, as a percentage (0-100) and it is multiplied by 10^6
        mapping(address => uint256) earnedCommissions; // Mapping of commissions earned by the agent for each payment token.
    }

    //=================State=======================

    // Constant to store the number of decimals used by Chainlink oracles
    uint8 public constant CHAINLINK_DECIMALS = 8;

    // Constant to store the number of decimals used for pricing the Self NFT
    uint8 public constant SELF_NFT_PRICE_DECIMALS = 6;

    // Interface for interacting with the SelfNft contract
    ISelfNft public selfNft;

    // Interface for interacting with the SelfToken ERC20 contract
    IERC20 public selfToken;

    // Variable to store the latest price of $SELF
    uint public selfPrice;

    // The total amount of $SELF tokens deposited
    uint public depositedSelfTokens;

    // Mapping to keep track of payment token addresses and their corresponding Chainlink price feeds. Note: Key of this mapping is payment token address not the price feed address
    mapping(address => PaymentToken) public chainlinkPriceFeeds;

    // Mapping to keep track of agents and their details
    mapping(address => Agent) public agents;

    //=================Events======================
    event NameRegistered(
        address indexed owner,
        string name,
        address indexed agent,
        address indexed paymentToken
    );
    event CollectedTokensForwarded(address indexed receiver, uint256 amount);
    event SelfNftUpdated(address indexed newSelfNft);
    event PaymentTokenUpdated(address indexed newBuyToken);
    event PriceUpdated(uint256 indexed length, uint256 indexed price);
    event SelfTokensApproved(address indexed spender, uint256 amount);
    event SelfTokensDeposited(uint256 amount);
    event SelfTokensWithdrawn(uint256 amount);
    event AgentAdded(address indexed agent, uint commission);
    event AgentCommisionUpdated(address indexed agent, uint commission);
    event AgentRemoved(address indexed agent);
    event CommisionWithdrawn(
        address indexed agent,
        address indexed paymentToken,
        uint256 amount
    );
    event SelfPriceUpdated(uint256 indexed price);
    event ChainlinkPriceFeedAdded(
        address indexed paymentToken,
        address indexed priceFeed
    );
    event ChainlinkPriceFeedUpdated(
        address indexed paymentToken,
        address indexed priceFeed
    );

    event ChainlinkPriceFeedRemoved(address indexed paymentToken);

    //=================Errors======================
    error ZeroAddressError();
    error InvalidCommissionRate();
    error InvalidCommissionAmount();
    error InvalidApproveAmount();
    error InvalidDepositAmount();
    error InvalidWithdrawAmount();
    error InvalidSelfPrice();
    error UnsupportedPaymentToken();
    error InsufficientSelfTokens(uint256 deposited, uint256 required);

    error InvalidTokenPrice();
    error InvalidTokenDecimals();
    error InvalidNamePrice();
    error NotAnAgent();
    error AlreadyAgent();
    error PriceFeedAlreadyAdded();
    error NotAPriceFeed();

    error InsufficientCollectedTokens();

    error InvlaidPrice();
}
