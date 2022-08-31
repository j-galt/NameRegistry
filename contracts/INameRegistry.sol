//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

/// @title Interface for Name Registry.
interface INameRegistry {

    /// @custom:struct Committer of a name hash.
    struct Committer {
        /// @custom:property Address of the committer.
        address addr;

        /// @custom:property Global order number of the committed name hash.
        uint96 _sequenceNumber;
    }

    /// @custom:struct Registered name.
    struct Name {
        /// @custom:property Name owner.
        address owner;

        /// @custom:property Timestamp showing when the name expires.
        uint64 ownershipExpirationTimestamp;
    }

    /// @notice Event emitted after name registration.
    /// @param owner Owner of the name.
    /// @param name Registered name.
    /// @param namePrice Price paid in ERC20 for registration of the name. 
    event nameRegistered(address indexed owner, string name, uint256 namePrice);

    /// @notice Event emitted after name hash commitment.
    /// @param committer Committer of the name hash.
    /// @param nameHash Committed name hash.
    event nameHashCommitted(address indexed committer, bytes32 nameHash);

    /// @notice Event emitted after releasing of tokens for expired names.
    /// @param receiver The receiver of the released tokens.
    /// @param releasedAmount The released amount of tokens.
    event fundsReleased(address indexed receiver, uint256 releasedAmount);

    /// @notice Commits name hash got from getNameHash function.
    /// @param nameHash Hash of the name.
    function commitNameHash(bytes32 nameHash) external;

    /// @notice Registers the name. The name should be committed beforehand as well as the required amount of tokens
    /// should be allowed to be taken by this contract.
    /// Front-running protection. If the name is submitted by a front runner,
    /// it will give it back to the earlier committer once the leter calls the function. Name expires in some time.
    /// @param name Name to be registered.
    function registerName(string memory name) external;

    /// @notice Releases the fixed portion of the price of names that expired.
    /// @param namesToBeReleased Collection of expired names to release the funds for.
    /// @dev namesToBeReleased Collection can be obtained by client code filtering nameRegistered events.
    function releaseAvailableFunds(string[] memory namesToBeReleased) external;

    /// @notice Gets the fixed portion of the price per name in ERC20 token.
    /// @return price The price per name in ERC20 token.
    function getFixedNamePrice() external view returns (uint256 price);

    /// @notice Checks if the addr is the owner of the name.
    /// @param addr Address to check.
    /// @param name Name to check.
    /// @return isOwner True if the addr is the owner of the name, false otherwise.
    function isNameOwner(address addr, string memory name) external view returns (bool isOwner);
}
