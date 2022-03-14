// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Token", "TKN") {}

    function mint(address recipient, uint256 amount) public {
        _mint(recipient, amount);
    }
}
