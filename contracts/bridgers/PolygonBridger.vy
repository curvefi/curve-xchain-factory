# @version 0.3.1
"""
@title Curve Polygon Bridge Wrapper
"""
from vyper.interfaces import ERC20


CRV20: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
POLYGON_BRIDGE_MANAGER: constant(address) = 0xA0c68C638235ee32657e8f720a23ceC1bFc77C77
POLYGON_BRIDGE_RECEIVER: constant(address) = 0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf


is_approved: public(HashMap[address, bool])


@external
def __init__():
    # we already know ahead of time that CRV will be bridged
    assert ERC20(CRV20).approve(POLYGON_BRIDGE_RECEIVER, MAX_UINT256)
    self.is_approved[CRV20] = True


@external
def bridge(_token: address, _to: address, _amount: uint256):
    assert ERC20(_token).transferFrom(msg.sender, self, _amount)

    if _token != CRV20 and not self.is_approved[_token]:
        assert ERC20(_token).approve(POLYGON_BRIDGE_RECEIVER, MAX_UINT256)
        self.is_approved[_token] = True

    raw_call(
        POLYGON_BRIDGE_MANAGER,
        _abi_encode(
            _to,
            _token,
            convert(96, uint256),
            convert(32, uint256),
            _amount,
            method_id=method_id("depositFor(address,address,bytes)")
        )
    )


@pure
@external
def cost() -> uint256:
    return 0


@pure
@external
def check(_account: address) -> bool:
    return True
