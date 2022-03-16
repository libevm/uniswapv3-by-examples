// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "ds-test/test.sol";

import "../lib/Address.sol";
import "../lib/SqrtMath.sol";

import "@uniswap-v3-core/contracts/libraries/TickMath.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap-v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap-v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "@uniswap-v3-periphery/contracts/interfaces/IQuoter.sol";
import "@uniswap-v3-periphery/contracts/interfaces/external/IWETH9.sol";

contract QuoteTest is DSTest {
    using TickMath for int24;

    IQuoter v3Quoter = IQuoter(Address.UNIV3_QUOTER);

    IWETH9 weth = IWETH9(Address.WETH);
    IERC20 snx = IERC20(Address.SNX);

    IUniswapV3Factory v3Factory = IUniswapV3Factory(Address.UNIV3_FACTORY);
    IUniswapV3Pool pool;

    uint24 constant fee = 3000;
    int24 tickSpacing;

    function setUp() public {
        // Get pool
        pool = IUniswapV3Pool(
            v3Factory.getPool(Address.WETH, Address.SNX, fee)
        );
        tickSpacing = pool.tickSpacing();
    }

    function test_quoteExactInputSingle() public {
        // How much SNX do we get out
        uint256 amountOut0 = v3Quoter.quoteExactInputSingle(
            address(weth),
            address(snx),
            fee,
            1e18,
            0
        );

        uint256 amountOut1 = v3Quoter.quoteExactInputSingle(
            address(weth),
            address(snx),
            fee,
            2e18,
            0
        );

        assertGt(amountOut0, 0);
        assertGt(amountOut1, amountOut0);
    }

    function test_quoteExactInputSingle_till_sqrtPrice() public {
        // ETH currently
        (, int24 curTick, , , , , ) = pool.slot0();
        uint160 curSqrtPriceX96 = curTick.getSqrtRatioAtTick();

        // https://ethereum.stackexchange.com/questions/98685/computing-the-uniswap-v3-pair-price-from-q64-96-number

        // Since token0 is SNX and token1 is ETH
        // The spot price it gives us is
        // 1 SNX = X ETH
        uint256 snxEthSpotPrice = (uint256(curSqrtPriceX96) *
            uint256(curSqrtPriceX96) *
            1e18) >> (96 * 2);

        // Convert to 1 ETH = X DAI spot price
        uint256 ethSnxSpotPrice = 1e36 / snxEthSpotPrice;
        uint256 ethSnxPremiumSmall = (ethSnxSpotPrice * 10001) / 10000;
        uint256 ethSnxPremiumBig= (ethSnxSpotPrice * 1001) / 1000;

        // Convert to sqrtPrice
        // encodeSqrtPrice(reserve1, reserve0)
        uint160 sqrtPriceTargetSmallPremX96 = encodePriceSqrt(ethSnxPremiumSmall, 1e18);
        uint160 sqrtPriceTargetLargePremX96 = encodePriceSqrt(ethSnxPremiumBig, 1e18);

        // How much SNX do we get out
        uint256 amountOutSmallPremium = v3Quoter.quoteExactInputSingle(
            address(weth),
            address(snx),
            fee,
            type(uint160).max,
            sqrtPriceTargetSmallPremX96
        );

        uint256 amountOutLargePremium = v3Quoter.quoteExactInputSingle(
            address(weth),
            address(snx),
            fee,
            type(uint160).max,
            sqrtPriceTargetLargePremX96
        );

        assertGt(amountOutSmallPremium, 0);
        assertGt(amountOutLargePremium, amountOutSmallPremium);
    }
}
