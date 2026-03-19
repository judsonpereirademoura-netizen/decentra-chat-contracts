// Sources flattened with hardhat v2.28.6 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/utils/Context.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File @openzeppelin/contracts/utils/Pausable.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// File contracts/DGovGovernance.sol

pragma solidity ^0.8.24;


    function getTotalEmitted() external view returns (uint256);
    function getVestingWeight(address holder) external view returns (uint256);
    function founder() external view returns (address);
}

contract DGovGovernance is ReentrancyGuard, Pausable {

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    uint256 public constant PROPOSAL_DURATION = 7 days;
    uint256 public constant TIMELOCK_DELAY = 48 hours;
    uint256 public constant QUORUM_BPS = 6001;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PROPOSAL_THRESHOLD_BPS = 100;
    uint256 public constant VOTER_INACTIVITY_PERIOD = 90 days;
    uint256 public constant MAX_DELEGATORS_PER_DELEGATE = 50; // [F-21]
    uint256 public constant EXECUTION_DEADLINE = 7 days; // [F-23] Prazo máximo para executar após timelock

    // =========================================================================
    // STATE — Core
    // =========================================================================

    IDGovToken public immutable dgov;
    address public admin;
    address public pendingAdmin; // [F-22] Admin transfer com aceitação
    uint256 public adminTransferTimestamp; // [F-22] Timestamp do pedido de transferência

    // [F-19] Whitelist de targets permitidos para execução de propostas
    mapping(address => bool) public allowedTargets;

    // =========================================================================
    // STATE — Proposals (split into small structs to avoid stack-too-deep)
    // =========================================================================

    struct ProposalCore {
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 timelockEnd;
        uint256 snapshotTotalEmitted;
        uint8 proposalType;
        bool executed;
    }

    struct ProposalVotes {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
    }

    struct ProposalExecution {
        address target;
        bytes data;
    }

    uint256 public proposalCount;
    mapping(uint256 => ProposalCore) public proposalCores;
    mapping(uint256 => ProposalVotes) public proposalVotes;
    mapping(uint256 => ProposalExecution) internal proposalExecutions;
    mapping(uint256 => string) public proposalTitles;
    mapping(uint256 => string) public proposalDescriptions;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnProposal;

    // =========================================================================
    // STATE — Voters
    // =========================================================================

    struct VoterInfo {
        bool isRegisteredVoter;
        bool isActive;
        uint256 lastVoteTimestamp;
        uint256 registrationTime;
        address delegate;
    }

    struct BalanceSnapshot {
        uint256 balance;
        uint256 vestingWeight;
        bool recorded;
    }

    mapping(address => VoterInfo) public voters;
    mapping(address => address[]) public delegators;
    uint256 public totalRegisteredVoters;
    uint256 public totalActiveVoters;
    mapping(uint256 => mapping(address => BalanceSnapshot)) public balanceSnapshots;

    // =========================================================================
    // EVENTS
    // =========================================================================

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, uint8 proposalType, uint256 snapshotTotalEmitted);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalQueued(uint256 indexed proposalId, uint256 timelockEnd);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoterRegistered(address indexed voter);
    event VoterDeactivated(address indexed voter);
    event VoterReactivated(address indexed voter);
    event DelegateSet(address indexed voter, address indexed delegate);
    event DelegateRemoved(address indexed voter, address indexed previousDelegate);
    event AdminTransferInitiated(address indexed currentAdmin, address indexed pendingAdmin);
    event AdminTransferCompleted(address indexed previousAdmin, address indexed newAdmin);
    event TargetAllowed(address indexed target, bool allowed);
    event ProposalCancelled(uint256 indexed proposalId, address indexed cancelledBy);

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    constructor(address _dgov, address _admin) {
        require(_dgov != address(0) && _admin != address(0), "Invalid address");
        dgov = IDGovToken(_dgov);
        admin = _admin;
    }

    // =========================================================================
    // ADMIN MANAGEMENT [F-22]
    // =========================================================================

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function initiateAdminTransfer(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0) && _newAdmin != admin, "Invalid new admin");
        pendingAdmin = _newAdmin;
        adminTransferTimestamp = block.timestamp;
        emit AdminTransferInitiated(admin, _newAdmin);
    }

    function acceptAdminTransfer() external {
        require(msg.sender == pendingAdmin, "Not pending admin");
        require(block.timestamp >= adminTransferTimestamp + TIMELOCK_DELAY, "Timelock active");
        address prev = admin;
        admin = pendingAdmin;
        pendingAdmin = address(0);
        adminTransferTimestamp = 0;
        emit AdminTransferCompleted(prev, admin);
    }

    // =========================================================================
    // [F-14] CIRCUIT BREAKER
    // =========================================================================

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    // =========================================================================
    // TARGET WHITELIST [F-19]
    // =========================================================================

    function setAllowedTarget(address target, bool allowed) external onlyAdmin {
        require(target != address(0), "Invalid target");
        allowedTargets[target] = allowed;
        emit TargetAllowed(target, allowed);
    }

    // =========================================================================
    // VOTER REGISTRATION & DELEGATION
    // =========================================================================

    function registerAsVoter() external {
        require(!voters[msg.sender].isRegisteredVoter, "Already registered");
        require(dgov.balanceOf(msg.sender) > 0 || msg.sender == dgov.founder(), "Must hold DGOV");

        voters[msg.sender] = VoterInfo(true, true, block.timestamp, block.timestamp, address(0));
        totalRegisteredVoters++;
        totalActiveVoters++;
        emit VoterRegistered(msg.sender);
    }

    function setDelegate(address _delegate) external {
        VoterInfo storage v = voters[msg.sender];
        require(v.isRegisteredVoter && v.isActive, "Not active voter");
        require(_delegate != msg.sender && _delegate != address(0), "Invalid delegate");
        require(voters[_delegate].isRegisteredVoter, "Delegate not registered");
        require(voters[_delegate].delegate == address(0), "Delegate is a delegator");

        if (v.delegate != address(0)) {
            _removeDelegator(v.delegate, msg.sender);
        }
        v.delegate = _delegate;
        require(delegators[_delegate].length < MAX_DELEGATORS_PER_DELEGATE, "Max delegators reached"); // [F-21]
        delegators[_delegate].push(msg.sender);
        emit DelegateSet(msg.sender, _delegate);
    }

    function removeDelegate() external {
        address prev = voters[msg.sender].delegate;
        require(prev != address(0), "No delegate");
        _removeDelegator(prev, msg.sender);
        voters[msg.sender].delegate = address(0);
        emit DelegateRemoved(msg.sender, prev);
    }

    function reactivateVoter() external {
        VoterInfo storage v = voters[msg.sender];
        require(v.isRegisteredVoter && !v.isActive, "Cannot reactivate");
        require(dgov.balanceOf(msg.sender) > 0 || msg.sender == dgov.founder(), "Must hold DGOV");
        v.isActive = true;
        v.lastVoteTimestamp = block.timestamp;
        totalActiveVoters++;
        emit VoterReactivated(msg.sender);
    }

    function deactivateInactiveVoter(address voter) external {
        VoterInfo storage v = voters[voter];
        require(v.isRegisteredVoter && v.isActive, "Not active voter");
        require(block.timestamp >= v.lastVoteTimestamp + VOTER_INACTIVITY_PERIOD, "Still active");
        v.isActive = false;
        totalActiveVoters--;
        emit VoterDeactivated(voter);
    }

    function _removeDelegator(address _delegate, address _delegator) internal {
        address[] storage list = delegators[_delegate];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == _delegator) {
                list[i] = list[list.length - 1];
                list.pop();
                return;
            }
        }
    }

    // =========================================================================
    // PROPOSALS
    // =========================================================================

    function getProposalThreshold() public view returns (uint256) {
        return (dgov.getTotalEmitted() * PROPOSAL_THRESHOLD_BPS) / BPS_DENOMINATOR;
    }

    function getQuorum(uint256 snap) public pure returns (uint256) {
        return (snap * QUORUM_BPS) / BPS_DENOMINATOR;
    }

    function recordBalanceSnapshot(uint256 pid) external {
        require(proposalCores[pid].proposer != address(0), "No proposal");
        require(!balanceSnapshots[pid][msg.sender].recorded, "Already recorded");
        balanceSnapshots[pid][msg.sender] = BalanceSnapshot(
            dgov.balanceOf(msg.sender), dgov.getVestingWeight(msg.sender), true
        );
    }

    function createProposal(
        string calldata title,
        string calldata description,
        uint8 proposalType,
        bytes calldata executionData,
        address executionTarget
    ) external whenNotPaused returns (uint256) {
        _validateProposer(msg.sender, proposalType, title, description);

        proposalCount++;
        uint256 pid = proposalCount;
        uint256 snap = dgov.getTotalEmitted();

        proposalCores[pid] = ProposalCore(
            msg.sender, block.timestamp, block.timestamp + PROPOSAL_DURATION,
            0, snap, proposalType, false
        );
        proposalTitles[pid] = title;
        proposalDescriptions[pid] = description;
        proposalExecutions[pid] = ProposalExecution(executionTarget, executionData);

        // Auto-snapshot for proposer
        balanceSnapshots[pid][msg.sender] = BalanceSnapshot(
            dgov.balanceOf(msg.sender), dgov.getVestingWeight(msg.sender), true
        );

        emit ProposalCreated(pid, msg.sender, proposalType, snap);
        return pid;
    }

    function _validateProposer(address proposer, uint8 pType, string calldata t, string calldata d) internal view {
        require(voters[proposer].isRegisteredVoter && voters[proposer].isActive, "Not active voter");
        uint256 w = dgov.balanceOf(proposer) + dgov.getVestingWeight(proposer);
        require(w >= getProposalThreshold(), "Below threshold");
        require(pType <= 3, "Invalid type");
        require(bytes(t).length > 0 && bytes(t).length <= 200, "Bad title");
        require(bytes(d).length > 0 && bytes(d).length <= 5000, "Bad desc");
    }

    function castVote(uint256 pid, uint8 support) external whenNotPaused {
        ProposalCore storage c = proposalCores[pid];
        require(c.proposer != address(0), "No proposal");
        require(block.timestamp >= c.startTime && block.timestamp < c.endTime, "Not voting period");
        require(!hasVotedOnProposal[pid][msg.sender], "Already voted");
        require(support <= 2, "Invalid vote");

        VoterInfo storage v = voters[msg.sender];
        require(v.isRegisteredVoter && v.isActive, "Not active voter");
        require(v.delegate == address(0), "Delegated, cannot vote");

        _autoSnapshot(pid, msg.sender);

        uint256 weight = getVotingPower(pid, msg.sender);
        require(weight > 0, "No voting power");

        hasVotedOnProposal[pid][msg.sender] = true;
        _markDelegatorsVoted(pid, msg.sender);
        v.lastVoteTimestamp = block.timestamp;

        ProposalVotes storage pv = proposalVotes[pid];
        if (support == 0) pv.againstVotes += weight;
        else if (support == 1) pv.forVotes += weight;
        else pv.abstainVotes += weight;

        emit VoteCast(pid, msg.sender, support, weight);
    }

    function _autoSnapshot(uint256 pid, address voter) internal {
        if (!balanceSnapshots[pid][voter].recorded) {
            balanceSnapshots[pid][voter] = BalanceSnapshot(
                dgov.balanceOf(voter), dgov.getVestingWeight(voter), true
            );
        }
    }

    function _markDelegatorsVoted(uint256 pid, address voter) internal {
        address[] storage dl = delegators[voter];
        for (uint256 i = 0; i < dl.length; i++) {
            if (voters[dl[i]].isActive && voters[dl[i]].delegate == voter) {
                hasVotedOnProposal[pid][dl[i]] = true;
            }
        }
    }

    function queueProposal(uint256 pid) external {
        ProposalCore storage c = proposalCores[pid];
        require(c.proposer != address(0) && !c.executed && c.timelockEnd == 0, "Cannot queue");
        require(block.timestamp >= c.endTime, "Voting not ended");

        ProposalVotes storage pv = proposalVotes[pid];
        uint256 total = pv.forVotes + pv.againstVotes + pv.abstainVotes;
        require(total >= getQuorum(c.snapshotTotalEmitted), "No quorum");
        require(pv.forVotes > pv.againstVotes, "Not passed");

        c.timelockEnd = block.timestamp + TIMELOCK_DELAY;
        emit ProposalQueued(pid, c.timelockEnd);
    }

    function executeProposal(uint256 pid) external nonReentrant whenNotPaused {
        ProposalCore storage c = proposalCores[pid];
        require(!c.executed && c.timelockEnd > 0, "Cannot execute");
        require(block.timestamp >= c.timelockEnd, "Timelock active");
        require(block.timestamp <= c.timelockEnd + EXECUTION_DEADLINE, "Execution deadline expired"); // [F-23]

        c.executed = true;
        ProposalExecution storage ex = proposalExecutions[pid];
        if (ex.data.length > 0 && ex.target != address(0)) {
            require(allowedTargets[ex.target], "Target not in whitelist"); // [F-19]
            (bool ok, ) = ex.target.call(ex.data);
            require(ok, "Execution failed");
        }
        emit ProposalExecuted(pid);
    }

    // [F-24] Cancel proposal — by proposer (before voting ends) or by admin (emergency)
    function cancelProposal(uint256 pid) external {
        ProposalCore storage c = proposalCores[pid];
        require(c.proposer != address(0) && !c.executed, "Cannot cancel");
        require(
            (msg.sender == c.proposer && block.timestamp < c.endTime) ||
            msg.sender == admin,
            "Not authorized to cancel"
        );
        c.executed = true; // Mark as executed to prevent further actions
        emit ProposalCancelled(pid, msg.sender);
    }

    // =========================================================================
    // VOTING POWER
    // =========================================================================

    function getVotingPower(uint256 pid, address voter) public view returns (uint256) {
        uint256 own = _snapWeight(pid, voter);
        uint256 del = 0;
        address[] storage dl = delegators[voter];
        for (uint256 i = 0; i < dl.length; i++) {
            if (voters[dl[i]].isActive && voters[dl[i]].delegate == voter) {
                del += _snapWeight(pid, dl[i]);
            }
        }
        return own + del;
    }

    function _snapWeight(uint256 pid, address h) internal view returns (uint256) {
        BalanceSnapshot storage s = balanceSnapshots[pid][h];
        if (s.recorded) return s.balance + s.vestingWeight;
        return dgov.balanceOf(h) + dgov.getVestingWeight(h);
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    function getProposalContent(uint256 pid) external view returns (
        string memory title, string memory description, address proposer
    ) {
        return (proposalTitles[pid], proposalDescriptions[pid], proposalCores[pid].proposer);
    }

    function getProposalVotesInfo(uint256 pid) external view returns (
        uint256 forV, uint256 againstV, uint256 abstainV
    ) {
        ProposalVotes storage pv = proposalVotes[pid];
        return (pv.forVotes, pv.againstVotes, pv.abstainVotes);
    }

    function getProposalTiming(uint256 pid) external view returns (
        uint256 startTime, uint256 endTime, bool executed, uint8 pType
    ) {
        ProposalCore storage c = proposalCores[pid];
        return (c.startTime, c.endTime, c.executed, c.proposalType);
    }

    function getProposalTimelockInfo(uint256 pid) external view returns (
        uint256 timelockEnd, uint256 snapshotTotalEmitted
    ) {
        ProposalCore storage c = proposalCores[pid];
        return (c.timelockEnd, c.snapshotTotalEmitted);
    }

    function getProposalQuorumStatus(uint256 pid) external view returns (
        uint256 quorumRequired, uint256 totalVotesCount, bool quorumReached, bool passed
    ) {
        ProposalCore storage c = proposalCores[pid];
        ProposalVotes storage pv = proposalVotes[pid];
        quorumRequired = getQuorum(c.snapshotTotalEmitted);
        totalVotesCount = pv.forVotes + pv.againstVotes + pv.abstainVotes;
        quorumReached = totalVotesCount >= quorumRequired;
        passed = pv.forVotes > pv.againstVotes;
    }

    function isProposalActive(uint256 pid) external view returns (bool) {
        ProposalCore storage c = proposalCores[pid];
        return (block.timestamp >= c.startTime && block.timestamp < c.endTime && !c.executed);
    }

    function isProposalExecutable(uint256 pid) external view returns (bool) {
        ProposalCore storage c = proposalCores[pid];
        return (c.timelockEnd > 0 && block.timestamp >= c.timelockEnd && !c.executed);
    }

    function hasVoted(uint256 pid, address voter) external view returns (bool) {
        return hasVotedOnProposal[pid][voter];
    }

    function getVoterInfo(address voter) external view returns (
        bool isReg, bool isAct, uint256 lastVote, address del
    ) {
        VoterInfo storage v = voters[voter];
        return (v.isRegisteredVoter, v.isActive, v.lastVoteTimestamp, v.delegate);
    }

    function getVoterDelegationInfo(address voter) external view returns (
        uint256 regTime, uint256 delCount
    ) {
        return (voters[voter].registrationTime, delegators[voter].length);
    }

    function getDelegators(address voter) external view returns (address[] memory) {
        return delegators[voter];
    }

    function getGovernanceStats() external view returns (
        uint256 emitted, uint256 threshold, uint256 quorum
    ) {
        uint256 e = dgov.getTotalEmitted();
        return (e, getProposalThreshold(), getQuorum(e));
    }

    function getGovernanceVoterStats() external view returns (
        uint256 regVoters, uint256 actVoters, uint256 propCount
    ) {
        return (totalRegisteredVoters, totalActiveVoters, proposalCount);
    }
}
