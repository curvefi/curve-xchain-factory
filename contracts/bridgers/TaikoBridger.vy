# @version 0.4.0
"""
@title TaikoBridger
@custom:version 0.0.1
@author Curve.Fi
@license Copyright (c) Curve.Fi, 2020-2024 - all rights reserved
@notice Curve Taiko bridge wrapper
"""

version: public(constant(String[8])) = "0.0.1"

from ethereum.ercs import IERC20
from snekmate.auth import ownable
import IBridger

initializes: ownable
implements: IBridger


interface ERC20Vault:
    def sendToken(_op: BridgeTransferOp) -> Message: payable

struct BridgeTransferOp:
    destChainId: uint64  # Destination chain ID.
    destOwner: address  # The owner of the bridge message on the destination chain.
    to: address  # Recipient address.
    fee: uint64  # Processing fee for the relayer.
    token: address  # Address of the token.
    gasLimit: uint32  # Gas limit for the operation.
    amount: uint256  # Amount to be bridged.

struct Message:
    id: uint64  # Message ID whose value is automatically assigned.
    fee: uint64  # The max processing fee for the relayer. This fee has 3 parts:
                 # - the fee for message calldata.
                 # - the minimal fee reserve for general processing, excluding function call.
                 # - the invocation fee for the function call.
                 # Any unpaid fee will be refunded to the destOwner on the destination chain.
                 # Note that fee must be 0 if gasLimit is 0, or large enough to make the invocation fee
                 # non-zero.
    gasLimit: uint32  # gasLimit that the processMessage call must have.
    _from: address  # The address, EOA or contract, that interacts with this bridge.
                    # The value is automatically assigned.
    srcChainId: uint64  # Source chain ID whose value is automatically assigned.
    srcOwner: address  # The owner of the message on the source chain.
    destChainId: uint64  # Destination chain ID where the `to` address lives.
    destOwner: address  # The owner of the message on the destination chain.
    to: address  # The destination address on the destination chain.
    value: uint256  # value to invoke on the destination chain.
    data: Bytes[1024]  # callData to invoke on the destination chain.

struct ManualParameters:
    dest_owner: address


CRV20: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
ERC20_VAULT: public(constant(ERC20Vault)) = ERC20Vault(0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab)

gas_price: public(uint256)
gas_limit: public(uint256)
dest_owner: public(address)

DESTINATION_CHAIN_ID: public(immutable(uint256))

allow_manual_parameters: public(bool)
manual_parameters: transient(ManualParameters)


@deploy
def __init__(_chain_id: uint256, _dest_owner: address):
    """
    @param _chain_id Chain ID to bridge to
    @param _dest_owner Destination default excess fee owner
    """
    DESTINATION_CHAIN_ID = _chain_id

    assert extcall IERC20(CRV20).approve(ERC20_VAULT.address, max_value(uint256))

    self.gas_price = 5 * 10 ** 8  # 0.5 gwei
    self.gas_limit = 1_315_360

    self.dest_owner = _dest_owner

    ownable.__init__()


exports: (
    ownable.owner,
    ownable.transfer_ownership,
)


@external
@payable
def bridge(_token: IERC20, _to: address, _amount: uint256, _min_amount: uint256=0) -> uint256:
    """
    @notice Bridge `_token` through Taiko Bridge
    @param _token The ERC20 asset to bridge
    @param _to The receiver on `_chain_id`
    @param _amount The amount of `_token` to deposit, 2^256-1 for the whole balance
    @param _min_amount Minimum amount when to bridge
    @return Bridged amount
    """
    amount: uint256 = _amount
    if amount == max_value(uint256):
        amount = min(staticcall _token.balanceOf(msg.sender), staticcall _token.allowance(msg.sender, self))
    assert amount >= _min_amount, "Amount too small"

    assert extcall _token.transferFrom(msg.sender, self, amount)

    dest_owner: address = self.manual_parameters.dest_owner
    if not self.allow_manual_parameters or dest_owner == empty(address):
        dest_owner = self.dest_owner
    gas_limit: uint256 = self.gas_limit
    fee: uint256 = self.gas_price * gas_limit
    extcall ERC20_VAULT.sendToken(
        BridgeTransferOp(
            destChainId=convert(DESTINATION_CHAIN_ID, uint64),
            destOwner=dest_owner,  # The owner of the bridge message on the destination chain.
            to=_to,
            fee=convert(fee, uint64),
            token=_token.address,
            gasLimit=convert(gas_limit, uint32),
            amount=amount,
        ),
        value=fee,
    )
    return amount


@view
@external
def cost() -> uint256:
    """
    @notice Cost in ETH to bridge
    """
    return self.gas_price * self.gas_limit


@view
@external
def check(_account: address) -> bool:
    """
    @notice Check if `_account` is allowed to bridge
    @param _account The account to check
    """
    return True


@external
def set_manual_parameters(_manual_parameters: ManualParameters):
    """
    @notice Set manual parameters that will be actual within current transaction
    @param _manual_parameters ()
    """
    self.manual_parameters = _manual_parameters


@external
def set_fee(_new_gas_price: uint256, _new_gas_limit: uint256):
    """
    @notice Set gas parameters
    """
    ownable._check_owner()

    self.gas_price = _new_gas_price
    self.gas_limit = _new_gas_limit


@external
def set_dest_owner(_new_dest_owner: address):
    """
    @notice Set new destination bridge transaction owner
    @param _new_dest_owner New transaction initiator (better be Curve Vault)
    """
    ownable._check_owner()

    self.dest_owner = _new_dest_owner


@external
def set_allow_manual_parameters(_allow: bool):
    """
    @notice Allow to set manual parameters(dest_owner)
    @param _allow Whether to allow
    """
    ownable._check_owner()

    self.allow_manual_parameters = _allow
