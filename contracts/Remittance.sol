pragma solidity ^0.5.0;

contract Remittance {
  struct Transfer {
    bytes32 puzzle;
    uint value;
    address recipient;
  }
  
  mapping (address => uint) public balances;
  mapping (bytes32 => Transfer) public transfers;
  
  event LogTransactionCreated(bytes32 puzzle, uint value, address indexed recipient);
  event LogTransactionCompleted(address indexed sender);
  event LogWithdrawn(address indexed sender, uint amount);
    
  function create(bytes32 secret, address recipient) public payable {
    require(msg.value >= 1, "Send at least 1 wei to be transfered.");
    require(transfers[secret].puzzle == bytes32(0), "This puzzle is already registered.");
    require(recipient != address(0), "Recipient should be a valid address.");
    transfers[secret] = Transfer(secret, msg.value, recipient);
    emit LogTransactionCreated(secret, msg.value, recipient);
  }
  
  function release(bytes32 passA, bytes32 passB) public {
    bytes32 hashedPuzzle = keccak256(abi.encodePacked(passA, passB));
    require(hashedPuzzle == transfers[hashedPuzzle].puzzle, "Invalid credentials.");
    require(transfers[hashedPuzzle].recipient == msg.sender, "Unauthorized account.");
    balances[msg.sender] += transfers[hashedPuzzle].value;
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