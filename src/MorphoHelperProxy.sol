// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MorphoHelperProxy
 * @notice This contract is a proxy that delegates calls to the MorphoHelper implementation.
 * @dev The MorphoHelperProxy is an instance of ERC1967Proxy that points to the MorphoHelper implementation.
 * This follows the UUPS (Universal Upgradeable Proxy Standard) pattern, which allows
 * for upgradeability via the implementation contract rather than the proxy itself.
 */
contract MorphoHelperProxy is ERC1967Proxy {
    constructor(address implementation, address initialAdmin) ERC1967Proxy(implementation, abi.encodeWithSignature("initialize(address)", initialAdmin)) {}
}