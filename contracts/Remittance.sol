pragma solidity ^0.5.0;

contract Remittance {
  struct Transfer {
    uint value;
  }
  
  mapping (address => uint) public balances;
  mapping (bytes32 => Transfer) public transfers;
  
  event LogTransactionCreated(bytes32 puzzle, uint value);
  event LogTransactionCompleted(address indexed sender);
  event LogWithdrawn(address indexed sender, uint amount);
    
  function create(bytes32 puzzle) public payable {
    require(msg.value >= 1, "Send at least 1 wei to be transfered.");
    require(transfers[puzzle].value == uint(0), "This puzzle is already registered.");
    transfers[puzzle] = Transfer(msg.value);
    emit LogTransactionCreated(puzzle, msg.value);
  }
  
  function release(bytes32 password, bytes32 agent) public {
    bytes32 hashedPuzzle = keccak256(abi.encodePacked(address(this), password, agent, msg.sender));
    require(transfers[hashedPuzzle].value != uint(0), "Puzzle does not match or already released.");
    balances[msg.sender] += transfers[hashedPuzzle].value;
    transfers[hashedPuzzle].value = 0;
    emit LogTransactionCompleted(msg.sender);
  }
  
  function generatePuzzle(bytes32 password, bytes32 agent, address shop) public view returns (bytes32) {
    require(shop != address(0), "Invalid recipient.");
    return keccak256(abi.encodePacked(address(this), password, agent, shop));
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