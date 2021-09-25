import pytest
from brownie.convert import to_address
from hexbytes import HexBytes


@pytest.fixture
def keccak(web3):
    return web3.keccak


@pytest.fixture
def vyper_proxy_init_code():
    """Calculate the EIP1167 initcode used by Vyper to deploy proxies.

    https://eips.ethereum.org/EIPS/eip-1167

    Arguments:
        _target: The target implementation address
    """

    def _f(_target):
        addr = HexBytes(_target)
        pre = HexBytes("0x602D3D8160093D39F3363d3d373d3d3d363d73")
        post = HexBytes("0x5af43d82803e903d91602b57fd5bf3")
        return HexBytes(pre + (addr + HexBytes(0) * (20 - len(addr))) + post)

    return _f


@pytest.fixture
def create2_address_of(keccak):
    """Calculate the CREATE2 deployment address of a contract.

    https://eips.ethereum.org/EIPS/eip-1014

    Arguments:
        _addr: The contract deploying a sub contract
        _salt: The random salt value supplied to CREATE2
        _initcode: Is the code that, when executed, produces the runtime bytecode
    """

    def _f(_addr, _salt, _initcode):
        prefix = HexBytes("0xff")
        addr = HexBytes(_addr)
        salt = HexBytes(_salt)
        initcode = HexBytes(_initcode)
        return to_address(keccak(prefix + addr + salt + keccak(initcode))[12:])

    return _f
