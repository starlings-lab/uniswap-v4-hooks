// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolModifyPositionTest} from "@uniswap/v4-core/contracts/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "@uniswap/v4-core/contracts/test/PoolSwapTest.sol";
import {PoolDonateTest} from "@uniswap/v4-core/contracts/test/PoolDonateTest.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolId.sol";

import {Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";
import {TestERC20} from "@uniswap/v4-core/contracts/test/TestERC20.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";

import {Call, CallType, GenericRouter} from "../../src/GenericRouter.sol";

/// @notice Contract to initialize some test helpers
/// @dev Minimal initialization. Inheriting contract should set up pools and provision liquidity
contract HookTest is Test {
    PoolManager manager;
    PoolModifyPositionTest modifyPositionRouter;
    PoolSwapTest swapRouter;
    PoolDonateTest donateRouter;
    TestERC20 token0;
    TestERC20 token1;
    GenericRouter router;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    function initHookTestEnv() public {
        uint256 amount = 2 ** 128;
        TestERC20 _tokenA = new TestERC20(amount);
        TestERC20 _tokenB = new TestERC20(amount);

        // pools alphabetically sort tokens by address
        // so align `token0` with `pool.token0` for consistency
        if (address(_tokenA) < address(_tokenB)) {
            token0 = _tokenA;
            token1 = _tokenB;
        } else {
            token0 = _tokenB;
            token1 = _tokenA;
        }

        manager = new PoolManager(500000);

        // Deploy a generic router
        router = new GenericRouter(manager);

        token0.approve(address(router), 2 ** 128);
        token1.approve(address(router), 2 ** 128);

        // Helpers for interacting with the pool
        modifyPositionRouter = new PoolModifyPositionTest(IPoolManager(address(manager)));
        swapRouter = new PoolSwapTest(IPoolManager(address(manager)));
        donateRouter = new PoolDonateTest(IPoolManager(address(manager)));

        // Approve for liquidity provision
        token0.approve(address(modifyPositionRouter), amount);
        token1.approve(address(modifyPositionRouter), amount);

        // Approve for swapping
        token0.approve(address(swapRouter), amount);
        token1.approve(address(swapRouter), amount);
    }

    function swap(PoolKey memory poolKey, TestERC20 fromToken, int256 swapAmount)
        internal
        returns (bytes[] memory results)
    {
        Call[] memory calls = new Call[](4);

        bool zeroForOne = address(fromToken) == Currency.unwrap(poolKey.currency0);
        Currency fromCurrency = Currency.wrap(address(fromToken));
        Currency toCurrency = zeroForOne ? Currency.wrap(address(token1)) : Currency.wrap(address(token0));

        // Swap
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: swapAmount,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });
        calls[0] =
            Call(address(manager), CallType.Call, 0, abi.encodeWithSelector(manager.swap.selector, poolKey, params));

        // Transfer fromToken to Pool Manager
        calls[1] = Call(
            address(fromToken),
            CallType.Call,
            0,
            abi.encodeWithSelector(token0.transferFrom.selector, address(this), address(manager), swapAmount)
        );

        // Settle fromToken
        calls[2] =
            Call(address(manager), CallType.Call, 0, abi.encodeWithSelector(manager.settle.selector, fromCurrency));

        // Take toToken
        calls[3] = Call(
            address(manager),
            CallType.Call,
            0,
            // TODO need to get this from the results
            abi.encodeWithSelector(manager.take.selector, toCurrency, address(this), 98)
        );

        results = router.process(calls);
    }

    function mint(PoolKey memory poolKey, Currency currency, uint256 mintAmount)
        internal
        returns (bytes[] memory results)
    {
        Call[] memory calls = new Call[](3);

        // Router transfers token1 from this test contract to Pool Manager
        calls[0] = Call(
            address(token1),
            CallType.Call,
            0,
            abi.encodeWithSelector(token1.transferFrom.selector, address(this), address(manager), mintAmount)
        );

        // Mint token1 to the router
        calls[1] = Call(
            address(manager),
            CallType.Call,
            0,
            abi.encodeWithSelector(manager.mint.selector, currency, address(this), mintAmount)
        );

        // Settle token1 in the Pool Manager
        calls[2] = Call(address(manager), CallType.Call, 0, abi.encodeWithSelector(manager.settle.selector, currency));

        results = router.process(calls);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        virtual
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}
