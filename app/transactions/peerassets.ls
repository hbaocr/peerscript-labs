pa = require '../lib/peerassets/peerassets'

{ Transaction, Script, PrivateKey } = require 'bitcore-lib'
{ each } = require 'prelude-ls'
{ assert } = require 'chai'

asset-owner-private-key = new PrivateKey()
prev-txn = new Transaction().to(asset-owner-private-key.to-public-key().to-address(), 10000000)
utxo = prev-txn.get-unspent-output 0

pa.setup true, true

deck-spawn-txn = undefined
number-of-decimals = 2

describe 'PeerAssets', ->
  specify 'Deck spawn', (done) ->
    asset-short-name = 'hello'

    # Create deck spawn transaction
    unsigned-deck-spawn = pa.createDeckSpawnTransaction(
      utxo,
      asset-short-name,
      number-of-decimals,
      [ pa.ISSUE_MODE.ONCE, pa.ISSUE_MODE.CUSTOM ]
    )
    deck-spawn-txn := unsigned-deck-spawn.sign(asset-owner-private-key)

    # Decode deck spawn transaction
    decoded-deck-spawn-txn = pa.decodeDeckSpawnTransaction(deck-spawn-txn)

    # Check encoded asset data
    assert.equal decoded-deck-spawn-txn.owner, asset-owner-private-key.to-address().to-string(), 'Failed to decode asset owner'
    assert.equal decoded-deck-spawn-txn.shortName, asset-short-name, 'Failed to decode asset short name'
    assert.equal decoded-deck-spawn-txn.number-of-decimals, number-of-decimals, 'Failed to decode number of decimals'
    assert decoded-deck-spawn-txn.issue-mode .&. pa.ISSUE_MODE.ONCE, 'Failed to check ONCE flag'
    assert decoded-deck-spawn-txn.issue-mode .&. pa.ISSUE_MODE.CUSTOM, 'Failed to check MULTI flag'
    assert.deepEqual decoded-deck-spawn-txn.get-issue-modes(), ['CUSTOM', 'ONCE'], 'Failed to get issue mode list'

    # Make sure bitwise combination of issue modes serializes equally
    unsigned-deck-spawn2 = pa.createDeckSpawnTransaction(
      utxo,
      asset-short-name,
      number-of-decimals,
      pa.ISSUE_MODE.ONCE .^. pa.ISSUE_MODE.CUSTOM
    )
    deck-spawn-txn2 = unsigned-deck-spawn2.sign(asset-owner-private-key)

    assert.equal unsigned-deck-spawn2.serialize(true), unsigned-deck-spawn.serialize(true)

    done()

  specify 'Card transfer', (done) ->
    # random sender
    sender = new PrivateKey()
    prev-txn = new Transaction().to(sender.to-address(), 10000000)
    utxo = prev-txn.get-unspent-output 0
    # random receivers
    amounts-map = {}
    amounts-map[new PrivateKey().to-address().to-string()] = 123
    amounts-map[new PrivateKey().to-address().to-string()] = 456
    amounts-map[new PrivateKey().to-address().to-string()] = 789

    # Create a card transfer transaction
    transfer-txn = pa.createCardTransferTransaction(utxo, amounts-map, deck-spawn-txn)
                     .sign(sender)

    # Decode the card transfer transaction
    decoded-transfer-txn = pa.decodeCardTransferTransaction(transfer-txn)

    # Check encoded transfer data
    assert.equal decoded-transfer-txn.from, sender.to-address().to-string(), 'Failed to decode transfer sender'
    assert.equal decoded-transfer-txn.number-of-decimals, number-of-decimals, 'Failed to decode transfer amount'

    # Check all amounts are correctly (de)serialized
    for address, amount of decoded-transfer-txn.to
      assert.equal amount, amounts-map[address], 'Failed to decode transfer receiver'

    done()
