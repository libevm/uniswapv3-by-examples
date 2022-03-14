// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "ds-test/test.sol";

import "../lib/Address.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap-v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap-v3-core/contracts/libraries/TickMath.sol";

import "@uniswap-v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap-v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "@uniswap-v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap-v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap-v3-periphery/contracts/interfaces/external/IWETH9.sol";

contract LiquidityProvider_ExistingTest is DSTest {
    using TickMath for int24;

    INonfungiblePositionManager nfpm =
        INonfungiblePositionManager(Address.UNIV3_POS_MANAGER);
    ISwapRouter v3router = ISwapRouter(Address.UNIV3_ROUTER);
    IUniswapV3Factory v3Factory = IUniswapV3Factory(Address.UNIV3_FACTORY);
    IUniswapV3Pool pool;

    IWETH9 weth = IWETH9(Address.WETH);
    IERC20 dai = IERC20(Address.DAI);

    IERC20 token0 =
        IERC20(Address.WETH < Address.DAI ? Address.WETH : Address.DAI);
    IERC20 token1 =
        IERC20(Address.WETH > Address.DAI ? Address.WETH : Address.DAI);

    uint24 constant fee = 3000;
    int24 tickSpacing;

    function setUp() public {
        // Get pool
        pool = IUniswapV3Pool(
            v3Factory.getPool(Address.WETH, Address.DAI, fee)
        );
        tickSpacing = pool.tickSpacing();

        // Give us some WETH
        weth.deposit{value: 20e18}();

        // Get us some DAI from Univ3
        weth.approve(address(v3router), uint256(-1));
        v3router.exactInput(
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(Address.WETH, fee, Address.DAI),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: 10e18,
                amountOutMinimum: 0
            })
        );
    }

    /// @notice Adds liquidity at current spot price -/+ tickSpacing
    function test_addLiquidity_existing() public returns (uint256) {
        // Approve NF Position Manager
        weth.approve(address(nfpm), uint256(-1));
        dai.approve(address(nfpm), uint256(-1));

        // Get pool current tick, make sure the ticks are correct
        (, int24 curTick, , , , , ) = pool.slot0();
        curTick = curTick - (curTick % tickSpacing);

        int24 lowerTick = curTick - (tickSpacing * 2);
        int24 upperTick = curTick + (tickSpacing * 2);

        uint256 before0 = token0.balanceOf(address(this));
        uint256 before1 = token1.balanceOf(address(this));

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = nfpm.mint(
                INonfungiblePositionManager.MintParams({
                    token0: pool.token0(),
                    token1: pool.token1(),
                    fee: fee,
                    tickLower: lowerTick,
                    tickUpper: upperTick,
                    amount0Desired: token0.balanceOf(address(this)),
                    amount1Desired: token1.balanceOf(address(this)),
                    amount0Min: 0e18,
                    amount1Min: 0e18,
                    recipient: address(this),
                    deadline: block.timestamp
                })
            );

        uint256 after0 = token0.balanceOf(address(this));
        uint256 after1 = token1.balanceOf(address(this));

        assertGt(uint256(liquidity), 0);
        assertEq(before0, after0 + amount0);
        assertEq(before1, after1 + amount1);
        assertEq(nfpm.ownerOf(tokenId), address(this));

        return tokenId;
    }

    function test_removeLiquidity_existing() public {
        // Alternatively, you can get the tokenid via
        // keccak256(abi.encodePacked(address(this), lowerTick, upperTick));
        uint256 tokenId = test_addLiquidity_existing();

        uint256 before0 = token0.balanceOf(address(this));
        uint256 before1 = token1.balanceOf(address(this));

        // Calculate amounts given liquidity and ticks
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        (
            ,
            ,
            ,
            ,
            ,
            int24 lowerTick,
            int24 upperTick,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nfpm.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtRatioX96,
                lowerTick.getSqrtRatioAtTick(),
                upperTick.getSqrtRatioAtTick(),
                liquidity
            );

        (uint256 amount0Removed, uint256 amount1Removed) = nfpm
            .decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: amount0,
                    amount1Min: amount1,
                    deadline: block.timestamp
                })
            );

        // NOTE: This is where tokenTransfer happens
        // Collect the decreased liquidity
        nfpm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: uint128(-1),
                amount1Max: uint128(-1)
            })
        );

        uint256 after0 = token0.balanceOf(address(this));
        uint256 after1 = token1.balanceOf(address(this));

        assertEq(amount0Removed, amount0);
        assertEq(amount1Removed, amount1);

        assertGt(after0, before0);
        assertGt(after1, before1);

        nfpm.burn(tokenId);
    }
}
