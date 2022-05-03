pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IExchange {
    function ethToTokenSwap(uint256 _minTokens) external payable;
    function ethToTokenTransfer(uint256 _minTokens, address _recipient) external payable;
}