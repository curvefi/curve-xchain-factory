# pragma version 0.4.0
"""
@title Curve zkSync BridgeHub Wrapper
@author CurveFi
@license MIT
@custom:version 0.0.1
"""

version: public(constant(String[8])) = "0.0.1"


from ethereum.ercs import IERC20
from snekmate.auth import ownable

initializes: ownable


interface ZkSyncBridgeHub:
    def requestL2TransactionTwoBridges(request: L2TransactionRequestTwoBridgesOuter) -> bytes32: payable
    def sharedBridge() -> address: view
    def baseToken(_chainId: uint256) -> IERC20: view
    def l2TransactionBaseCost(_chainId: uint256, _gasPrice: uint256, _l2GasLimit: uint256, _l2GasPerPubdataByteLimit: uint256) -> uint256: view


event SetDestinationData:
    destination_data: DestinationData


struct L2TransactionRequestTwoBridgesOuter:
    chainId: uint256
    mintValue: uint256
    l2Value: uint256
    l2GasLimit: uint256
    l2GasPerPubdataByteLimit: uint256
    refundRecipient: address
    secondBridgeAddress: address
    secondBridgeValue: uint256
    secondBridgeCalldata: Bytes[MAX_TRANSFER_LEN]

struct DestinationData:
    bridge: address  # Shared Bridge
    base_token: IERC20
    l2_gas_limit: uint256
    l2_gas_price_limit: uint256  # (Default) Gas per Pubdata Byte Limit
    refund_recipient: address  # FeeCollector or Curve Vault
    allow_custom_refund: bool

struct ManualParameters:
    l2GasPerPubdataByteLimit: uint256
    refund_recipient: address  # if allowed
    gas_value: uint256  # amount in case of baseToken != ETH

struct RecoverInput:
    coin: IERC20
    amount: uint256


ZK_SYNC_ETH_ADDRESS: constant(address) = 0x0000000000000000000000000000000000000001
MAX_TRANSFER_LEN: constant(uint256) = 3 * 32

BRIDGE_HUB: public(constant(ZkSyncBridgeHub)) = ZkSyncBridgeHub(0x303a465B659cBB0ab36eE643eA362c509EEb5213)
CHAIN_ID: public(immutable(uint256))
destination_data: public(DestinationData)

owner: public(address)

manual_parameters: transient(ManualParameters)


@deploy
def __init__(_chain_id: uint256):
    CHAIN_ID = _chain_id

    default_data: DestinationData = DestinationData(
        bridge=staticcall BRIDGE_HUB.sharedBridge(),
        base_token=staticcall BRIDGE_HUB.baseToken(_chain_id),
        l2_gas_limit=2 * 10 ** 6,  # Create token if necessary + transfers
        l2_gas_price_limit=800,
        refund_recipient=empty(address),
        allow_custom_refund=True,
    )
    assert default_data.base_token != empty(IERC20), "baseToken not set"
    self.destination_data = default_data
    log SetDestinationData(default_data)

    crv: IERC20 = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52)
    assert extcall crv.approve(default_data.bridge, max_value(uint256))

    ownable.__init__()


exports: ownable.transfer_ownership


@internal
def _receive_token(token: IERC20, amount: uint256) -> uint256:
    if amount == max_value(uint256):
        amount = min(staticcall token.balanceOf(msg.sender), staticcall token.allowance(msg.sender, self))
    assert extcall token.transferFrom(msg.sender, self, amount, default_return_value=True)

    return staticcall token.balanceOf(self)


@internal
@view
def _applied_destination_data() -> DestinationData:
    """
    @notice Apply manual parameters to destiantion data
    """
    data: DestinationData = self.destination_data

    l2_gas_price_limit: uint256 = self.manual_parameters.l2GasPerPubdataByteLimit
    if l2_gas_price_limit > 0:
        data.l2_gas_price_limit = l2_gas_price_limit

    if data.allow_custom_refund:
        refund_recipient: address = self.manual_parameters.refund_recipient
        if refund_recipient != empty(address):
            data.refund_recipient = refund_recipient

    return data


