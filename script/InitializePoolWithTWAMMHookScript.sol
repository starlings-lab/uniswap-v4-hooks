// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";
import {PoolKey, PoolIdLibrary} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {TestERC20} from "@uniswap/v4-core/contracts/test/TestERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {TestPoolManager} from "../test/utils/TestPoolManager.sol";
import {TWAMMHookFactory} from "../src/hooks/TWAMMHookFactory.sol";
import {TWAMM} from "v4-periphery/hooks/examples/TWAMM.sol";
import "forge-std/console.sol";
import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";

/// @notice Forge script for deploying TWAMM hook to **anvil**
/// @dev This script only works on an anvil RPC because v4 exceeds bytecode limits
contract TWAMMHookScript is Script {
    uint160 public constant SQRT_RATIO_1_TO_1 = 79228162514264337593543950336;

    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    PoolKey poolKey;
    uint256 privateKey;
    address signerAddr;
    IHooks twammHook;
    PoolManager manager;

    function setUp() public {
        privateKey = vm.envUint("PRIVATE_KEY");
        signerAddr = vm.addr(privateKey);
        vm.startBroadcast(privateKey);

        // Conduit Pool Manager & TWAMM Hook
        manager = PoolManager(payable(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9));
        twammHook = IHooks(0xa8E797cF0d535fbf2586677c8Bc138AeFc4c8C24);

        // Derive the key for the new pool
        poolKey = PoolKey(
            Currency.wrap(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0),
            Currency.wrap(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512),
            3000,
            50,
            twammHook
        );

        // Create the pool in the Uniswap Pool Manager
        console.log("Initializing a pool - script");
        manager.initialize(poolKey, SQRT_RATIO_1_TO_1, "");
        console.log("Initialized pool");

        vm.stopBroadcast();
    }

    function run() public {
        vm.startBroadcast(privateKey);
        console.log("TWAMM Hook Expiration Interval", TWAMM(address(twammHook)).expirationInterval());

        vm.stopBroadcast();
    }
}
