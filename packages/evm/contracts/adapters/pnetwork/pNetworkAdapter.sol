// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

import { OracleAdapter } from "../OracleAdapter.sol";
import { BlockHashOracleAdapter } from "../BlockHashOracleAdapter.sol";

import "@openzeppelin/contracts/token/ERC777/presets/ERC777PresetFixedSupply.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1820RegistryUpgradeable.sol";

contract PNetworkAdapter is OracleAdapter, BlockHashOracleAdapter, IERC777Recipient {
    address public admittedSender;
    address public token;
    bytes32 public chainId;
    IERC1820RegistryUpgradeable private constant _erc1820 =
        IERC1820RegistryUpgradeable(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    bytes32 private constant Erc777Token_INTERFACE_HASH = keccak256("ERC777Token");

    error ArrayLengthMissmatch();
    error InvalidSender(address sender);

    constructor(address _sender, address _token, bytes32 _chainId) {
        admittedSender = _sender;
        token = _token;
        chainId = _chainId;
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    // Implement the ERC777TokensRecipient interface
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external override {
        require(msg.sender == address(token), "Only accepted token is allowed");
        if (from != admittedSender) revert InvalidSender(from);
        (uint256[] memory messageIds, bytes32[] memory hashes) = abi.decode(data, (uint256[], bytes32[]));
        if (messageIds.length != hashes.length) revert ArrayLengthMissmatch();
        for (uint256 i = 0; i < messageIds.length; i++) {
            _storeHash(uint256(chainId), messageIds[i], hashes[i]);
        }
    }
}
