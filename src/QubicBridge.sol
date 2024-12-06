// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./QubicToken.sol";

contract QubicBridge {
    address public immutable token;
    address public admin;
    address[] public managers;
    mapping(address => bool) isManager;

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
    event AdminUpdated(
        address indexed oldAdmin, address indexed newAdmin
    );
    event ManagerAdded(
        address indexed manager
    );
    event ManagerRemoved(
        address indexed manager
    );

    /**
     * @notice Custom Errors
     */
    error Unauthorized();
    error InvalidDestinationAccount();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidOrderId();
    error InsufficientApproval();
    error AlreadyConfirmed();
    error AlreadyExecuted();
    error ManagerAlreadyAdded();
    error ManagerNotAdded();

    modifier onlyAdmin() {
        if (admin != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyManager() {
        if (!isManager[msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    constructor(address _token) {
        token = _token;
        admin = msg.sender;
    }

    /**
     * @notice Sets a new admin
     * @param newAdmin Address of the new admin
     */
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
        admin = newAdmin;
        emit AdminUpdated(msg.sender, newAdmin);
    }

    /**
     * @notice Adds a new manager
     * @param manager Address of the new manager
     */
    function addManager(address manager) external onlyAdmin {
        if (isManager[manager]) {
            revert ManagerAlreadyAdded();
        }

        isManager[manager] = true;
        managers.push(manager);

        emit ManagerAdded(manager);
    }

    /**
     * @notice Removes a manager
     * @param manager Address of the manager to remove
     */
    function removeManager(address manager) external onlyAdmin {
        if (!isManager[manager]) {
            revert ManagerNotAdded();
        }

        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == manager) {
                managers[i] = managers[managers.length - 1];
                managers.pop();
                break;
            }
        }

        delete isManager[manager];

        emit ManagerRemoved(manager);
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
     * @notice Called by the manager backend to confirm a transfer-out order
     * @param orderId Order ID
     */
    function confirmOrder(uint256 orderId) public onlyManager {
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
     * @notice Called by the manager backend to revert a failed transfer-out order
     * @param orderId Order ID
     */
    function revertOrder(uint256 orderId) public onlyManager {
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
     * @notice Called by the manager backend to execute a transfer-in order initiated in the origin network
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
    ) external onlyManager {
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
}
