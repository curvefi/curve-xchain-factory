from brownie import RootGaugeFactory, web3
from brownie.convert import to_address
from eth_abi import encode_single
from hexbytes import HexBytes


def keccak(val):
    return web3.keccak(val)


def vyper_proxy_init_code(_target: str):
    """Calculate the EIP1167 initcode used by Vyper to deploy proxies.

    https://eips.ethereum.org/EIPS/eip-1167

    Arguments:
        _target: The target implementation address
    """

    addr = HexBytes(_target)
    pre = HexBytes("0x602D3D8160093D39F3363d3d373d3d3d363d73")
    post = HexBytes("0x5af43d82803e903d91602b57fd5bf3")
    return HexBytes(pre + (addr + HexBytes(0) * (20 - len(addr))) + post)


def create2_address_of(_addr, _salt, _initcode):
    """Calculate the CREATE2 deployment address of a contract.

    https://eips.ethereum.org/EIPS/eip-1014

    Arguments:
        _addr: The contract deploying a sub contract
        _salt: The random salt value supplied to CREATE2
        _initcode: Is the code that, when executed, produces the runtime bytecode
    """

    prefix = HexBytes("0xff")
    addr = HexBytes(_addr)
    salt = HexBytes(_salt)
    initcode = HexBytes(_initcode)
    return to_address(keccak(prefix + addr + salt + keccak(initcode))[12:])


def main(_chain_id: str, _deployer: str, _salt: str):
    factory = RootGaugeFactory.at("0xabC000d88f23Bb45525E447528DBF656A9D55bf5")
    implementation_addr = factory.get_implementation()

    init_code = vyper_proxy_init_code(implementation_addr)
    salt = keccak(
        encode_single("(uint256,address,bytes32)", [int(_chain_id), _deployer, HexBytes(_salt)])
    )
    print(create2_address_of(factory.address, salt, init_code))
