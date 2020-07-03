pragma solidity ^0.5.0;

contract Remittance {
  struct Transfer {
    address sender;
    uint value;
    uint deadline;
  }
  
  mapping (address => uint) public balances;
  mapping (bytes32 => Transfer) public transfers;
  
  event LogTransactionCreated(bytes32 puzzle, uint value);
  event LogTransactionCompleted(address indexed sender);
  event LogWithdrawn(address indexed sender, uint amount);
  event LogTransactionClaimedBack(bytes32 puzzle);
    
  function create(bytes32 puzzle, uint hoursToExpire) public payable {
    require(hoursToExpire > 1 && hoursToExpire <= 48, "Time until expiration must be between 1 and 48 hours.");
    require(msg.value >= 1, "Send at least 1 wei to be transfered.");
    require(transfers[puzzle].value == uint(0), "This puzzle is already registered.");
    uint expiresAt = now + (hoursToExpire * 1 hours);
    transfers[puzzle] = Transfer(msg.sender, msg.value, expiresAt);
    emit LogTransactionCreated(puzzle, msg.value);
  }
  
  function release(bytes32 password) public {
    bytes32 hashedPuzzle = keccak256(abi.encodePacked(address(this), password, msg.sender));
    require(transfers[hashedPuzzle].deadline > now, "This remittance is expired.");
    require(transfers[hashedPuzzle].value != uint(0), "Puzzle does not match or already released.");
    balances[msg.sender] += transfers[hashedPuzzle].value;
    transfers[hashedPuzzle].value = 0;
    emit LogTransactionCompleted(msg.sender);
  }
  
  function claimBackEther(bytes32 puzzle) public {
      require(transfers[puzzle].value != uint(0), "Puzzle does not match or already claimed back.");
      require(transfers[puzzle].deadline < now, "Can not claim funds until the remittance is expired.");
      require(transfers[puzzle].sender == msg.sender, "Only the remittance sender can claim back funds.");
      
      balances[msg.sender] += transfers[puzzle].value;
      transfers[puzzle].value = 0;
      emit LogTransactionClaimedBack(puzzle);
  }
  
  function generatePuzzle(bytes32 password, address agent) public view returns (bytes32) {
    require(agent != address(0), "Invalid recipient.");
    return keccak256(abi.encodePacked(address(this), password, agent));
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