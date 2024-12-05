// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IQubicToken {
    // Events
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    // Functions
    function setAdmin(address newAdmin) external;
    function addOperator(address operator) external returns (bool);
    function removeOperator(address operator) external returns (bool);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;

    // Views
    function getAdmin() external view returns (address);
    function getOperators() external view returns (address[] memory);
    function decimals() external pure returns (uint8);
}
