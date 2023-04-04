from web3 import Web3

w3 = Web3()
account = w3.eth.account.create()
print(f'account={account.address}, key={w3.to_hex(account._private_key)}')
