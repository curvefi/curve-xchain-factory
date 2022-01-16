// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.6;

// MPC management means multi-party validation.
// MPC signing likes Multi-Signature is more secure than use private key directly.
abstract contract MPCManageable {
    address public mpc;
    address public pendingMPC;

    uint256 public constant delay = 2 days;
    uint256 public delayMPC;

    modifier onlyMPC() {
        require(msg.sender == mpc, "MPC: only mpc");
        _;
    }

    event LogChangeMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint256 effectiveTime);

    event LogApplyMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint256 applyTime);

    constructor(address _mpc) {
        require(_mpc != address(0), "MPC: mpc is the zero address");
        mpc = _mpc;
        emit LogChangeMPC(address(0), mpc, block.timestamp);
    }

    function changeMPC(address _mpc) external onlyMPC {
        require(_mpc != address(0), "MPC: mpc is the zero address");
        pendingMPC = _mpc;
        delayMPC = block.timestamp + delay;
        emit LogChangeMPC(mpc, pendingMPC, delayMPC);
    }

    function applyMPC() external {
        require(msg.sender == pendingMPC, "MPC: only pendingMPC");
        require(block.timestamp >= delayMPC, "MPC: time before delayMPC");
        emit LogApplyMPC(mpc, pendingMPC, block.timestamp);
        mpc = pendingMPC;
        pendingMPC = address(0);
        delayMPC = 0;
    }
}

// support limit operations to whitelist
abstract contract Whitelistable is MPCManageable {
    mapping(address => mapping(uint256 => mapping(address => bool))) public isInWhitelist;
    mapping(address => mapping(uint256 => address[])) public whitelists;
    mapping(address => bool) public isBlacklisted;

    event LogSetWhitelist(address indexed from, uint256 indexed chainID, address indexed to, bool flag);

    modifier onlyWhitelisted(address from, uint256 chainID, address[] memory to) {
        mapping(address => bool) storage map = isInWhitelist[from][chainID];
        for (uint256 i = 0; i < to.length; i++) {
            require(map[to[i]], "AnyCall: to address is not in whitelist");
        }
        _;
    }

    constructor(address _mpc) MPCManageable(_mpc) {}

    /**
        @notice Query the number of elements in the whitelist of `whitelists[from][chainID]`
        @param from The initiator of a cross chain interaction
        @param chainID The target chain's identifier
        @return uint256 The length of addresses `from` is allowed to call on `chainID`
    */
    function whitelistLength(address from, uint256 chainID) external view returns (uint256) {
        return whitelists[from][chainID].length;
    }

    /**
        @notice Approve/Revoke a caller's permissions to initiate a cross chain interaction
        @param from The initiator of a cross chain interaction
        @param chainID The target chain's identifier
        @param to The address of the target `from` is being allowed/disallowed to call
        @param flag Boolean denoting whether permissions is being granted/denied
    */
    function whitelist(address from, uint256 chainID, address to, bool flag) external onlyMPC {
        require(isInWhitelist[from][chainID][to] != flag, "nothing change");
        address[] storage list = whitelists[from][chainID];
        if (flag) {
            list.push(to);
        } else {
            uint256 length = list.length;
            for (uint i = 0; i < length; i++) {
                if (list[i] == to) {
                    if (i + 1 < length) {
                        list[i] = list[length-1];
                    }
                    list.pop();
                    break;
                }
            }
        }
        isInWhitelist[from][chainID][to] = flag;
        emit LogSetWhitelist(from, chainID, to, flag);
    }

    function blacklist(address account, bool flag) external onlyMPC {
        isBlacklisted[account] = flag;
    }
}

abstract contract Billable is Whitelistable {
    event Fund(address indexed beneficiary, uint256 amount);

    mapping(address => int256) public funds;
    uint256 public expenses;

    modifier bill(address originator) {
        uint256 gas = gasleft();
        _;
        uint256 cost = (gas - gasleft()) * tx.gasprice;
        funds[originator] -= int256(cost); // potential insufficient balances
        expenses += cost;
    }

    constructor(address _mpc) Whitelistable(_mpc) {}

    function fund(address beneficiary) external payable {
        funds[beneficiary] += int256(msg.value);
        emit Fund(beneficiary, msg.value);
    }

    function refundMPC() external {
        uint256 amount = expenses;
        if (address(this).balance >= amount) {
            expenses = 0;
            mpc.call{value: amount}("");
        } else {
            expenses = amount - address(this).balance;
            mpc.call{value: address(this).balance}("");
        }
    }
}

contract AnyCallProxy is Billable {
    event LogAnyCall(address indexed from, address[] to, bytes[] data,
                     address[] callbacks, uint256[] nonces, uint256 fromChainID, uint256 toChainID);
    event LogAnyExec(address indexed from, address[] to, bytes[] data, bool[] success, bytes[] result,
                     address[] callbacks, uint256[] nonces, uint256 fromChainID, uint256 toChainID);

    struct Context {
        address sender;
        uint256 fromChainID;
    }

    Context public context;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'AnyCall: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _mpc) Billable(_mpc) {}

    // @notice Query the chainID of this contract
    // @dev Implemented as a view function so it is less expensive. CHAINID < PUSH32
    function cID() external view returns (uint256) {
        return block.chainid;
    }

    /**
        @notice Trigger a cross-chain contract interaction
        @param to - list of addresses to call
        @param data - list of data payloads to send / call
        @param callbacks - the callbacks on the fromChainID to call
        `callback(address to, bytes data, uint256 nonces, uint256 fromChainID, bool success, bytes result)`
        @param nonces - the nonces (ordering) to include for the resulting callback
        @param toChainID - the recipient chain that will receive the events
    */
    function anyCall(
        address[] memory to,
        bytes[] memory data,
        address[] memory callbacks,
        uint256[] memory nonces,
        uint256 toChainID
    ) external onlyWhitelisted(msg.sender, toChainID, to) {
        require(toChainID != block.chainid, "AnyCall: FORBID");
        require(!isBlacklisted[msg.sender]);
        emit LogAnyCall(msg.sender, to, data, callbacks, nonces, block.chainid, toChainID);
    }

    function anyCall(
        address from,
        address[] memory to,
        bytes[] memory data,
        address[] memory callbacks,
        uint256[] memory nonces,
        uint256 fromChainID
    ) external onlyMPC lock bill(from) {
        require(from != address(this) && from != address(0), "AnyCall: FORBID");
        require(!isBlacklisted[from]);

        uint256 length = to.length;
        bool[] memory success = new bool[](length);
        bytes[] memory results = new bytes[](length);

        context = Context({sender: from, fromChainID: fromChainID});

        for (uint256 i = 0; i < length; i++) {
            address _to = to[i];
            if (isInWhitelist[from][block.chainid][_to]) {
                (success[i], results[i]) = _to.call{value:0}(data[i]);
            } else {
                (success[i], results[i]) = (false, "forbid calling");
            }
        }
        context = Context({sender: from, fromChainID: 0});
        emit LogAnyExec(from, to, data, success, results, callbacks, nonces, fromChainID, block.chainid);
    }
}