@external
@payable
def bridge(_token: IERC20, _to: address, _amount: uint256, _min_amount: uint256=0) -> uint256:
    """
    @notice Bridge a token to zkSync using BridgedHub with SharedBridge.
        Might need manual parameters change from bridge initiator.
    @param _token The token to bridge (base token is not supported)
    @param _to The address to deposit the token to on L2
    @param _amount The amount of the token to deposit, 2^256-1 for the whole available balance
    @param _min_amount Minimum amount when to bridge
    @return Bridged amount
    """
    amount: uint256 = self._receive_token(_token, _amount)
    assert amount >= _min_amount, "Amount too small"

    data: DestinationData = self._applied_destination_data()

    if staticcall _token.allowance(self, data.bridge) < amount:
        extcall _token.approve(data.bridge, max_value(uint256))

    gas_value: uint256 = self.balance
    if data.base_token.address != ZK_SYNC_ETH_ADDRESS:
        gas_value = self.manual_parameters.gas_value
        if staticcall data.base_token.balanceOf(self) < gas_value:
            # gas expenses not transferred before call, so trying to fetch them from sender
            assert extcall data.base_token.transferFrom(msg.sender, self, gas_value, default_return_value=True)
        if staticcall data.base_token.allowance(self, data.bridge) < gas_value:
            extcall data.base_token.approve(data.bridge, max_value(uint256))

    extcall BRIDGE_HUB.requestL2TransactionTwoBridges(
        L2TransactionRequestTwoBridgesOuter(
            chainId=CHAIN_ID,
            mintValue=gas_value,
            l2Value=0,
            l2GasLimit=data.l2_gas_limit,
            l2GasPerPubdataByteLimit=data.l2_gas_price_limit,
            refundRecipient=data.refund_recipient,
            secondBridgeAddress=data.bridge,
            secondBridgeValue=0,
            secondBridgeCalldata=abi_encode(_token.address, amount, _to),
        ),
        value=gas_value if data.base_token.address == ZK_SYNC_ETH_ADDRESS else 0,
    )
    return amount


@view
@external
def check(_account: address) -> bool:
    """
    @notice Dummy method to check if caller is allowed to bridge
    @param _account The account to check
    """
    return True


@view
@external
def cost(_basefee: uint256=block.basefee) -> uint256:
    """
    @notice Cost in ETH to bridge
    """
    l2_gas_price_limit: uint256 = self.manual_parameters.l2GasPerPubdataByteLimit
    if l2_gas_price_limit == 0:
        l2_gas_price_limit = self.destination_data.l2_gas_price_limit
    return staticcall BRIDGE_HUB.l2TransactionBaseCost(
        CHAIN_ID,
        _basefee,
        self.destination_data.l2_gas_limit,
        l2_gas_price_limit,
    )


@external
def set_manual_parameters(_manual_parameters: ManualParameters):
    """
    @notice Set manual parameters that will be actual within current transaction
    """
    self.manual_parameters = _manual_parameters


@external
def set_destination_data(_destination_data: DestinationData):
    """
    @notice Set custom destination data. In order to turn off chain id set bridge=0xdead
    """
    ownable._check_owner()

    self.destination_data = _destination_data
    log SetDestinationData(_destination_data)


@external
def recover(_recovers: DynArray[RecoverInput, 64], _receiver: address):
    """
    @notice Recover ERC20 tokens or Ether from this contract
    @dev Callable only by owner and emergency owner
    @param _recovers (Token, amount) to recover
    @param _receiver Receiver of coins
    """
    ownable._check_owner()

    for input: RecoverInput in _recovers:
        amount: uint256 = input.amount
        if input.coin.address == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE:
            if amount == max_value(uint256):
                amount = self.balance
            raw_call(_receiver, b"", value=amount)
        else:
            if amount == max_value(uint256):
                amount = staticcall input.coin.balanceOf(self)
            extcall input.coin.transfer(_receiver, amount, default_return_value=True)  # do not need safe transfer
