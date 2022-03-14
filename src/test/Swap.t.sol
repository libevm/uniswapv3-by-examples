// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "ds-test/test.sol";

import "../lib/Address.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap-v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap-v3-periphery/contracts/interfaces/external/IWETH9.sol";

contract SwapTest is DSTest {
    ISwapRouter v3router = ISwapRouter(Address.UNIV3_ROUTER);

    IWETH9 weth = IWETH9(Address.WETH);
    IERC20 dai = IERC20(Address.DAI);

    uint24 constant fee = 3000;

    function setUp() public {
        weth.deposit{value: 20e18}();
        weth.approve(address(v3router), uint256(-1));
    }

    function test_swapExactInput() public {
        uint256 _before = dai.balanceOf(address(this));
        v3router.exactInput(
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(Address.WETH, fee, Address.DAI),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: 10e18,
                amountOutMinimum: 0
            })
        );
        uint256 _after = dai.balanceOf(address(this));
        assertGt(_after, _before);
    }

    function test_swapExactOutput() public {
        uint256 _before = dai.balanceOf(address(this));

        v3router.exactOutput(
            ISwapRouter.ExactOutputParams({
                // Path is reversed
                path: abi.encodePacked(Address.DAI, fee, Address.WETH),
                recipient: address(this),
                deadline: block.timestamp,
                amountInMaximum: 20e18,
                amountOut: 10000e18
            })
        );

        uint256 _after = dai.balanceOf(address(this));
        assertGt(_after, _before);
    }
}
