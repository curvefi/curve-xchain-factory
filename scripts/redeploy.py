import csv

import rlp
from brownie import ZERO_ADDRESS, Recover, Script, accounts, web3
from hexbytes import HexBytes

with open("redeploy_data.csv") as f:
    data = [(int(row[0]), *row[1:-2]) for i, row in enumerate(csv.reader(f)) if i != 0]

tx = {
    "nonce": "0x",
    "gasPrice": 40 * 10**9,
    "gasLimit": 600000,
    "to": "0x",
    "value": 4 * 10**18,  # 4 ETH
    "data": Script.deploy.encode_input(data),
    "v": 27,
    "r": 0x1234567890ABCDEF,
    "s": 0x1234567890ABCDEF,
}


def main():
    recover = Recover.deploy({"from": accounts[0]})
    sighash = web3.keccak(rlp.encode([HexBytes(v) for k, v in tx.items() if k not in "vrs"]))

    while (sender := recover.recover(sighash, tx["v"], tx["r"], tx["s"])) == ZERO_ADDRESS:
        tx["r"] += 1
    serialized = rlp.encode(list(map(HexBytes, tx.values()))).hex()

    print(f"Send 4.03 ETH to account: {sender}")
    print(
        "Contract instance will be created and destroyed at:",
        accounts.at(sender, force=True).get_deployment_address(0),
    )
    print(f"Then submit the following raw transaction: \n\n'{serialized}")
