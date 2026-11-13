# pragma version 0.3.10
"""
@title Reward Forwarder
@custom:version 0.1.0
"""

# Updated from 0.0.1:
# - forwards at most what fits under the gauge's cap on undistributed rewards (2**96),
#   the rest stays here for the next call instead of making the deposit revert
version: public(constant(String[8])) = "0.1.0"


from vyper.interfaces import ERC20


interface Gauge:
    def deposit_reward_token(_reward_token: address, _amount: uint256): nonpayable
    def claim_rewards(_addr: address): nonpayable


# Gauge reverts when the undistributed reward together with a new deposit exceeds this
MAX_REWARD: constant(uint256) = 2 ** (64 + 32)

GAUGE: immutable(address)


@external
def __init__(_gauge: address):
    GAUGE = _gauge


@external
def deposit_reward_token(_reward_token: address):
    """
    @param _reward_token The address of token that gets forwarded to the gauge
    @notice Deposit a reward token in the gauge
    @dev This contract should be set as the distributor of `_reward_token` in the
        gauge, else the tx will fail.
    @dev Any user can forward deposited reward tokens to a gauge, after calling
        `allow`.
    @dev Forwards the balance up to the room left under the gauge's reward cap; what
        does not fit stays in this contract and can be forwarded later.
    """
    # Checkpoint rewards first, so that the room is measured against the current state.
    # This contract holds no gauge tokens: nothing is claimed.
    Gauge(GAUGE).claim_rewards(self)
    amount: uint256 = min(ERC20(_reward_token).balanceOf(self), self._max_deposit(_reward_token))
    Gauge(GAUGE).deposit_reward_token(_reward_token, amount)


@view
@internal
def _max_deposit(_reward_token: address) -> uint256:
    """
    @dev Room under the cap by the stored `reward_remaining`. A checkpoint can only
        free more room, so without one this is a lower bound. Gauges without
        `reward_remaining` (no undistributed carry) are treated as empty.
    """
    success: bool = False
    response: Bytes[32] = b""
    success, response = raw_call(
        GAUGE,
        _abi_encode(_reward_token, method_id=method_id("reward_remaining(address)")),
        max_outsize=32,
        is_static_call=True,
        revert_on_failure=False,
    )
    remaining: uint256 = 0
    if success and len(response) == 32:
        remaining = convert(response, uint256)

    if remaining >= MAX_REWARD:
        return 0
    return MAX_REWARD - remaining


@external
def allow(_reward_token: address):
    """
    @param _reward_token The address of token that gets forwarded to the gauge
    @notice Allow `_reward_token` to be transferred from self to Gauge
    @dev This method is a more gas efficient way to handle token approvals, by avoiding
        a storage variable to verify it token was approved, and calls to the token to
        check for approval.
    """
    response: Bytes[32] = raw_call(
        _reward_token,
        _abi_encode(GAUGE, MAX_UINT256, method_id=method_id("approve(address,uint256)")),
        max_outsize=32,
    )
    if len(response) != 0:
        assert convert(response, bool)


@pure
@external
def gauge() -> address:
    return GAUGE
