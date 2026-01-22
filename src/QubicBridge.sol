// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./QubicToken.sol";

contract QubicBridge is
    AccessControlEnumerable,
    ReentrancyGuardTransient,
    Pausable
{
    /**
     * @notice State
     */
    uint256 public baseFee;
    uint256 public minTransferAmount;
    uint256 public maxTransferAmount;

    /// @notice Outgoing orders generated from this contract
    struct PullOrder {
        address originAccount;
        string destinationAccount;
        uint248 amount;
        bool done;
    }

    mapping(uint256 => PullOrder) pullOrders;
    uint256 lastPullOrderId;

    /// @notice Incoming orders generated from the origin network
    mapping(uint256 => bool) pushOrders;

    /**
     * @notice Multisig State
     */
    /// @notice Proposal structure for multisig actions
    struct Proposal {
        bytes32 proposalId;
        address proposer;
        bytes data;
        uint256 approvalCount;
        bool executed;
        uint256 createdAt;
        bytes32 roleRequired; // ADMIN or MANAGER role
        mapping(address => bool) hasApproved;
    }

    /// @notice Multisig configuration
    uint256 public adminThreshold; // Number of admin approvals required
    uint256 public managerThreshold; // Number of manager approvals required

    /// @notice Mapping of proposal ID to Proposal
    mapping(bytes32 => Proposal) public proposals;

    /// @notice Array of pending proposal IDs for enumeration
    bytes32[] public pendingProposals;

    /**
     * @notice Constants
     */
    address public immutable token;
    address public feeRecipient; // Wallet that receives all bridge fees
    bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint8 constant QUBIC_ACCOUNT_LENGTH = 60;
    uint8 constant MAX_ADMINS = 3;
    uint8 constant MAX_MANAGERS = 3;

    /**
     * @notice Mapping of function selectors to required roles
     * This prevents privilege escalation by enforcing correct role for each function
     */
    mapping(bytes4 => bytes32) public functionRoles;

    /**
     * @notice Tracks which selectors are registered to distinguish from default bytes32(0)
     */
    mapping(bytes4 => bool) public isFunctionRegistered;

    /**
     * @notice Events
     */
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event ManagerAdded(address indexed manager);
    event ManagerRemoved(address indexed manager);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event BaseFeeUpdated(uint256 baseFee);
    event FeeRecipientUpdated(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event MinTransferAmountUpdated(uint256 minAmount);
    event MaxTransferAmountUpdated(uint256 maxAmount);
    event OrderCreated(
        uint256 indexed orderId,
        address indexed originAccount,
        string indexed destinationAccount,
        uint256 amount
    );
    event OrderConfirmed(
        uint256 indexed orderId,
        address indexed originAccount,
        string indexed destinationAccount,
        uint256 amount
    );
    event OrderReverted(
        uint256 indexed orderId,
        address indexed originAccount,
        string indexed destinationAccount,
        uint256 amount
    );
    event OrderExecuted(
        uint256 indexed originOrderId,
        string indexed originAccount,
        address indexed destinationAccount,
        uint256 amount
    );
    event EmergencyTokenWithdrawn(
        address tokenAddress,
        address to,
        uint256 amount
    );
    event EmergencyEtherWithdrawn(address to, uint256 amount);

    /**
     * @notice Multisig Events
     */
    event ProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposer,
        bytes data,
        bytes32 roleRequired
    );
    event ProposalApproved(
        bytes32 indexed proposalId,
        address indexed approver,
        uint256 approvalCount
    );
    event ProposalExecuted(
        bytes32 indexed proposalId,
        address indexed executor
    );
    event ProposalCancelled(
        bytes32 indexed proposalId,
        address indexed canceller
    );
    event AdminThresholdUpdated(uint256 newThreshold);
    event ManagerThresholdUpdated(uint256 newThreshold);

    /**
     * @notice Custom Errors
     */
    error InvalidAddress();
    error InvalidBaseFee();
    error InvalidDestinationAccount();
    error InvalidAmount();
    error AmountBelowMinimum();
    error AmountExceedsMaximum();
    error InvalidFeePct();
    error InvalidOrderId();
    error InsufficientApproval();
    error AlreadyConfirmed();
    error AlreadyExecuted();
    error TokenTransferFailed();
    error EtherTransferFailed();

    /**
     * @notice Multisig Errors
     */
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalAlreadyApproved();
    error InsufficientApprovals();
    error InvalidThreshold();
    error UnauthorizedRole();
    error OnlyProposal();
    error MaxAdminsReached();
    error MaxManagersReached();
    error ThresholdExceedsCount();
    error AlreadyAdmin();
    error AlreadyManager();
    error AlreadyOperator();
    error MustBePaused();
    error ProposalAlreadyExists();
    error FeeExceedsAmount();

    /**
     * @notice Internal helper to register function selector to role mapping
     */
    function _registerFunction(string memory signature, bytes32 role) internal {
        bytes4 selector = bytes4(keccak256(bytes(signature)));
        functionRoles[selector] = role;
        isFunctionRegistered[selector] = true;
    }

    /**
     * @notice Initialize all function role mappings
     */
    function _initializeFunctionRoles() internal {
        // Admin functions (DEFAULT_ADMIN_ROLE = bytes32(0))
        _registerFunction("addAdmin(address)", DEFAULT_ADMIN_ROLE);
        _registerFunction("removeAdmin(address)", DEFAULT_ADMIN_ROLE);
        _registerFunction("addManager(address)", DEFAULT_ADMIN_ROLE);
        _registerFunction("removeManager(address)", DEFAULT_ADMIN_ROLE);
        _registerFunction("setBaseFee(uint256)", DEFAULT_ADMIN_ROLE);
        _registerFunction("setFeeRecipient(address)", DEFAULT_ADMIN_ROLE);
        _registerFunction("emergencyPause()", DEFAULT_ADMIN_ROLE);
        _registerFunction("emergencyUnpause()", DEFAULT_ADMIN_ROLE);
        _registerFunction(
            "emergencyTokenWithdraw(address,address,uint256)",
            DEFAULT_ADMIN_ROLE
        );
        _registerFunction(
            "emergencyEtherWithdraw(address)",
            DEFAULT_ADMIN_ROLE
        );
        _registerFunction("setAdminThreshold(uint256)", DEFAULT_ADMIN_ROLE);
        _registerFunction("setManagerThreshold(uint256)", DEFAULT_ADMIN_ROLE);

        // Manager functions
        _registerFunction("addOperator(address)", MANAGER_ROLE);
        _registerFunction("removeOperator(address)", MANAGER_ROLE);
        _registerFunction("setMinTransferAmount(uint256)", DEFAULT_ADMIN_ROLE);
        _registerFunction("setMaxTransferAmount(uint256)", DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Modifiers
     */
    /// @notice Ensures function can only be called via executeProposal
    modifier onlyProposal() {
        if (msg.sender != address(this)) {
            revert OnlyProposal();
        }
        _;
    }

    /**
     * @notice Constructor
     * @param _token Address of the bridge token
     * @param _baseFee Base fee (2 decimal places)
     * @param _admins Array of initial admin addresses (max 3)
     * @param _adminThreshold Number of admin approvals required for admin actions
     * @param _managerThreshold Number of manager approvals required for manager actions
     * @param _feeRecipient Address that receives all bridge fees
     * @param _minTransferAmount Minimum transfer amount (0 = no minimum)
     * @param _maxTransferAmount Maximum transfer amount (0 = no maximum)
     */
    constructor(
        address _token,
        uint256 _baseFee,
        address[] memory _admins,
        uint256 _adminThreshold,
        uint256 _managerThreshold,
        address _feeRecipient,
        uint256 _minTransferAmount,
        uint256 _maxTransferAmount
    ) {
        if (_admins.length == 0 || _admins.length > MAX_ADMINS) {
            revert InvalidThreshold();
        }
        if (_adminThreshold == 0 || _adminThreshold > _admins.length) {
            revert InvalidThreshold();
        }
        if (_managerThreshold == 0 || _managerThreshold > MAX_MANAGERS) {
            revert InvalidThreshold();
        }
        if (_feeRecipient == address(0)) {
            revert InvalidAddress();
        }

        token = _token;
        baseFee = _baseFee;
        adminThreshold = _adminThreshold;
        managerThreshold = _managerThreshold;
        feeRecipient = _feeRecipient;
        minTransferAmount = _minTransferAmount;
        maxTransferAmount = _maxTransferAmount;

        // Grant admin role to all initial admins
        for (uint256 i = 0; i < _admins.length; i++) {
            if (_admins[i] == address(0)) {
                revert InvalidAddress();
            }
            _grantRole(DEFAULT_ADMIN_ROLE, _admins[i]);
        }

        // Initialize function selector to role mapping
        _initializeFunctionRoles();
    }

    /**
     * @notice Adds a new admin (max 3 admins)
     * @param newAdmin Address of the new admin
     * @return True if the role was granted, false otherwise
     */
    function addAdmin(address newAdmin) external onlyProposal returns (bool) {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
        if (hasRole(DEFAULT_ADMIN_ROLE, newAdmin)) {
            revert AlreadyAdmin();
        }

        // Count current admins (excluding contract itself)
        uint256 adminCount = 0;
        uint256 memberCount = getRoleMemberCount(DEFAULT_ADMIN_ROLE);
        for (uint256 i = 0; i < memberCount; i++) {
            address member = getRoleMember(DEFAULT_ADMIN_ROLE, i);
            if (member != address(this)) {
                adminCount++;
            }
        }

        if (adminCount >= MAX_ADMINS) {
            revert MaxAdminsReached();
        }

        bool success = _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        emit AdminAdded(newAdmin);
        return success;
    }

    /**
     * @notice Removes an admin
     * @param admin Address of the admin to remove
     * @return True if the role was revoked, false otherwise
     */
    function removeAdmin(address admin) external onlyProposal returns (bool) {
        if (admin == address(this)) {
            revert InvalidAddress();
        }

        // Count current admins (excluding contract itself)
        uint256 adminCount = 0;
        uint256 memberCount = getRoleMemberCount(DEFAULT_ADMIN_ROLE);
        for (uint256 i = 0; i < memberCount; i++) {
            address member = getRoleMember(DEFAULT_ADMIN_ROLE, i);
            if (member != address(this)) {
                adminCount++;
            }
        }

        // Prevent removal if it would leave fewer admins than threshold
        if (adminCount - 1 < adminThreshold) {
            revert ThresholdExceedsCount();
        }

        bool success = _revokeRole(DEFAULT_ADMIN_ROLE, admin);
        emit AdminRemoved(admin);
        return success;
    }

    /**
     * @notice Adds a new manager
     * @param newManager Address of the new manager
     * @return True if the role was granted, false otherwise
     */
    function addManager(
        address newManager
    ) external onlyProposal returns (bool) {
        if (newManager == address(0)) {
            revert InvalidAddress();
        }
        if (hasRole(MANAGER_ROLE, newManager)) {
            revert AlreadyManager();
        }

        // Count current managers (excluding contract itself)
        uint256 managerCount = 0;
        uint256 memberCount = getRoleMemberCount(MANAGER_ROLE);
        for (uint256 i = 0; i < memberCount; i++) {
            address member = getRoleMember(MANAGER_ROLE, i);
            if (member != address(this)) {
                managerCount++;
            }
        }

        if (managerCount >= MAX_MANAGERS) {
            revert MaxManagersReached();
        }

        bool success = _grantRole(MANAGER_ROLE, newManager);
        emit ManagerAdded(newManager);
        return success;
    }

    /**
     * @notice Removes a manager
     * @param manager Address of the manager to remove
     * @return True if the role was revoked, false otherwise
     */
    function removeManager(
        address manager
    ) external onlyProposal returns (bool) {
        // Count current managers (excluding contract itself)
        uint256 managerCount = 0;
        uint256 memberCount = getRoleMemberCount(MANAGER_ROLE);
        for (uint256 i = 0; i < memberCount; i++) {
            address member = getRoleMember(MANAGER_ROLE, i);
            if (member != address(this)) {
                managerCount++;
            }
        }

        // Prevent removal if it would leave fewer managers than threshold
        if (managerCount - 1 < managerThreshold) {
            revert ThresholdExceedsCount();
        }

        bool success = _revokeRole(MANAGER_ROLE, manager);
        emit ManagerRemoved(manager);
        return success;
    }

    /**
     * @notice Adds a new operator
     * @param newOperator Address of the new operator
     * @return True if the role was granted, false otherwise
     */
    function addOperator(
        address newOperator
    ) external onlyProposal returns (bool) {
        if (newOperator == address(0)) {
            revert InvalidAddress();
        }
        if (hasRole(OPERATOR_ROLE, newOperator)) {
            revert AlreadyOperator();
        }
        bool success = _grantRole(OPERATOR_ROLE, newOperator);
        emit OperatorAdded(newOperator);
        return success;
    }

    /**
     * @notice Removes an operator
     * @param operator Address of the operator to remove
     * @return True if the role was revoked, false otherwise
     */
    function removeOperator(
        address operator
    ) external onlyProposal returns (bool) {
        bool success = _revokeRole(OPERATOR_ROLE, operator);
        emit OperatorRemoved(operator);
        return success;
    }

    /**
     * @notice Sets the base fee
     * @param _baseFee Amount of the base fee (2 decimal places)
     */
    function setBaseFee(uint256 _baseFee) external onlyProposal {
        if (_baseFee > 100 * 100) {
            revert InvalidBaseFee();
        }
        baseFee = _baseFee;
        emit BaseFeeUpdated(_baseFee);
    }

    /**
     * @notice Sets the fee recipient address
     * @param newFeeRecipient Address that will receive all bridge fees
     */
    function setFeeRecipient(address newFeeRecipient) external onlyProposal {
        if (newFeeRecipient == address(0)) {
            revert InvalidAddress();
        }
        address oldRecipient = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(oldRecipient, newFeeRecipient);
    }

    /**
     * @notice Sets the minimum transfer amount
     * @param _minTransferAmount Minimum transfer amount (0 = no minimum)
     */
    function setMinTransferAmount(
        uint256 _minTransferAmount
    ) external onlyProposal {
        minTransferAmount = _minTransferAmount;
        emit MinTransferAmountUpdated(_minTransferAmount);
    }

    /**
     * @notice Sets the maximum transfer amount
     * @param _maxTransferAmount Maximum transfer amount (0 = no maximum)
     */
    function setMaxTransferAmount(
        uint256 _maxTransferAmount
    ) external onlyProposal {
        maxTransferAmount = _maxTransferAmount;
        emit MaxTransferAmountUpdated(_maxTransferAmount);
    }

    /**
     * @notice Called by the user to initiate a transfer-out order
     * @param destinationAccount Destination account in Qubic network
     * @param amount Amount of QUBIC to send
     * @param bypassDestinationAccountCheck Whether to bypass the Qubic address check (gas-expensive)
     */
    function createOrder(
        string calldata destinationAccount,
        uint256 amount,
        bool bypassDestinationAccountCheck
    ) external whenNotPaused {
        if (
            !bypassDestinationAccountCheck &&
            !isQubicAddress(destinationAccount)
        ) {
            revert InvalidDestinationAccount();
        }
        if (QubicToken(token).allowance(msg.sender, address(this)) < amount) {
            revert InsufficientApproval();
        }
        if (amount == 0 || amount > type(uint248).max) {
            revert InvalidAmount();
        }
        if (minTransferAmount > 0 && amount < minTransferAmount) {
            revert AmountBelowMinimum();
        }
        if (maxTransferAmount > 0 && amount > maxTransferAmount) {
            revert AmountExceedsMaximum();
        }

        address originAccount = msg.sender;

        // order Ids begin at 1
        uint256 orderId = ++lastPullOrderId;

        pullOrders[orderId] = PullOrder(
            originAccount,
            destinationAccount,
            uint248(amount),
            false
        );

        QubicToken(token).transferFrom(originAccount, address(this), amount);

        emit OrderCreated(orderId, originAccount, destinationAccount, amount);
    }

    /**
     * @notice Called by the operator backend to confirm a transfer-out order
     * @param orderId Order ID
     * @param feePct Percentage of the baseFee to apply (no decimal places)
     */
    function confirmOrder(
        uint256 orderId,
        uint256 feePct
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        PullOrder memory order = pullOrders[orderId];
        uint256 amount = uint256(order.amount);

        if (amount == 0) {
            revert InvalidOrderId();
        }
        if (order.done) {
            revert AlreadyConfirmed();
        }
        if (feePct > 100) {
            revert InvalidFeePct();
        }

        uint256 fee = getTransferFee(amount, feePct);
        if (fee >= amount) {
            revert FeeExceedsAmount();
        }
        uint256 amountAfterFee = amount - fee;

        // Mark the order done
        pullOrders[orderId].done = true;

        // Transfer the fee to the configured recipient
        if (fee > 0) {
            QubicToken(token).transfer(feeRecipient, fee);
        }

        // Burn the amount after fee
        QubicToken(token).burn(amountAfterFee);

        emit OrderConfirmed(
            orderId,
            order.originAccount,
            order.destinationAccount,
            amount
        );
    }

    /**
     * @notice Called by the operator backend to revert a transfer-out order
     * @param orderId Order ID
     * @param feePct Percentage of the baseFee to apply (no decimal places)
     */
    function revertOrder(
        uint256 orderId,
        uint256 feePct
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        PullOrder memory order = pullOrders[orderId];
        uint256 amount = uint256(order.amount);

        if (amount == 0) {
            revert InvalidOrderId();
        }
        if (order.done) {
            revert AlreadyConfirmed();
        }
        if (feePct > 100) {
            revert InvalidFeePct();
        }

        // Delete the order
        delete pullOrders[orderId];

        uint256 fee = getTransferFee(amount, feePct);
        if (fee >= amount) {
            revert FeeExceedsAmount();
        }
        uint256 amountAfterFee = amount - fee;

        // Transfer the fee to the configured recipient
        if (fee > 0) {
            QubicToken(token).transfer(feeRecipient, fee);
        }

        // Transfer the amount to the origin account
        QubicToken(token).transfer(order.originAccount, amountAfterFee);

        emit OrderReverted(
            orderId,
            order.originAccount,
            order.destinationAccount,
            amount
        );
    }

    /**
     * @notice Called by the operator backend to execute a transfer-in order initiated in the origin network
     * @param originOrderId Order ID in the origin network
     * @param originAccount Origin account in the origin network
     * @param destinationAccount Destination account in this network
     * @param amount Amount of QUBIC to send
     * @param feePct Percentage of the baseFee to apply (no decimal places)
     */
    function executeOrder(
        uint256 originOrderId,
        string calldata originAccount,
        address destinationAccount,
        uint256 amount,
        uint256 feePct
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        if (destinationAccount == address(0)) {
            revert InvalidDestinationAccount();
        }
        if (feePct > 100) {
            revert InvalidFeePct();
        }
        if (pushOrders[originOrderId]) {
            revert AlreadyExecuted();
        }

        if (minTransferAmount > 0 && amount < minTransferAmount) {
            revert AmountBelowMinimum();
        }
        if (maxTransferAmount > 0 && amount > maxTransferAmount) {
            revert AmountExceedsMaximum();
        }

        uint256 fee = getTransferFee(amount, feePct);
        if (fee >= amount) {
            revert FeeExceedsAmount();
        }
        uint256 amountAfterFee = amount - fee;

        // Mark the order as executed
        pushOrders[originOrderId] = true;

        // Mint the fee to the configured recipient
        if (fee > 0) {
            QubicToken(token).mint(feeRecipient, fee);
        }

        // Mint the amount to the destination account
        QubicToken(token).mint(destinationAccount, amountAfterFee);

        emit OrderExecuted(
            originOrderId,
            originAccount,
            destinationAccount,
            amount
        );
    }

    /**
     * @notice Emergency pause function - CENTRALIZATION RISK
     * @dev AUDIT NOTE (KS–VB–F–04): This function creates centralization risk as admin
     *      can unilaterally pause the entire bridge. This is an intentional design decision
     *      for emergency response capabilities. Recommended mitigations:
     *      - Use multi-signature wallet for admin role
     *      - Implement timelock for critical operations
     *      - Consider governance mechanisms for pause decisions
     */
    function emergencyPause() external onlyProposal {
        _pause();
    }

    /**
     * @notice Emergency unpause function - CENTRALIZATION RISK
     * @dev AUDIT NOTE (KS–VB–F–04): Admin can unilaterally unpause the bridge
     */
    function emergencyUnpause() external onlyProposal {
        _unpause();
    }

    /**
     * @notice Called by the admin to withdraw tokens in case of emergency - CENTRALIZATION RISK
     * @dev AUDIT NOTE (KS–VB–F–04): This function creates significant centralization risk
     *      as admin can withdraw ALL tokens from the contract at any time. This introduces
     *      custodial risk and makes the contract non-trustless. Users must trust that the
     *      admin will not abuse this power. Recommended mitigations:
     *      - Use multi-signature wallet for admin role
     *      - Implement transparent governance processes
     *      - Consider timelock mechanisms for withdrawals
     *      - Regular security audits of privileged accounts
     * @param tokenAddress Address of the token to withdraw
     * @param recipient Address to receive the withdrawn tokens
     * @param amount Amount of tokens to withdraw
     */
    function emergencyTokenWithdraw(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external onlyProposal {
        if (!paused()) {
            revert MustBePaused();
        }
        if (recipient == address(0)) {
            revert InvalidAddress();
        }

        (bool success, ) = tokenAddress.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                recipient,
                amount
            )
        );

        if (!success) {
            revert TokenTransferFailed();
        }

        emit EmergencyTokenWithdrawn(tokenAddress, recipient, amount);
    }

    /**
     * @notice Called by the admin to withdraw all Ether in case of emergency - CENTRALIZATION RISK
     * @dev AUDIT NOTE (KS–VB–F–04): Admin can withdraw ALL Ether from the contract.
     *      Same centralization risks apply as with emergencyTokenWithdraw.
     * @param recipient Address to receive the withdrawn Ether
     */
    function emergencyEtherWithdraw(address recipient) external onlyProposal {
        if (!paused()) {
            revert MustBePaused();
        }
        if (recipient == address(0)) {
            revert InvalidAddress();
        }

        uint256 amount = address(this).balance;
        (bool success, ) = recipient.call{value: amount}("");

        if (!success) {
            revert EtherTransferFailed();
        }

        emit EmergencyEtherWithdrawn(recipient, amount);
    }

    /**
     * @notice MULTISIG FUNCTIONS
     */

    /**
     * @notice Creates a proposal for an admin or manager action
     * @param data The encoded function call data
     * @param roleRequired The role required to approve (DEFAULT_ADMIN_ROLE or MANAGER_ROLE)
     * @return proposalId The ID of the created proposal
     */
    function proposeAction(
        bytes calldata data,
        bytes32 roleRequired
    ) external returns (bytes32) {
        // Verify caller has the required role
        if (!hasRole(roleRequired, msg.sender)) {
            revert UnauthorizedRole();
        }

        // Verify roleRequired is valid
        if (
            roleRequired != DEFAULT_ADMIN_ROLE && roleRequired != MANAGER_ROLE
        ) {
            revert UnauthorizedRole();
        }

        // Extract function selector from data
        if (data.length < 4) {
            revert InvalidAddress(); // Reusing error for invalid data
        }
        bytes4 selector = bytes4(data[:4]);

        // Verify the function is registered and matches the required role
        if (!isFunctionRegistered[selector]) {
            revert UnauthorizedRole(); // Function not registered
        }
        bytes32 expectedRole = functionRoles[selector];
        if (expectedRole != roleRequired) {
            revert UnauthorizedRole(); // Role mismatch
        }

        // Generate proposal ID
        bytes32 proposalId = keccak256(
            abi.encodePacked(data, block.timestamp, msg.sender, block.number)
        );

        // Check if proposal already exists
        if (proposals[proposalId].proposer != address(0)) {
            revert ProposalAlreadyExists();
        }

        // Initialize proposal
        Proposal storage proposal = proposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposer = msg.sender;
        proposal.data = data;
        proposal.approvalCount = 0;
        proposal.executed = false;
        proposal.createdAt = block.timestamp;
        proposal.roleRequired = roleRequired;

        // Add to pending proposals
        pendingProposals.push(proposalId);

        emit ProposalCreated(proposalId, msg.sender, data, roleRequired);

        return proposalId;
    }

    /**
     * @notice Approves a pending proposal
     * @param proposalId The ID of the proposal to approve
     */
    function approveProposal(bytes32 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Verify proposal exists
        if (proposal.proposer == address(0)) {
            revert ProposalNotFound();
        }

        // Verify not already executed
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Verify caller has required role
        if (!hasRole(proposal.roleRequired, msg.sender)) {
            revert UnauthorizedRole();
        }

        // Verify not already approved by this address
        if (proposal.hasApproved[msg.sender]) {
            revert ProposalAlreadyApproved();
        }

        // Record approval
        proposal.hasApproved[msg.sender] = true;
        proposal.approvalCount++;

        emit ProposalApproved(proposalId, msg.sender, proposal.approvalCount);
    }

    /**
     * @notice Executes a proposal if it has enough approvals
     * @param proposalId The ID of the proposal to execute
     */
    function executeProposal(bytes32 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        // Verify proposal exists
        if (proposal.proposer == address(0)) {
            revert ProposalNotFound();
        }

        // Verify not already executed
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Check threshold (anyone can execute if threshold is met)
        uint256 threshold = proposal.roleRequired == DEFAULT_ADMIN_ROLE
            ? adminThreshold
            : managerThreshold;
        if (proposal.approvalCount < threshold) {
            revert InsufficientApprovals();
        }

        // Mark as executed
        proposal.executed = true;

        // Remove from pending proposals
        _removePendingProposal(proposalId);

        // Execute the proposal
        (bool success, ) = address(this).call(proposal.data);
        if (!success) {
            revert("Proposal execution failed");
        }

        emit ProposalExecuted(proposalId, msg.sender);
    }

    /**
     * @notice Cancels a pending proposal (only proposer can cancel)
     * @param proposalId The ID of the proposal to cancel
     */
    function cancelProposal(bytes32 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Verify proposal exists
        if (proposal.proposer == address(0)) {
            revert ProposalNotFound();
        }

        // Verify not already executed
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Only proposer or admin can cancel
        if (
            msg.sender != proposal.proposer &&
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) {
            revert UnauthorizedRole();
        }

        // Mark as executed (cancelled)
        proposal.executed = true;

        // Remove from pending proposals
        _removePendingProposal(proposalId);

        emit ProposalCancelled(proposalId, msg.sender);
    }

    /**
     * @notice Updates the admin threshold
     * @param newThreshold New threshold value
     */
    function setAdminThreshold(uint256 newThreshold) external onlyProposal {
        if (newThreshold == 0) {
            revert InvalidThreshold();
        }

        // Count current admins (excluding contract itself)
        uint256 adminCount = 0;
        uint256 memberCount = getRoleMemberCount(DEFAULT_ADMIN_ROLE);
        for (uint256 i = 0; i < memberCount; i++) {
            address member = getRoleMember(DEFAULT_ADMIN_ROLE, i);
            if (member != address(this)) {
                adminCount++;
            }
        }

        if (newThreshold > adminCount || newThreshold > MAX_ADMINS) {
            revert ThresholdExceedsCount();
        }

        adminThreshold = newThreshold;
        emit AdminThresholdUpdated(newThreshold);
    }

    /**
     * @notice Updates the manager threshold
     * @param newThreshold New threshold value
     */
    function setManagerThreshold(uint256 newThreshold) external onlyProposal {
        if (newThreshold == 0) {
            revert InvalidThreshold();
        }

        // Count current managers (excluding contract itself)
        uint256 managerCount = 0;
        uint256 memberCount = getRoleMemberCount(MANAGER_ROLE);
        for (uint256 i = 0; i < memberCount; i++) {
            address member = getRoleMember(MANAGER_ROLE, i);
            if (member != address(this)) {
                managerCount++;
            }
        }

        if (newThreshold > managerCount || newThreshold > MAX_MANAGERS) {
            revert ThresholdExceedsCount();
        }

        managerThreshold = newThreshold;
        emit ManagerThresholdUpdated(newThreshold);
    }

    /**
     * @notice Internal function to remove a proposal from pending list
     * @param proposalId The proposal ID to remove
     */
    function _removePendingProposal(bytes32 proposalId) internal {
        for (uint256 i = 0; i < pendingProposals.length; i++) {
            if (pendingProposals[i] == proposalId) {
                pendingProposals[i] = pendingProposals[
                    pendingProposals.length - 1
                ];
                pendingProposals.pop();
                break;
            }
        }
    }

    /**
     * @notice Calculates the transfer fee with a guaranteed minimum of 1
     * @dev Rounds up so that it favors the protocol
     * @param amount Transfer amount
     * @param feePct Percentage of the baseFee to apply (no decimal places)
     * @return The calculated fee amount
     */
    function getTransferFee(
        uint256 amount,
        uint256 feePct
    ) internal view returns (uint256) {
        // baseFee decimals * feePct decimals
        uint256 DENOMINATOR = 10000 * 100;
        // calculate rounding 1 up
        return (amount * baseFee * feePct + DENOMINATOR - 1) / DENOMINATOR;
    }

    /**
     * @notice Gets a pull order
     * @param orderId Order ID
     * @return Pull order
     */
    function getOrder(
        uint256 orderId
    ) external view returns (PullOrder memory) {
        if (orderId == 0 || orderId > lastPullOrderId) {
            revert InvalidOrderId();
        }

        return pullOrders[orderId];
    }

    /**
     * @notice Gets all admins (excluding the contract itself)
     * @return Array of admin addresses
     */
    function getAdmins() external view returns (address[] memory) {
        return getRoleMembers(DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Gets the managers
     * @return Managers
     */
    function getManagers() external view returns (address[] memory) {
        return getRoleMembers(MANAGER_ROLE);
    }

    /**
     * @notice Gets the operators
     * @return Operators
     */
    function getOperators() external view returns (address[] memory) {
        return getRoleMembers(OPERATOR_ROLE);
    }

    /**
     * @notice Gets all pending proposal IDs
     * @return Array of pending proposal IDs
     */
    function getPendingProposals() external view returns (bytes32[] memory) {
        return pendingProposals;
    }

    /**
     * @notice Gets proposal details
     * @param proposalId The proposal ID
     * @return proposer The address that created the proposal
     * @return data The encoded function call data
     * @return approvalCount Number of approvals received
     * @return executed Whether the proposal has been executed
     * @return createdAt Timestamp when proposal was created
     * @return roleRequired The role required to approve this proposal
     */
    function getProposal(
        bytes32 proposalId
    )
        external
        view
        returns (
            address proposer,
            bytes memory data,
            uint256 approvalCount,
            bool executed,
            uint256 createdAt,
            bytes32 roleRequired
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.data,
            proposal.approvalCount,
            proposal.executed,
            proposal.createdAt,
            proposal.roleRequired
        );
    }

    /**
     * @notice Checks if an address has approved a proposal
     * @param proposalId The proposal ID
     * @param approver The address to check
     * @return Whether the address has approved the proposal
     */
    function hasApprovedProposal(
        bytes32 proposalId,
        address approver
    ) external view returns (bool) {
        return proposals[proposalId].hasApproved[approver];
    }

    /**
     * @notice Checks if an address is a valid Qubic address
     * @param addr Address to check
     * @return bool
     * @dev This function validates format and characters but does not verify checksum.
     *      Full checksum validation would require implementing Qubic's specific algorithm.
     *      The bridge relies on the Qubic network to reject invalid addresses.
     */
    function isQubicAddress(string memory addr) internal pure returns (bool) {
        bytes memory baddr = bytes(addr);

        // Check length
        if (baddr.length != QUBIC_ACCOUNT_LENGTH) {
            return false;
        }

        // Check that address is not all zeros or all same character
        bytes1 firstChar = baddr[0];
        bool allSame = true;
        bool allZeros = true;

        // Validate characters and check for patterns
        for (uint256 i = 0; i < QUBIC_ACCOUNT_LENGTH; i++) {
            bytes1 char = baddr[i];

            // Only allow alphanumeric uppercase
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x41 && char <= 0x5A) // A-Z
            ) {
                return false;
            }

            // Check for suspicious patterns
            if (char != firstChar) {
                allSame = false;
            }
            if (char != 0x30) {
                // '0'
                allZeros = false;
            }
        }

        // Reject obviously invalid patterns
        if (allSame || allZeros) {
            return false;
        }

        // NOTE: Full checksum validation not implemented
        // The Qubic network will reject invalid addresses during processing
        return true;
    }
}
