// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IQubicBridge {
    // Custom Errors
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
    error CannotWithdrawBridgeToken();
    error InvalidDataLength();
    error FunctionNotRegistered();
    error RoleMismatch();

    struct PullOrder {
        address originAccount;
        string destinationAccount;
        uint248 amount;
        bool done;
    }

    // Events
    event OrderCreated(
        uint256 indexed orderId, address indexed originAccount, string destinationAccount, uint256 amount
    );
    event OrderConfirmed(
        uint256 indexed orderId, address indexed originAccount, string destinationAccount, uint256 amount
    );
    event OrderReverted(
        uint256 indexed orderId, address indexed originAccount, string destinationAccount, uint256 amount
    );
    event OrderExecuted(
        uint256 indexed originOrderId, string originAccount, address indexed destinationAccount, uint256 amount
    );
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event ManagerAdded(address indexed manager);
    event ManagerRemoved(address indexed manager);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event BaseFeeUpdated(uint256 baseFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event MinTransferAmountUpdated(uint256 minAmount);
    event MaxTransferAmountUpdated(uint256 maxAmount);
    event EmergencyTokenWithdrawn(address tokenAddress, address to, uint256 amount);
    event EmergencyEtherWithdrawn(address to, uint256 amount);

    // Multisig Events
    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, bytes data, bytes32 roleRequired);
    event ProposalApproved(bytes32 indexed proposalId, address indexed approver, uint256 approvalCount);
    event ProposalExecuted(bytes32 indexed proposalId, address indexed executor);
    event ProposalCancelled(bytes32 indexed proposalId, address indexed canceller);
    event AdminThresholdUpdated(uint256 newThreshold);
    event ManagerThresholdUpdated(uint256 newThreshold);

    // Admin Functions
    function addAdmin(address newAdmin) external returns (bool);
    function removeAdmin(address admin) external returns (bool);
    function addManager(address manager) external returns (bool);
    function removeManager(address manager) external returns (bool);
    function setBaseFee(uint256 _baseFee) external;
    function setFeeRecipient(address newFeeRecipient) external;
    function setMinTransferAmount(uint256 _minTransferAmount) external;
    function setMaxTransferAmount(uint256 _maxTransferAmount) external;

    // Manager Functions
    function addOperator(address operator) external returns (bool);
    function removeOperator(address operator) external returns (bool);

    // Emergency Functions
    function emergencyPause() external;
    function emergencyUnpause() external;
    function emergencyTokenWithdraw(address tokenAddress, address recipient, uint256 amount) external;
    function emergencyEtherWithdraw(address recipient) external;

    // Bridge Operations
    function createOrder(
        string calldata destinationAccount,
        uint256 amount,
        bool bypassDestinationAccountCheck
    ) external;
    function confirmOrder(
        uint256 orderId,
        uint256 feePct
    ) external;
    function revertOrder(
        uint256 orderId,
        uint256 feePct
    ) external;
    function executeOrder(
        uint256 originOrderId,
        string calldata originAccount,
        address destinationAccount,
        uint256 amount,
        uint256 feePct
    ) external;

    // Multisig Functions
    function proposeAction(bytes calldata data, bytes32 roleRequired) external returns (bytes32);
    function approveProposal(bytes32 proposalId) external;
    function executeProposal(bytes32 proposalId) external;
    function cancelProposal(bytes32 proposalId) external;
    function setAdminThreshold(uint256 newThreshold) external;
    function setManagerThreshold(uint256 newThreshold) external;

    // Views
    function getOrder(uint256 orderId) external view returns (PullOrder memory);
    function getAdmins() external view returns (address[] memory);
    function getManagers() external view returns (address[] memory);
    function getOperators() external view returns (address[] memory);
    function token() external view returns (address);
    function baseFee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function minTransferAmount() external view returns (uint256);
    function maxTransferAmount() external view returns (uint256);
    function getPendingProposals() external view returns (bytes32[] memory);
    function getProposal(bytes32 proposalId) external view returns (
        address proposer,
        bytes memory data,
        uint256 approvalCount,
        bool executed,
        uint256 createdAt,
        bytes32 roleRequired
    );
    function hasApprovedProposal(bytes32 proposalId, address approver) external view returns (bool);
    function adminThreshold() external view returns (uint256);
    function managerThreshold() external view returns (uint256);
}
