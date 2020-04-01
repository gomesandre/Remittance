const Remittance = artifacts.require('Remittance');
const truffleAssert = require('truffle-assertions');

contract('Remittance', function(accounts) {
  let remittanceInstance;
  const { fromAscii, toBN, soliditySha3, padRight } = web3.utils; 
  const { getBalance } = web3.eth; 
  const [alice, bob, carol] = accounts;
  const passA = padRight(fromAscii("password1"), 64);
  const passB = padRight(fromAscii("password2"), 64);
  const passC = padRight(fromAscii("password3"), 64)
  const secret = soliditySha3(passA, passB);
  const invalidAddress = "0x0000000000000000000000000000000000000000";

  beforeEach('deploy new instance', async () => {
    remittanceInstance = await Remittance.new({ from: alice });
  })

  it('should fail minimum value error', async () => {
    await truffleAssert.fails(
      remittanceInstance.create("bobSecret", "carolSecret", { from: alice })
    );
  })

  it('should fail invalid passwords', async () => {
    await truffleAssert.fails(
      remittanceInstance.create('0x00', '0x00', { from: alice, value: 100 })
    );
  })

  it('should create new transfer', async () => {
    await truffleAssert.passes(
      remittanceInstance.create(secret, carol, { from: alice, value: 200 })
    );
  })

  it('should fail puzzle already exists', async () => {
    await remittanceInstance.create(secret, carol, { from: alice, value: 200 })
    
    await truffleAssert.fails(
      remittanceInstance.create(secret, carol, { from: alice, value: 200 })
    );
  })

  it('should fail invalid recipient address', async () => {
    await truffleAssert.fails(
      remittanceInstance.create(secret, invalidAddress, { from: alice, value: 200 })
    );
  })

  it('should create and add balance to the contract', async () => {
    const balanceBefore = await getBalance(remittanceInstance.address);
    assert.strictEqual(balanceBefore, "0");

    await remittanceInstance.create(secret, carol, { from: alice, value: 200 });

    const balanceAfter = await getBalance(remittanceInstance.address);
    assert.strictEqual(balanceAfter, "200");
  })

  it('should emit transaction created event', async () => {
    const response = await remittanceInstance.create(secret, carol, { from: alice, value: 200 })
    assert.strictEqual('LogTransactionCreated', response.receipt.logs[0].event);
  })

  it('should not release funds to invalid puzzle', async () => {
    await remittanceInstance.create(secret, carol, { from: alice, value: 200 })

    await truffleAssert.fails(
      remittanceInstance.release(passC, passB, { from: carol})
    );
  })

  it('should not release funds to unauthorized account', async () => {
    await remittanceInstance.create(secret, carol, { from: alice, value: 200 })

    await truffleAssert.fails(
      remittanceInstance.release(passC, passB, { from: bob})
    );
  })

  it('should add funds to msg.sender balance', async () => {
    await remittanceInstance.create(secret, carol, { from: alice, value: 100 })
    
    const carolBalance = await remittanceInstance.balances(carol);
    assert.strictEqual(carolBalance.toString(10), "0");
    
    const response = await remittanceInstance.release(passA, passB, { from: carol});
    
    const carolBalanceAfter = await remittanceInstance.balances(carol);
    assert.strictEqual(carolBalanceAfter.toString(10), "100");
  })

  it('should emit funds released event', async () => {
    await remittanceInstance.create(secret, carol, { from: alice, value: 100 })
    const response = await remittanceInstance.release(passA, passB, { from: carol});
    
    assert.strictEqual(response.receipt.logs[0].event, "LogTransactionCompleted");
  })

  it('should not withdraw insufficient funds', async () => {
    await truffleAssert.fails(
      remittanceInstance.withdraw({ from: bob, value: 100 })
    );
  })

  it('should withdraw released funds', async () => {
    await remittanceInstance.create(secret, carol, { from: alice, value: 100 })
    await remittanceInstance.release(passA, passB, { from: carol });
    
    const accountBalance = toBN(await getBalance(carol));
    const stateBalance = toBN(await remittanceInstance.balances(carol));

    const response = await remittanceInstance.withdraw({ from: carol });
    const tx = await web3.eth.getTransaction(response.tx);
    const txFee = toBN(tx.gasPrice).mul(toBN(response.receipt.gasUsed)).toString(10);

    const accountBalanceUpdated = await getBalance(carol);
    const stateBalanceUpdated = await remittanceInstance.balances(carol);

    assert.strictEqual(stateBalance.sub(toBN(100)).toString(10), stateBalanceUpdated.toString(10));
    assert.strictEqual(accountBalanceUpdated, accountBalance.add(toBN(100).sub(toBN(txFee))).toString(10));
    assert.strictEqual(stateBalanceUpdated.toString(10), toBN(0).toString(10));    
  })

  it('should emit funds withdrawn event', async () => {
    await remittanceInstance.create(secret, carol, { from: alice, value: 100 })
    await remittanceInstance.release(passA, passB, { from: carol });
    const response = await remittanceInstance.withdraw({ from: carol });

    assert.strictEqual(response.receipt.logs[0].event, "LogWithdrawn");
  })
});