pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IFactory.sol";

contract Exchange is ERC20 {
  address public tokenAddress;
  address public factoryAddress;
  IERC20 token;

  constructor(address _token) ERC20("Teddyswap-v1", "TED-v1") {
    // Check that the address is not null to avoid having a useless/dangerous exchange contract
    require(_token != address(0), "invalid token address");

    factoryAddress = msg.sender;
    tokenAddress = _token;
    token = IERC20(_token);
  }

  function addLiquidity(uint256 _tokenAmount) public payable returns (uint256) {
      uint256 liquidity;
      if (getReserve() == 0) {
        token.transferFrom(msg.sender, address(this), _tokenAmount);
        liquidity = address(this).balance;
        _mint(msg.sender, liquidity);
      } 
      else {
        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = getReserve();
        uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;
        require(_tokenAmount >= tokenAmount, "insufficient token amount");
                
                
        liquidity = (totalSupply() * msg.value) / ethReserve;
        _mint(msg.sender, liquidity);
        token.transferFrom(msg.sender, address(this), tokenAmount);
      }
      return liquidity;
  }

  function getReserve() public view returns (uint256) {
      return token.balanceOf(address(this));
  }

  function getPrice(uint256 inputReserve, uint256 outputReserve)
  public
  pure
  returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

    return (inputReserve * 1000) / outputReserve;
  }

  function getAmount(
    uint256 inputAmount,
    uint256 inputReserve,
    uint256 outputReserve
  ) private pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

    uint256 inputAmountWithFee = inputAmount * 99;
    uint256 numerator = inputAmountWithFee * outputReserve;
    uint256 denominator = (inputReserve * 100) + inputAmountWithFee;

    return numerator / denominator;
  }
  
  function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
    require(_ethSold > 0, "ethSold is too small");

    uint256 tokenReserve = getReserve();

    return getAmount(_ethSold, address(this).balance, tokenReserve);
  }

  function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
    require(_tokenSold > 0, "tokenSold is too small");

    uint256 tokenReserve = getReserve();

    return getAmount(_tokenSold, tokenReserve, address(this).balance);
  }

  function ethToToken(uint256 _minTokens, address recipient) private {
    uint256 tokenReserve = getReserve();
    uint256 tokensBought = getAmount(
      msg.value,
      address(this).balance - msg.value,
      tokenReserve
    );

    require(tokensBought >= _minTokens, "insufficient output amount");

    token.transfer(recipient, tokensBought);
  }

  function ethToTokenSwap(uint256 _minTokens) public payable {
    ethToToken(_minTokens, msg.sender);
  }

  function ethToTokenTransfer(uint256 _minTokens, address _recipient)
  public
  payable
  {
    ethToToken(_minTokens, _recipient);
  }

  function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
    uint256 tokenReserve = getReserve();
    uint256 ethBought = getAmount(
      _tokensSold,
      tokenReserve,
      address(this).balance
    );

    require(ethBought >= _minEth, "insufficient output amount");

    token.transferFrom(msg.sender, address(this), _tokensSold);
    payable(msg.sender).transfer(ethBought);
  }

  function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
    require(_amount > 0, "invalid amount");

    uint256 ethAmount = (address(this).balance * _amount) / totalSupply();
    uint256 tokenAmount = (getReserve() * _amount) / totalSupply();

    _burn(msg.sender, _amount);
    payable(msg.sender).transfer(ethAmount);
    token.transfer(msg.sender, tokenAmount);

    return (ethAmount, tokenAmount);
  }

  function tokenToTokenSwap(
    uint256 _tokensSold,
    uint256 _minTokensBought,
    address _tokenAddress
  ) public {
    address exchangeAddress = IFactory(factoryAddress).getExchange(
        _tokenAddress
    );
    require(
        exchangeAddress != address(this) && exchangeAddress != address(0),
        "invalid exchange address"
    );

    uint256 tokenReserve = getReserve();
    uint256 ethBought = getAmount(
        _tokensSold,
        tokenReserve,
        address(this).balance
    );

    token.transferFrom(
        msg.sender,
        address(this),
        _tokensSold
    );

    IExchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(
        _minTokensBought,
        msg.sender
    );
  }

}