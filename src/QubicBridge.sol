// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "./QubicToken.sol";

contract QubicBridge is AccessControlEnumerable {
    address public immutable token;

    bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint8 constant QUBIC_ACCOUNT_LENGTH = 60;

    struct PullOrder {
        address originAccount;
        string destinationAccount;
        uint248 amount;
        bool done;
    }

    /**
     * @notice Outgoing orders generated from this contract
     */
    PullOrder[] pullOrders;

    /**
     * @notice Incoming orders generated from the origin network
     */
    mapping(uint256 => bool) pushOrders;

    /**
     * @notice Events
     */
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event ManagerAdded(address indexed manager);
    event ManagerRemoved(address indexed manager);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event OrderCreated(
        uint256 indexed orderId, address indexed originAccount, string indexed destinationAccount, uint256 amount
    );
    event OrderConfirmed(
        uint256 indexed orderId, address indexed originAccount, string indexed destinationAccount, uint256 amount
    );
    event OrderReverted(
        uint256 indexed orderId, address indexed originAccount, string indexed destinationAccount, uint256 amount
    );
    event OrderExecuted(
        uint256 indexed originOrderId, string indexed originAccount, address indexed destinationAccount, uint256 amount
    );

    /**
     * @notice Custom Errors
     */
    error InvalidDestinationAccount();
    error InvalidAmount();
    error InvalidOrderId();
    error InsufficientApproval();
    error AlreadyConfirmed();
    error AlreadyExecuted();

    constructor(address _token) {
        token = _token;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    /**
     * @notice Sets the admin
     * @param newAdmin Address of the new admin
     */
    function setAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address admin = getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _revokeRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        emit AdminUpdated(admin, newAdmin);
    }

    /**
     * @notice Adds a new manager
     * @param newManager Address of the new manager
     * @return True if the role was granted, false otherwise
     */
    function addManager(address newManager) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        bool success = _grantRole(MANAGER_ROLE, newManager);
        emit ManagerAdded(newManager);
        return success;
    }

    /**
     * @notice Removes a manager
     * @param manager Address of the manager to remove
     * @return True if the role was revoked, false otherwise
     */
    function removeManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        bool success = _revokeRole(MANAGER_ROLE, manager);
        emit ManagerRemoved(manager);
        return success;
    }

    /**
     * @notice Adds a new operator
     * @param newOperator Address of the new operator
     * @return True if the role was granted, false otherwise
     */
    function addOperator(address newOperator) external onlyRole(MANAGER_ROLE) returns (bool) {
        bool success = _grantRole(OPERATOR_ROLE, newOperator);
        emit OperatorAdded(newOperator);
        return success;
    }

    /**
     * @notice Removes an operator
     * @param operator Address of the operator to remove
     * @return True if the role was revoked, false otherwise
     */
    function removeOperator(address operator) external onlyRole(MANAGER_ROLE) returns (bool) {
        bool success = _revokeRole(OPERATOR_ROLE, operator);
        emit OperatorRemoved(operator);
        return success;
    }

    /**
     * @notice Called by the user to initiate a transfer-out order
     * @param destinationAccount Destination account in Qubic network
     * @param amount Amount of QUBIC to send
     */
    function createOrder(
        string calldata destinationAccount,
        uint256 amount
    ) external {
        if (bytes(destinationAccount).length != QUBIC_ACCOUNT_LENGTH) {
            revert InvalidDestinationAccount();
        }
        if (QubicToken(token).allowance(msg.sender, address(this)) < amount) {
            revert InsufficientApproval();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        address originAccount = msg.sender;

        pullOrders.push(PullOrder(
            originAccount,
            destinationAccount,
            uint248(amount),
            false
        ));

        uint256 orderId = pullOrders.length;

        QubicToken(token).transferFrom(originAccount, address(this), amount);

        emit OrderCreated(orderId, originAccount, destinationAccount, amount);
    }

    /**
     * @notice Called by the operator backend to confirm a transfer-out order
     * @param orderId Order ID
     */
    function confirmOrder(uint256 orderId) external onlyRole(OPERATOR_ROLE) {
        PullOrder memory order = pullOrders[orderId - 1];
        uint256 amount = uint256(order.amount);

        if (amount == 0) {
            revert InvalidOrderId();
        }
        if (order.done) {
            revert AlreadyConfirmed();
        }

        pullOrders[orderId - 1].done = true;
        QubicToken(token).burn(address(this), amount);

        emit OrderConfirmed(orderId, order.originAccount, order.destinationAccount, amount);
    }

    /**
     * @notice Called by the operator backend to revert a failed transfer-out order
     * @param orderId Order ID
     */
    function revertOrder(uint256 orderId) external onlyRole(OPERATOR_ROLE) {
        PullOrder memory order = pullOrders[orderId - 1];
        uint256 amount = uint256(order.amount);
        if (amount == 0) {
            revert InvalidOrderId();
        }
        if (order.done) {
            revert AlreadyConfirmed();
        }

        delete pullOrders[orderId - 1];
        QubicToken(token).transfer(order.originAccount, amount);

        emit OrderReverted(orderId, order.originAccount, order.destinationAccount, amount);
    }

    /**
     * @notice Called by the operator backend to execute a transfer-in order initiated in the origin network
     * @param originOrderId Order ID in the origin network
     * @param originAccount Origin account in the origin network
     * @param destinationAccount Destination account in this network
     * @param amount Amount of QubicToken to receive
     */
    function executeOrder(
        uint256 originOrderId,
        string calldata originAccount,
        address destinationAccount,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) {
        if (destinationAccount == address(0)) {
            revert InvalidDestinationAccount();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (pushOrders[originOrderId]) {
            revert AlreadyExecuted();
        }

        pushOrders[originOrderId] = true;
        QubicToken(token).mint(destinationAccount, amount);

        emit OrderExecuted(originOrderId, originAccount, destinationAccount, amount);
    }

    /**
     * @notice Gets a pull order
     * @param orderId Order ID
     * @return Pull order
     */
    function getOrder(uint256 orderId) external view returns (PullOrder memory) {
        if (orderId == 0 || orderId > pullOrders.length) {
            revert InvalidOrderId();
        }

        return pullOrders[orderId - 1];
    }

    /**
     * @notice Gets the admin
     * @return Admin address
     */
    function getAdmin() external view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
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
}
