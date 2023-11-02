// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {TWAMM} from "v4-periphery/hooks/examples/TWAMM.sol";
import {BaseFactory} from "../BaseFactory.sol";

// Factory for deploying TWAMM hooks
contract TWAMMHookFactory is BaseFactory {
    uint256 internal constant EXPIRATION_INTERVAL = 60;

    constructor()
        BaseFactory(
            address(uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_MODIFY_POSITION_FLAG | Hooks.BEFORE_SWAP_FLAG))
        )
    {}

    function deploy(IPoolManager poolManager, bytes32 salt) public override returns (address) {
        return address(new TWAMM{salt: salt}(poolManager, EXPIRATION_INTERVAL));
    }

    function _hashBytecode(IPoolManager poolManager) internal pure override returns (bytes32 bytecodeHash) {
        bytecodeHash =
            keccak256(abi.encodePacked(type(TWAMM).creationCode, abi.encode(poolManager, EXPIRATION_INTERVAL)));
    }
}
