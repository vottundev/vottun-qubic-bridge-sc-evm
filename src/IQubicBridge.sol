// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IQubicBridge {
    struct PullOrder {
        address originAccount;
        string destinationAccount;
        uint248 amount;
        bool done;
    }

    // Events
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
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event TransferFeeUpdated(uint256 feePct);

    // Functions
    function setAdmin(address newAdmin) external returns (bool);
    function addManager(address manager) external returns (bool);
    function removeManager(address manager) external returns (bool);
    function addOperator(address operator) external returns (bool);
    function removeOperator(address operator) external returns (bool);
    function createOrder(string calldata destinationAccount, uint256 amount) external;
    function confirmOrder(uint256 orderId) external;
    function revertOrder(uint256 orderId) external;
    function executeOrder(uint256 originOrderId, string calldata originAccount, address destinationAccount, uint256 amount) external;

    // Views
    function getOrder(uint256 orderId) external view returns (PullOrder memory);
    function getAdmin() external view returns (address);
    function getManagers() external view returns (address[] memory);
    function getOperators() external view returns (address[] memory);
}
