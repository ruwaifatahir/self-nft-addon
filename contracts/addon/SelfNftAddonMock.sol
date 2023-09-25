// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {SelfNftAddon} from "./SelfNftAddon.sol";

contract SelfNftAddonMock is SelfNftAddon {
    constructor(
        address _selfToken,
        address _selfNft
    ) SelfNftAddon(_selfToken, _selfNft) {}

    function calculatePriceInPaymentToken(
        uint256 namePrice,
        uint256 selfPrice,
        uint256 payTokenPrice,
        uint8 payDecimals
    ) external view returns (uint) {
        return
            _calculatePriceInPaymentToken(
                namePrice,
                selfPrice,
                payTokenPrice,
                payDecimals
            );
    }

    function __setSelfPrice(uint256 _price) external onlyOwner {
        selfPrice = _price;
    }
}
