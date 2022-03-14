// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "ds-test/test.sol";

import "../lib/Address.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap-solidity-lib/contracts/libraries/FixedPoint.sol";
import "@uniswap-v3-core/contracts/libraries/TickMath.sol";

import "@uniswap-v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap-v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap-v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap-v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap-v3-periphery/contracts/interfaces/external/IWETH9.sol";

contract AddLiquidityTest is DSTest {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    using TickMath for int24;

    INonfungiblePositionManager nfpm =
        INonfungiblePositionManager(Address.UNIV3_POS_MANAGER);
    ISwapRouter v3router = ISwapRouter(Address.UNIV3_ROUTER);
    IUniswapV3Factory v3Factory = IUniswapV3Factory(Address.UNIV3_FACTORY);
    IUniswapV3Pool pool;

    IWETH9 weth = IWETH9(Address.WETH);
    IERC20 dai = IERC20(Address.DAI);

    IERC20 token0 = IERC20(Address.WETH < Address.DAI ? Address.WETH : Address.DAI);
    IERC20 token1 = IERC20(Address.WETH > Address.DAI ? Address.WETH : Address.DAI);

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
    function test_addLiquidity() public {
        // Approve NF Position Manager
        weth.approve(address(nfpm), uint256(-1));
        dai.approve(address(nfpm), uint256(-1));

        // Get pool current tick, make sure the ticks are correct
        (, int24 curTick,,,,,) = pool.slot0();
        curTick = curTick - (curTick % tickSpacing);

        int24 lowerTick = curTick - (tickSpacing * 2);
        int24 upperTick = curTick + (tickSpacing * 2);

        nfpm.mint(
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
    }
}
