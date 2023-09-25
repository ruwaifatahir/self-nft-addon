// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

interface ISelfNft is IERC721 {
    function registerName(string calldata _name) external returns (bool);

    function getPrice(string memory _name) external view returns (uint256);
}
