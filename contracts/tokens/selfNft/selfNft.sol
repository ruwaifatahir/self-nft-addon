// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {SelfNftStorage} from "./selfNftStorage.sol";

contract SelfNft is
    SelfNftStorage,
    ERC721Royalty,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Pausable,
    Ownable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    //=================State===================\

    /**
     * @title SelfNft
     * @author Self dev team
     * @custom:version v2.2.4
     * @custom:date 6 July 2023

    ------------v2.2.1 changes------------
        - change param convention from "name_" to "_name"
        - update maps to be public and remove map getters
        - add a new function registerName(to, name) to mint a name to any address which can be called by owner. 

        - Add adminRegisterName
        - Add agentRegisterName
        - update/refactor registerName
        - add _registerName
    

        - add functionality to blacklist names
            - add reservedNames map
            - add isBlacklisted modifier
            - add blacklistName func
            - add whitelistName func

        - add royalty functionality 
            - import ERC721Royalty from openzeppelin
            - inherit form it
            - add setDefaultRoyalty function

        - add reserved name starting functionality
            - add isReserved modifier
            - update register(name)

        - add no underscore at the start funcitonality and no consecitive underscore
            - separate length funcitonality from isLegal() and make a new modifier isLegallength
            - add isLegallength() 
            - update isLegal
            - update registerName()

        - replace requrire strings with custom errors

    ------------v2.2.2 changes------------

        - add ERC721Pausable 
        - remove pauseable

    ------------v2.2.3 changes------------
        - change 3 ---> 5 in setPrice()
        - setPrice accepts 10**6
        - update getPrice to not multiply price with 10**18
        - update registerName to multiply price with 10**12
        - update agentRegisterName to not divide with 100 instead of 100_000_000
        - update agentRegisterName to multiply _agentCommission with 10**6
        - update agentRegisterName to multiply _remaining with 10**6
        - update removeAgent() to add NotAgentError custom error
        - update addAgent() to check if _agent is already an agent
        - Add editAgent() function, AgentUpdated event, and AlreadyAgentError error
        - remove return from adminRegisterName() and remove nonReentrant 
        - isNameAvailable() updated to support missing modifiers

    ------------v2.2.4 changes------------
        - replace reservedWord with array reservedWords
        - update containsNoReservedWord modifier to check for reservedWords instead   of reserved word
    
    

     * @notice SelfNft is a smart contract that allows users to mint unique Self Identity NFTs (SIN) based on their provided names. The contract uses OpenZeppelin libraries for secure and standard functionality, including ERC721Enumerable, ERC721URIStorage, Ownable, Pausable, and ReentrancyGuard. It also utilizes SafeERC20 to safely transfer tokens for minting NFTs.
    

     * @dev ERC721Enumerable - ERC721Enumerable is an extension of the ERC721 standard for Non-Fungible   
     Tokens (NFTs). It provides additional functionalities to support the enumeration of NFTs, allowing developers to easily access and interact with the complete set of tokens in a contract.\

     * @dev Token Ownership Enumeration: It allows for the enumeration of tokens owned by a specific address. This enables us to retrieve a list of tokens owned by a user on chain and off chain.

     * @dev ERC721URIStorage -  ERC721URIStorage is an extension of the ERC721 standard, which is focused on providing a storage mechanism for token URIs. Token URIs are used to link an NFT with external resources, such as metadata or media files. This metadata can include descriptions, images, and other relevant information related to the NFT.
     */ ///

    //=================Modifiers===================

    /**
     * @notice  Checks that the input string (name) is of valid length
     * @notice The valid length range for the input string is between 3 and 30 characters (inclusive).
     * @param _name The input string (name) to be checked for valid length.

     */
    modifier isLegalLength(string memory _name) {
        uint nameLength = bytes(_name).length;

        ///@dev validate length of a name
        if (nameLength < 5 || nameLength > 40)
            revert NameLengthOutOfRangeError();

        _;
    }

    /**
     * @notice Checks that the input string (name) consists of valid characters.
     * @notice Allowed characters are lowercase alphabets (a-z), digits (0-9), and underscore (_).
     * @notice Names cannot begin with an underscore, and they cannot contain consecutive underscores.
     * 
     * @param _name The input string (name) to be checked for valid characters and length.
     *
     * @dev This modifier is designed to accept Latin characters. However, there is a minuscule possibility that a non-Latin character could pass the isLegal modifier check due to coincidental overlaps in ASCII code values.

     * The isLegal modifier checks if the ASCII code of a character falls within specific ranges:
        * Lowercase Latin letters (a-z): 97-122
        * Digits (0-9): 48-57
        * Underscore (_): 95

     * Non-Latin characters, such as Cyrillic, Arabic, or Chinese, typically have Unicode code points outside the range of allowed ASCII codes. However, if a non-Latin character coincidentally shares the same ASCII code as a character within the allowed ranges, it would pass the isLegal modifier check.

     * It is important to note that the chances of such an occurrence are extremely low, given the distinct and well-defined nature of ASCII codes for Latin letters and non-Latin characters. In the unlikely event that a non-Latin character does pass the isLegal modifier check, it would be treated as a valid input by the registerName function. This would be an atypical behavior and not the intended functionality of the contract.
     

     */
    modifier isLegal(string memory _name) {
        ///@dev conversion to bytes
        bytes memory _nameBytes = bytes(_name);

        uint8 _current;

        for (uint256 i = 0; i < _nameBytes.length; ++i) {
            _current = uint8(_nameBytes[i]);

            // Check that the first character is not an underscore
            if (i == 0 && _current == 95) revert UnderscoreStartError();

            // Check that there are no consecutive underscores from the second character onwards
            if (i >= 1 && uint8(_nameBytes[i - 1]) == 95 && _current == 95)
                revert ConsecutiveUnderscoreError();

            /**
             * @dev The following conditions check if the current character falls within the following ranges:
             *
             * @dev 97-122: lowercase 'a' to 'z'
             * @dev 48-57: digits '0' to '9'
             * @dev 95: underscore character ('_')
             *
             * @notice This modifier is designed to only accept ASCII characters in the specified ranges. The likelihood of accepting non-latin or non-ASCII characters is extremely low due to these strict conditions.
             */

            require(
                (_current >= 97 && _current <= 122) ||
                    (_current >= 48 && _current <= 57) ||
                    _current == 95,
                "SELF: Invalid Character!"
            );
        }
        _;
    }

    /**
     * @dev This modifier checks if the proposed name does not start with any of  reserved word. It will fail if the name is starting with any of a reserved word.
     * @param _name The name to be checked.
     */
    modifier containsNoReservedWord(string calldata _name) {
        // If the name is at least 4 characters long

        for (uint i = 0; i < reservedWords.length; ++i) {
            string memory _reservedWord = reservedWords[i];
            uint _reservedWordLength = bytes(_reservedWord).length;

            if (_equal(_reservedWord, _name[0:_reservedWordLength]))
                revert ReservedWordStartError();
        }

        _; // Continue execution
    }

    /**
     * @notice A modifier to check if a name is whitelisted.
     * @dev This modifier checks if the proposed name is not blacklisted. It will fail if the name is in the blacklist.
     * @param _name The name to be checked.
     */
    modifier isNameNotReserved(string memory _name) {
        if (reservedNames[_name]) revert NameReservedError();
        _;
    }

    //=================Functions===================

    constructor(address _self) ERC721("Self Identity NFT", "SIN") {
        if (_self == address(0)) revert InvalidAddressError();

        

        self = IERC20(_self);
    }

    /**
     * @dev Registers the specified name.
     * @param _name The name to register.
     * @return A boolean indicating the success of the registration.
     */
    function registerName(
        string calldata _name
    )
        external
        whenNotPaused // Ensures the contract is not paused
        nonReentrant // Prevents reentrancy attacks
        isLegalLength(_name) // Checks the length of the name is legal
        isLegal(_name) // Checks the name is legal
        isNameNotReserved(_name) // Checks if the name is not reserved by admin
        containsNoReservedWord(_name) // Checks if the name contains reserved word
        returns (bool)
    {
        ///@dev get the price of the name
        uint _price = (getPrice(_name)) * 10 ** 12;

        ///@dev checks if the name has a valid price
        if (_price == 0) revert PriceNotSet();

        ///@dev transfer the self from msg.sender to this contract
        self.safeTransferFrom(msg.sender, address(this), _price);

        ///@dev Update the totalSelfCollected
        _registerName(msg.sender, _name);

        collectedSelf += _price;

        return true;
    }

    /**
     * @notice Allows an agent (external service) to register a name for a user on their platform.
     * @dev This function allows an agent (external service) to register a new name for a user. The agent earns a commission for each successful name registration.
     *
     * @param _to The address of the user for whom the name is being registered.
     * @param _name The name to be registered for the user.
     *
     * @return true if the name is successfully registered.
     */
    function agentRegisterName(
        address _to,
        string calldata _name
    )
        external
        whenNotPaused // Ensures the contract is not paused
        nonReentrant // Prevents reentrancy attacks
        isLegalLength(_name) // Checks the length of the name is legal
        isLegal(_name) // Checks the name is legal
        isNameNotReserved(_name) // Checks if the name is whitelisted
        containsNoReservedWord(_name) // Checks if the name contains reserved
        returns (bool)
    {
        // Checks if the sender is a registered agent
        if (!agents[msg.sender].isAgent) revert NotAgentError();

        ///@dev get the price of the name
        uint _price = getPrice(_name);

        ///@dev checks if the name has a valid price
        if (_price == 0) revert PriceNotSet();

        // Calculates the agent's commission based on their percentage commission
        uint _agentCommission = ((_price * agents[msg.sender].commission) *
            (10 ** 6)) / 100;

        // Calculate the remaining amount after deducting the agent's commission
        uint _remaining = ((_price) * (10 ** 12)) - _agentCommission;

        // Transfer the agent's commission of SELF tokens from the buyer to the agent
        self.safeTransferFrom(_to, msg.sender, _agentCommission);

        // Transfer the remaining SELF tokens from the buyer to this contract
        self.safeTransferFrom(_to, address(this), _remaining);

        ///@dev Update the totalSelfCollected
        _registerName(_to, _name);

        collectedSelf += _remaining;

        return true;
    }

    /**
     * @notice Register a name to a specific address.
     * @dev This function can only be called by the contract owner. It allows the registration of names with a length less than 3 or greater than 40. Additionally, it facilitates the registration of names that are reserved or those that start with a reserved word.
     * 
     * @param _to The address to which the name will be registered.
     * @param _name The name to register.
     * 

     */
    function adminRegisterName(
        address _to,
        string memory _name
    ) external whenNotPaused onlyOwner isLegal(_name) {
        _registerName(_to, _name);
    }

    /**
    * @notice Associate an IPFS URL as metadata with the given tokenId.
    * @param _tokenId The unique identifier of the NFT whose metadata is to be updated.
    * @param _metadata The IPFS URL containing metadata for the NFT.
    *
    * @dev This function is used to set or update the metadata associated with a specific tokenId. The metadata is expected to be an IPFS URL, which is a decentralized way to store and retrieve content.
    
     */
    function setNameMetadata(
        uint256 _tokenId,
        string memory _metadata
    ) external {
        ///@dev check if msg.sender is owner of token id (NFT)
        if (_ownerOf(_tokenId) != msg.sender) revert NotNameOwnerError();

        ///@dev update uri
        _setTokenURI(_tokenId, _metadata);

        emit MetadataUpdated(_tokenId, _metadata);
    }

    /**
     * @notice Sets the price for registering a name of a specific length.
     * @dev The _length parameter is not verified since the administrator may choose to disallow registration of names with specific lengths.
     * @param _length The length of the name (in characters) for which the price is being set.
     * @param _price The price (in tokens) for registering a name of the specified length.
     * @dev _price should be in 10**6
     */
    function setPrice(uint256 _length, uint256 _price) external onlyOwner {
        ///@dev The length must be between 5 and 8 characters (inclusive).
        if (_length < 5 || _length > 8) revert NameLengthOutOfRangeError();

        lengthToPrice[_length] = _price;

        emit PriceUpdated(_length, _price);
    }

    /// @notice Updates the address of the SELF token used for payments within the contract.
    /// @param _self The address of the new SELF token.

    function setSelf(address _self) external onlyOwner {
        if (_self == address(0)) revert InvalidAddressError();
        self = IERC20(_self);

        emit SelfTokenUpdated(_self);
    }

    /**
     * @notice If you are the owner of the contract, use this function to withdraw all SELF tokens owned by the contract.
     * @dev Transfers the entire balance of SELF tokens owned by the contract to the owner.
     */
    function forwardCollectedSelf() external onlyOwner {
        uint _amountToTransfer = collectedSelf;
        if (_amountToTransfer == 0) revert NoTokensAvailableError();

        collectedSelf = 0;

        self.safeTransfer(msg.sender, _amountToTransfer);

        emit CollectedSelfForwarded(msg.sender, _amountToTransfer);
    }

    /**
     * @dev Blacklists a name.
     * @param _name The name to be blacklisted.
     */
    function reserveName(
        string memory _name
    ) external onlyOwner isLegal(_name) isNameNotReserved(_name) {
        if (bytes(_name).length == 0) revert NameLengthOutOfRangeError();

        reservedNames[_name] = true;

        emit NameReserved(_name);
    }

    /**
     * @dev Whitelists  a name.
     * @param _name The name to be whitelisted.
     */
    function unreserveName(
        string memory _name
    ) external onlyOwner isLegal(_name) {
        if (bytes(_name).length == 0) revert NameLengthOutOfRangeError();
        if (!reservedNames[_name]) revert NameNotReservedError();

        reservedNames[_name] = false;

        emit NameUnreserved(_name);
    }

    function batchReserveNames(string[] memory _names) external onlyOwner {
        for (uint i = 0; i < _names.length; ++i) {
            reservedNames[_names[i]] = true;
        }
    }

    function batchUnreserveNames(string[] memory _names) external onlyOwner {
        for (uint i = 0; i < _names.length; ++i) {
            reservedNames[_names[i]] = false;
        }
    }

    /**
     * @dev Sets the royalty.
     *
     * @param _receiver The address of the royalty receiver.
     * @param _feeNumerator The numerator of the royalty fee.
     */
    function setDefaultRoyalty(
        address _receiver,
        uint96 _feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Updates the commsion of already added agent.
     * @param _agent The address of the agent to edit.
     * @param _commission The commission rate for the agent.
     * @dev _commision should be in 10**6
     */
    function editAgent(address _agent, uint _commission) external onlyOwner {
        if (_agent == address(0)) revert InvalidAddressError();
        if (_commission == 0) revert InvalidCommissionError();
        if (!agents[_agent].isAgent) revert NotAgentError();

        agents[_agent].commission = _commission;

        emit AgentUpdated(_agent, _commission);
    }

    /**
     * @notice Adds a new agent with the specified address and commission.
     * @param _agent The address of the agent to add.
     * @param _commission The commission rate for the agent.
     * @dev _commision should be in 10**6
     */
    function addAgent(address _agent, uint _commission) external onlyOwner {
        if (_agent == address(0)) revert InvalidAddressError();
        if (_commission == 0) revert InvalidCommissionError();
        if (agents[_agent].isAgent) revert AlreadyAgentError();

        agents[_agent] = Agent({isAgent: true, commission: _commission});

        emit AgentAdded(_agent, _commission);
    }

    /**
     * @notice Removes the specified agent.
     * @param _agent The address of the agent to remove
     */
    function removeAgent(address _agent) external onlyOwner {
        if (_agent == address(0)) revert InvalidAddressError();
        if (!agents[_agent].isAgent) revert NotAgentError();

        agents[_agent].isAgent = false;

        emit AgentRemoved(_agent);
    }

    /// @notice Pauses the contract, disabling name registration and other functions.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, enabling name registration and other functions.
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Retrieves all registered names owned by a specific address.
     * @param _owner The address of the owner whose registered names will be fetched.
     * @return names An array of strings containing all the registered names owned by the specified address.
     * @dev Efficient routine for fetching names owned by an address(tested for 300 names). Much better approach is to move this routine off-chain.
     */
    function getNames(
        address _owner
    ) external view returns (string[] memory names) {
        uint256 _balance = balanceOf(_owner);

        names = new string[](_balance);

        for (uint256 i = 0; i < _balance; ++i) {
            names[i] = tokenIdToName[tokenOfOwnerByIndex(_owner, i)];
        }
    }

    /**
     * @notice Checks if a given name is available for registration.
     * @param _name The name to check for availability.
     * @return A boolean value indicating whether the name is available for registration.
     */
    function isNameAvailable(
        string calldata _name
    )
        external
        view
        isLegal(_name)
        isLegalLength(_name)
        isNameNotReserved(_name)
        containsNoReservedWord(_name)
        returns (bool)
    {
        uint256 _tokenId = _hashString(_name);
        return _ownerOf(_tokenId) == address(0);
    }

    /**
     * @notice Calculates the price for registering a given name.
     * @param _name The name for which the price will be calculated.
     * @return The price for registering the given name.
     */
    function getPrice(string memory _name) public view returns (uint256) {
        uint256 nameLength = bytes(_name).length;
        uint256 effectiveNameLength = nameLength > 8 ? 8 : nameLength;
        return lengthToPrice[effectiveNameLength];
    }

    /**

    * @notice Registers a unique name as an NFT and mints it to the caller.
    * @param _name The unique name to be registered as an NFT.
    
    * @dev The input (name) is hashed, and the resulting hash (converted to uint) acts as the tokenId. The original name is stored for use by external services (client-side applications, APIs).

    * @dev Different names might have the same hash, which could result in a hash collision. However, no known hash collisions have ever been discovered. There are 2^256 possible keccak-256 hashes, which is roughly the same number as atoms in the known observable universe. A collision would be akin to randomly selecting two atoms and finding them to be identical.

    * @dev If a collision occurs, the registrant would be able to have two or more names for the same price (lucky person!). This does not mean that multiple NFTs will be minted; instead, a single NFT will represent multiple names. In essence, once a tokenId is minted, it cannot be minted again. So, if different names result in the same tokenId, only the initial registrant will be able to mint that tokenId.

 */
    function _registerName(address _to, string memory _name) private {
        ///@dev hash the name and convert it into uint256
        uint256 _tokenId = _hashString(_name);

        ///@dev check if name is already registered
        if (_ownerOf(_tokenId) != address(0))
            revert NameAlreadyRegisteredError();

        ///@dev store the original name corresponding to the hashed name
        tokenIdToName[_tokenId] = _name;

        ///@dev mint the nft
        _safeMint(_to, _tokenId);

        ///@dev emit event
        emit NameRegistered(_to, _name, _tokenId);
    }

    function _hashString(string memory _str) private pure returns (uint256) {
        return uint256(keccak256(bytes(_str)));
    }

    function _equal(
        string memory a,
        string memory b
    ) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    // ==========The following functions are overrides required by Solidity===========
    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage, ERC721Royalty) {
        super._burn(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
