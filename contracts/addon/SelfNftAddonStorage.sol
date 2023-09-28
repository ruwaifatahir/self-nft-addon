// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/ISelfNft.sol";

contract SelfNftAddonStorage {
    struct PaymentToken {
        AggregatorV3Interface priceFeed;
        address paymentToken;
        uint8 decimals;
        uint256 collectedTokens;
    }

    struct Agent {
        uint256 commissionRate;
        mapping(address => uint256) earnedCommissions;
    }

    uint8 public constant CHAINLINK_DECIMALS = 8;

    uint8 public constant SELF_NFT_PRICE_DECIMALS = 6;

    ISelfNft public selfNft;

    IERC20 public selfToken;

    uint public selfPrice;

    uint public depositedSelfTokens;

    mapping(address => PaymentToken) public chainlinkPriceFeeds;

    mapping(address => Agent) public agents;

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
