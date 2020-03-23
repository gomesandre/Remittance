pragma solidity ^0.5.0;

contract Remittance {
  bytes32 public puzzle;
  mapping (address => uint) public balances;
  
  event LogTransactionCreated(bytes32 puzzle, uint value);
  event LogTransactionCompleted(address indexed sender);
  event LogWithdrawn(address indexed sender, uint amount);
    
  function create(bytes32 bobPassword, bytes32 carolPassword) public payable {
    require(msg.value >= 1, "Send at least 1 wei to be transfered.");
    require(bobPassword != 0, "Bob's pass can't be blank.");
    require(carolPassword != 0, "Carol's pass can't be blank.");
    puzzle = keccak256(abi.encodePacked(bobPassword, carolPassword));
    emit LogTransactionCreated(puzzle, msg.value);
  }
  
  function release(bytes32 bobSecret, bytes32 carolSecret) public {
    require(keccak256(abi.encodePacked(bobSecret, carolSecret)) == puzzle, "Invalid credentials.");
    balances[msg.sender] += address(this).balance;
    emit LogTransactionCompleted(msg.sender);
  }
  
  function withdraw() public {
      uint amount = balances[msg.sender];
      require(amount > 0, "Insufficient funds.");
      balances[msg.sender] = 0;
      emit LogWithdrawn(msg.sender, amount);
      (bool success, ) = msg.sender.call.value(amount)("");
      require(success, "Transfer failed.");
  }
}