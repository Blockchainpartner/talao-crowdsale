pragma solidity ^0.4.18;

import './token/MintableToken.sol';

contract EmindhubToken is MintableToken {
  using SafeMath for uint256;
  string public constant name = "eMindHub Token";
  string public constant symbol = "EXP";
  uint8 public constant decimals = 18;

  modifier onlyMintingFinished() {
    require(mintingFinished == true);
    _;
  }
  /// @dev Same ERC20 behavior, but require the token to be unlocked
  /// @param _spender address The address which will spend the funds.
  /// @param _value uint256 The amount of tokens to be spent.
  function approve(address _spender, uint256 _value) public onlyMintingFinished returns (bool) {
      return super.approve(_spender, _value);
  }

  /// @dev Same ERC20 behavior, but require the token to be unlocked
  /// @param _to address The address to transfer to.
  /// @param _value uint256 The amount to be transferred.
  function transfer(address _to, uint256 _value) public onlyMintingFinished returns (bool) {
      return super.transfer(_to, _value);
  }

  /// @dev Same ERC20 behavior, but require the token to be unlocked
  /// @param _from address The address which you want to send tokens from.
  /// @param _to address The address which you want to transfer to.
  /// @param _value uint256 the amount of tokens to be transferred.
  function transferFrom(address _from, address _to, uint256 _value) public onlyMintingFinished returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

}
