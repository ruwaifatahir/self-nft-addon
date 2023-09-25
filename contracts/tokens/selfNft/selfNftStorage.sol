// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SelfNftStorage {
    //=================Datatypes===================

    ///@dev Represents an agent who can perform reistrations for users and earn commission.
    struct Agent {
        bool isAgent;
        uint commission; //should be in 10**6
    }

    //=================State===================
    ///@dev Mapping to store the real value of hashed name
    mapping(uint256 => string) public tokenIdToName;

    ///@dev Mapping to store the price of a name based on its length
    mapping(uint256 => uint256) public lengthToPrice;

    ///@dev Mapping to store names reserved for only owner of the contract
    mapping(string => bool) public reservedNames;

    ///@dev Mapping to keep track of verified agents
    mapping(address => Agent) public agents;

    ///@dev Self ERC20 Interface
    IERC20 public self;

    ///@dev Var to keep track of self collected from registrations.
    uint256 public collectedSelf;

    ///@dev The words that should not be allowed at the start of any name. Only the administrator can register names that start with the prohibited words.

    string[] public reservedWords = ["v_", "self", "seif"];

    //=================Events===================
    event NameRegistered(address indexed owner, string name, uint tokenId);
    event MetadataUpdated(uint256 indexed tokenId, string metadata);
    event PriceUpdated(uint256 indexed length, uint256 indexed price);
    event SelfTokenUpdated(address indexed newSelfToken);
    event CollectedSelfForwarded(address indexed receiver, uint256 amount);
    event AgentAdded(address indexed agent, uint commission);
    event AgentUpdated(address indexed agent, uint commission);
    event AgentRemoved(address indexed agent);
    event NameReserved(string indexed name);
    event NameUnreserved(string indexed name);

    //=================Errors===================
    error NotNameOwnerError();
    error NameLengthOutOfRangeError();
    error UnderscoreStartError();
    error ConsecutiveUnderscoreError();
    error ReservedWordStartError();
    error NameReservedError();
    error NameNotReservedError();
    error PriceNotSet();
    error NameAlreadyRegisteredError();

    error AlreadyAgentError();
    error NotAgentError();
    error InvalidCommissionError();

    error InvalidAddressError();
    error NoTokensAvailableError();
}
