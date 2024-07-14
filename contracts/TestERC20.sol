pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract TestERC20 is ERC20, Ownable{

  // Constructor to initialize token supply (same as previous example)
  constructor(
    uint256 _initialSupply,
    string memory name,
    string memory symbol,
    address _owner
  ) ERC20(name, symbol) Ownable(_owner) {
    _mint(_owner, _initialSupply); 
  }
}