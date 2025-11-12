pragma solidity ^0.8.24;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract MockDBR is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol, 18){
    }

    function mint(address to, uint amount) external {
        _mint(to, amount);
    }

    function markets(address) external view returns(bool) {
        return true;
    }
}
