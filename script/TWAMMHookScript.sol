// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";
import {PoolKey, PoolIdLibrary} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {TestERC20} from "@uniswap/v4-core/contracts/test/TestERC20.sol";

import {TestPoolManager} from "../test/utils/TestPoolManager.sol";
import {TWAMMHookFactory} from "../src/hooks/TWAMMHookFactory.sol";

/// @notice Forge script for deploying TWAMM hook with Pool Manager & Test ERC20s
/// @dev This script only works on an anvil RPC because v4 exceeds bytecode limits
contract TWAMMHookScript is Script, TestPoolManager {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    PoolKey poolKey;
    uint256 privateKey;
    address signerAddr;

    function setUp() public {
        privateKey = vm.envUint("PRIVATE_KEY");
        signerAddr = vm.addr(privateKey);
        vm.startBroadcast(privateKey);

        TestPoolManager.initialize();

        // Deploy the hook
        TWAMMHookFactory factory = new TWAMMHookFactory();

        // Any changes to the MyHook contract will mean a different salt will be needed
        // so just starting from 0 in this script
        IHooks hook = IHooks(factory.mineDeploy(manager, 0));
        console.log("Deployed TWAMM hook to address %s", address(hook));

        // Derive the key for the new pool
        poolKey = PoolKey(Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)), 3000, 60, hook);
        // Create the pool in the Uniswap Pool Manager

        manager.pools(poolKey.toId());
        console.log("Initializing a pool - script");
        manager.initialize(poolKey, SQRT_RATIO_1_TO_1, "");
        console.log("Initialized pool");

        // Provide liquidity to the pool
        caller.addLiquidity(poolKey, signerAddr, -60, 60, 10e18);
        caller.addLiquidity(poolKey, signerAddr, -120, 120, 20e18);
        caller.addLiquidity(poolKey, signerAddr, TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 30e18);

        vm.stopBroadcast();
    }

    function run() public {
        vm.startBroadcast(privateKey);

        // Perform a test swap
        caller.swap(poolKey, signerAddr, signerAddr, poolKey.currency0, 1e18);
        console.log("swapped token 0 for token 1");

        // Remove liquidity from the pool
        caller.removeLiquidity(poolKey, signerAddr, -60, 60, 4e18);
        console.log("removed liquidity");

        // Deposit token 0 to the pool manager
        // caller.deposit(address(tokenA), signerAddr, signerAddr, 6e18);

        vm.stopBroadcast();
    }
}
