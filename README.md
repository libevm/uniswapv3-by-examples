# UniswapV3 By Examples

I couldn't find a repository that contained straightforward Uniswap V3 action examples, so I decided to make one myself.

This repostiory assumes you understand how UniswapV3 operates at a high level, if not, [check out their docs](https://docs.uniswap.org/protocol/concepts/V3-overview/concentrated-liquidity).

```bash
# forge 0.1.0 (0f58c52 2022-03-14T00:17:17.595445+00:00)
forge build

# RPC_URL=https://mainnet.infura.io/v3/<PROJECT_ID>
forge test -f $RPC_URL -vvv

# ganache-cli -f $RPC_URL
forge run --debug src/test/Swap.t.sol -f http://127.0.0.1:8545 --sig "test_swapExactInput()"
```

## Examples 

- [x] Calculate SqrtPriceX96/SqrtRatioX96
- [x] Add Liquidity
- [x] Remove Liquidity
- [x] Swap Exact In
- [x] Swap Exact Out