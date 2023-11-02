// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

import { IMessageRelay } from "../../interfaces/IMessageRelay.sol";
import { IErc20Vault } from "./IErc20Vault.sol";
import { IPToken } from "./IPToken.sol";
import { Yaho } from "../../Yaho.sol";
import { AMBAdapter } from "./AMBAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PNetworkMessageRelay is IMessageRelay {
    using SafeERC20 for IERC20;

    address public immutable token;
    address public immutable vault;
    Yaho public immutable yaho;
    bytes4[] private _supportedNetworkIds;

    uint256 private constant SWAP_AMOUNT = 100;

    event MessageRelayed(address indexed emitter, uint256 indexed messageId);
    event NetworkIdAdded(bytes4 networkId);

    error AlreadyExistingNetworkId(bytes4 networkId);

    constructor(address _vault, address _token, Yaho _yaho) {
        vault = _vault;
        token = _token;
        yaho = _yaho;
    }

    function relayMessages(
        uint256[] memory messageIds,
        address pnetworkAdapter
    ) public payable returns (bytes32 receipt) {
        bytes32[] memory hashes = new bytes32[](messageIds.length);
        for (uint256 i = 0; i < messageIds.length; i++) {
            uint256 id = messageIds[i];
            hashes[i] = yaho.hashes(id);
            emit MessageRelayed(address(this), messageIds[i]);
        }
        bytes memory data = abi.encode(messageIds, hashes);
        if (vault != address(0)) {
            for (uint256 index = 0; index < _supportedNetworkIds.length; ) {
                IERC20(token).safeApprove(vault, SWAP_AMOUNT); // TODO: is this OK? Who is holding PNTs?
                IErc20Vault(vault).pegIn(
                    SWAP_AMOUNT,
                    token,
                    _toAsciiString(pnetworkAdapter),
                    data,
                    _supportedNetworkIds[index]
                );
            }
        } else {
            for (uint256 index = 0; index < _supportedNetworkIds.length; ) {
                IPToken(token).redeem(SWAP_AMOUNT, data, _toAsciiString(pnetworkAdapter), _supportedNetworkIds[index]);
            }
        }
        // TODO: return something resembling a receipt
    }

    // TODO: limit access to this function
    function addNetwork(bytes4 networkId) public {
        if (_isNetworkSupported(networkId)) revert AlreadyExistingNetworkId(networkId);
        _supportedNetworkIds.push(networkId);
        emit NetworkIdAdded(networkId);
    }

    function _toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = _char(hi);
            s[2 * i + 1] = _char(lo);
        }
        return string(s);
    }

    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function _isNetworkSupported(bytes4 _target) internal view returns (bool) {
        for (uint i = 0; i < _supportedNetworkIds.length; i++) {
            if (_supportedNetworkIds[i] == _target) {
                return true; // Value found in the array
            }
        }
        return false; // Value not found in the array
    }
}
