# @version 0.2.16
"""
@title Curve Child Chain Streamer Factory
@license MIT
@author Curve.fi
@notice Child chain streamer factory enabling permissionless deployment of cross chain streamers
"""


interface ChildStreamer:
    def initialize(_deployer: address, _receiver: address): nonpayable


event OwnershipTransferred:
    _owner: address
    _new_owner: address

event StreamerDeployed:
    _deployer: indexed(address)
    _streamer: address
    _receiver: address

event ImplementationUpdated:
    _implementation: address
    _new_implementation: address


owner: public(address)
future_owner: public(address)

get_implementation: public(address)
get_size: public(uint256)
# Using MAX_UINT256 raises `Exception: Value too high`
get_streamer: public(address[MAX_INT128])

nonces: public(HashMap[address, uint256])

reward_token: public(address)
threshold: public(uint256)


@external
def __init__(_reward_token: address):
    self.owner = msg.sender
    self.reward_token = _reward_token
    # minimum amount of new rewards being deposited in order for
    # `notify` to be called on child streamers. Prevents bad actors
    # from calling `notify` without first donating 1_000 CRV
    self.threshold = 1_000 * 10 ** 18

    log OwnershipTransferred(ZERO_ADDRESS, msg.sender)


@external
@nonreentrant("lock")
def deploy_streamer(_receiver: address) -> address:
    """
    @notice Deploy a child streamer
    @param _receiver Rewards receiver for the child streamer
    @return The address of the deployed and initialized child streamer
    """
    assert _receiver != ZERO_ADDRESS

    # generate the salt used for CREATE2 deployment of gauge
    nonce: uint256 = self.nonces[msg.sender]
    salt: bytes32 = keccak256(_abi_encode(chain.id, msg.sender, nonce))
    streamer: address = create_forwarder_to(self.get_implementation, salt=salt)

    # increase the nonce of the deployer
    self.nonces[msg.sender] = nonce + 1

    # append the newly deployed gauge to list of chain's gauges
    size: uint256 = self.get_size
    self.get_streamer[size] = streamer
    self.get_size = size + 1

    # initialize the gauge
    ChildStreamer(streamer).initialize(msg.sender, _receiver)

    log StreamerDeployed(msg.sender, streamer, _receiver)
    return streamer


@external
def set_implementation(_implementation: address):
    """
    @notice Set the child streamer implementation
    @param _implementation The child streamer implementation contract address
    """
    assert msg.sender == self.owner

    implementation: address = self.get_implementation
    self.get_implementation = _implementation

    log ImplementationUpdated(implementation, _implementation)


@external
def commit_transfer_ownership(_new_owner: address):
    """
    @notice Transfer ownership of to `_new_owner`
    @param _new_owner New owner address
    """
    assert msg.sender == self.owner  # dev: owner only
    self.future_owner = _new_owner


@external
def accept_transfer_ownership():
    """
    @notice Accept ownership
    @dev Only callable by the future owner
    """
    new_owner: address = self.future_owner
    assert msg.sender == new_owner  # dev: new owner only

    owner: address = self.owner
    self.owner = new_owner

    log OwnershipTransferred(owner, new_owner)
