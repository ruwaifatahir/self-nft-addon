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
    
     */ ///

    constructor(address _selfToken, address _selfNft) {
        if (_selfToken == address(0)) revert ZeroAddressError();
        if (_selfNft == address(0)) revert ZeroAddressError();

        selfToken = IERC20(_selfToken);
        selfNft = ISelfNft(_selfNft);
    }

    function registerName(
        string calldata _name,
        address _paymentToken,
        address _agentAddress
    ) external whenNotPaused nonReentrant returns (bool) {
        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert UnsupportedPaymentToken();
        uint256 priceInSelf = selfNft.getPrice(_name);

        priceInSelf = priceInSelf * (10 ** (18 - SELF_NFT_PRICE_DECIMALS));

        if (depositedSelfTokens < priceInSelf)
            revert InsufficientSelfTokens(depositedSelfTokens, priceInSelf);

        uint256 priceInPaymentTkn = _getPrice(_paymentToken, priceInSelf);

        if (priceInPaymentTkn == 0) revert InvlaidPrice();

        uint256 netPrice = _handleAgentCommission(
            _agentAddress,
            priceInPaymentTkn,
            _paymentToken
        );

        chainlinkPriceFeeds[_paymentToken].collectedTokens += netPrice;

        IERC20(_paymentToken).safeTransferFrom(
            msg.sender,
            address(this),
            priceInPaymentTkn
        );

        selfNft.registerName(_name);

        selfNft.safeTransferFrom(address(this), msg.sender, _hashString(_name));

        emit NameRegistered(msg.sender, _name, _agentAddress, _paymentToken);

        return true;
    }

    function addAgent(
        address _agentAddress,
        uint256 _commissionRate
    ) external onlyOwner {
        if (_agentAddress == address(0)) revert ZeroAddressError();

        if (agents[_agentAddress].commissionRate != 0) revert AlreadyAgent();

        if (_commissionRate == 0 || _commissionRate > 100e6)
            revert InvalidCommissionRate();

        agents[_agentAddress].commissionRate = _commissionRate;

        emit AgentAdded(_agentAddress, _commissionRate);
    }

    function updateAgentCommission(
        address _agentAddress,
        uint256 _commissionRate
    ) external onlyOwner {
        if (_agentAddress == address(0)) revert ZeroAddressError();

        if (_commissionRate == 0 || _commissionRate > 100e6)
            revert InvalidCommissionRate();

        if (agents[_agentAddress].commissionRate == 0) revert NotAnAgent();

        agents[_agentAddress].commissionRate = _commissionRate;

        emit AgentCommisionUpdated(_agentAddress, _commissionRate);
    }

    function removeAgent(address _agentAddress) external onlyOwner {
        if (_agentAddress == address(0)) revert ZeroAddressError();

        if (agents[_agentAddress].commissionRate == 0) revert NotAnAgent();

        agents[_agentAddress].commissionRate = 0;

        emit AgentRemoved(_agentAddress);
    }

    function withdrawCommission(address _paymentToken) external nonReentrant {
        if (agents[msg.sender].commissionRate == 0) revert NotAnAgent();

        uint256 commission = agents[msg.sender].earnedCommissions[
            _paymentToken
        ];
        if (commission == 0) revert InvalidCommissionAmount();

        agents[msg.sender].earnedCommissions[_paymentToken] = 0;

        IERC20(_paymentToken).safeTransfer(msg.sender, commission);

        emit CommisionWithdrawn(msg.sender, _paymentToken, commission);
    }

    function approveSelfTokens(uint _amount) external onlyOwner {
        selfToken.approve(address(selfNft), _amount);

        emit SelfTokensApproved(address(selfNft), _amount);
    }

    function depositSelfTokens(uint _amount) external onlyOwner {
        if (_amount == 0) revert InvalidDepositAmount();

        depositedSelfTokens += _amount;

        selfToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit SelfTokensDeposited(_amount);
    }

    function withdrawSelfTokens() external onlyOwner {
        uint256 _depositedSelfTokens = depositedSelfTokens;
        if (_depositedSelfTokens == 0) revert InvalidWithdrawAmount();

        depositedSelfTokens = 0;

        selfToken.safeTransfer(msg.sender, _depositedSelfTokens);

        emit SelfTokensWithdrawn(_depositedSelfTokens);
    }

    function setSelfNft(address _selfNft) external onlyOwner {
        if (_selfNft == address(0)) revert ZeroAddressError();

        selfNft = ISelfNft(_selfNft);

        emit SelfNftUpdated(_selfNft);
    }

    function addChainlinkPricefeed(
        address _paymentToken,
        address _priceFeed,
        uint8 _decimals
    ) external onlyOwner {
        if (_paymentToken == address(0)) revert ZeroAddressError();

        if (_priceFeed == address(0)) revert ZeroAddressError();

        if (_decimals < 6) revert InvalidTokenDecimals();

        if (chainlinkPriceFeeds[_paymentToken].paymentToken != address(0))
            revert PriceFeedAlreadyAdded();

        chainlinkPriceFeeds[_paymentToken] = PaymentToken(
            AggregatorV3Interface(_priceFeed),
            _paymentToken,
            _decimals,
            0
        );

        emit ChainlinkPriceFeedAdded(_paymentToken, _priceFeed);
    }

    function updateChainlinkPricefeed(
        address _paymentToken,
        address _priceFeed,
        uint8 _decimals
    ) external onlyOwner {
        if (_paymentToken == address(0)) revert ZeroAddressError();

        if (_priceFeed == address(0)) revert ZeroAddressError();

        if (_decimals < 6) revert InvalidTokenDecimals();

        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert NotAPriceFeed();

        chainlinkPriceFeeds[_paymentToken] = PaymentToken(
            AggregatorV3Interface(_priceFeed),
            _paymentToken,
            _decimals,
            chainlinkPriceFeeds[_paymentToken].collectedTokens
        );

        emit ChainlinkPriceFeedUpdated(_paymentToken, _priceFeed);
    }

    function removeChainlinkPricefeed(
        address _paymentToken
    ) external onlyOwner {
        if (_paymentToken == address(0)) revert ZeroAddressError();

        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert NotAPriceFeed();

        chainlinkPriceFeeds[_paymentToken].paymentToken = address(0);

        uint _collectedTokens = chainlinkPriceFeeds[_paymentToken]
            .collectedTokens;

        if (_collectedTokens > 0) {
            chainlinkPriceFeeds[_paymentToken].collectedTokens = 0;
            IERC20(_paymentToken).safeTransfer(msg.sender, _collectedTokens);
        }

        emit ChainlinkPriceFeedRemoved(_paymentToken);
    }

    function forwardCollectedTokens(address _paymentToken) external onlyOwner {
        if (_paymentToken == address(0)) revert ZeroAddressError();

        if (chainlinkPriceFeeds[_paymentToken].paymentToken == address(0))
            revert NotAPriceFeed();

        uint256 _collectedTokens = chainlinkPriceFeeds[_paymentToken]
            .collectedTokens;

        if (_collectedTokens == 0) revert InsufficientCollectedTokens();

        chainlinkPriceFeeds[_paymentToken].collectedTokens = 0;

        IERC20(_paymentToken).safeTransfer(msg.sender, _collectedTokens);

        emit CollectedTokensForwarded(msg.sender, _collectedTokens);
    }

    function setSelfPrice(uint256 _price) external onlyOwner {
        if (_price == 0) revert InvalidSelfPrice();

        selfPrice = _price;

        emit SelfPriceUpdated(_price);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getEarnedCommision(
        address _agent,
        address _payToken
    ) external view returns (uint256) {
        return agents[_agent].earnedCommissions[_payToken];
    }

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
        PaymentToken memory token = chainlinkPriceFeeds[_paymentToken];

        return
            _calculatePriceInPaymentToken(
                _namePrice,
                selfPrice,
                uint256(_getLatestData(token.priceFeed)),
                token.decimals
            );
    }

    function _handleAgentCommission(
        address _agentAddress,
        uint256 _price,
        address _paymentToken
    ) internal returns (uint256) {
        if (
            _agentAddress == address(0) ||
            agents[_agentAddress].commissionRate == 0
        ) {
            return _price;
        }

        Agent storage agent = agents[_agentAddress];

        uint256 commission = ((_price * agent.commissionRate) / 100) / 10 ** 6;

        agent.earnedCommissions[_paymentToken] += commission;

        return _price - commission;
    }

    function _calculatePriceInPaymentToken(
        uint256 _namePrice,
        uint256 _selfPrice,
        uint256 _payTokenPrice,
        uint8 _payDecimals
    ) internal pure returns (uint256) {
        if (_namePrice == 0) revert InvalidNamePrice();

        if (_selfPrice == 0 || _payTokenPrice == 0) revert InvalidTokenPrice();

        if (_payDecimals < 6) revert InvalidTokenDecimals();

        uint256 adjPayPrice = _payTokenPrice * 10 ** (18 - CHAINLINK_DECIMALS);

        uint256 calcPrice = (_namePrice * _selfPrice) / adjPayPrice;

        return (calcPrice * 10 ** (_payDecimals)) / 10 ** 18;
    }

    function _getLatestData(
        AggregatorV3Interface _priceFeed
    ) internal view returns (int) {
        // Fetch the latest round data from the Chainlink Aggregator
        // Note: Ignoring other returned values except for 'answer'
        // prettier-ignore
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
