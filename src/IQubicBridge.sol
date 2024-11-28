// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IQubicBridge {
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

    // Functions
    function setAdmin(address newAdmin) external;
    function addManager(address manager) external;
    function removeManager(address manager) external;
    function createOrder(string calldata destinationAccount, uint256 amount) external returns (uint256);
    function confirmOrder(uint256 orderId) external;
    function revertOrder(uint256 orderId) external;
    function executeOrder(uint256 originOrderId, string calldata originAccount, address destinationAccount, uint256 amount) external;
}
