# @version 0.2.16
"""
@title Curve Root Chain Gauge Factory
@license MIT
@author Curve.fi
@notice Root chain gauge factory enabling permissionless deployment of cross chain gauges
"""


interface RootGauge:
    def initialize(): nonpayable


event OwnershipTransferred:
    _owner: address
    _new_owner: address

event GaugeDeployed:
    _chain_id: indexed(uint256)
    _deployer: indexed(address)
    _gauge: address


struct ChainData:
    implementation: address
    gauges: address[MAX_UINT256]
    size: uint256


owner: public(address)
future_owner: public(address)

chain_data: HashMap[uint256, ChainData]
# chain_id -> msg_sender -> nonce
nonces: public(HashMap[uint256, HashMap[address, uint256]])


@external
def __init__():
    self.owner = msg.sender

    log OwnershipTransferred(ZERO_ADDRESS, msg.sender)


@view
@external
def get_implementation(_chain_id: uint256) -> address:
    """
    @notice Get the root gauge implementation used for `_chain_id`
    @param _chain_id The chain id of interest
    """
    return self.chain_data[_chain_id].implementation


@view
@external
def get_size(_chain_id: uint256) -> uint256:
    """
    @notice Get the number of gauges deployed for `_chain_id`
    @param _chain_id The chain id of interest
    """
    return self.chain_data[_chain_id].size


@view
@external
def get_gauge(_chain_id: uint256, _idx: uint256) -> address:
    """
    @notice Get the address of a deployed root gauge for `_chain_id`
    @dev Index values greater than the size of the chain's gauge list will
        return `ZERO_ADDRESS`
    @param _chain_id The chain id of interest
    @param _idx The index of the gauge to retrieve from `_chain_id`'s gauge list
    """
    return self.chain_data[_chain_id].gauges[_idx]


@external
def deploy_gauge(_chain_id: uint256) -> address:
    """
    @notice Deploy a root gauge for `_chain_id`
    @param _chain_id The chain id of interest
    @return The address of the deployed and initialized root gauge
    """
    # generate the salt used for CREATE2 deployment of gauge
    nonce: uint256 = self.nonces[_chain_id][msg.sender]
    salt: bytes32 = keccak256(_abi_encode(_chain_id, msg.sender, nonce))
    gauge: address = create_forwarder_to(self.chain_data[_chain_id].implementation, salt=salt)

    # increase the nonce of the deployer
    self.nonces[_chain_id][msg.sender] = nonce + 1

    # append the newly deployed gauge to list of chain's gauges
    size: uint256 = self.chain_data[_chain_id].size
    self.chain_data[_chain_id].gauges[size] = gauge
    self.chain_data[_chain_id].size = size + 1

    # initialize the gauge
    RootGauge(gauge).initialize()

    log GaugeDeployed(_chain_id, msg.sender, gauge)
    return gauge


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
