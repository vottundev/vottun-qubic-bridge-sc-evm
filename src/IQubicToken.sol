// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IQubicToken {
    // Events
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    // Functions
    function setAdmin(address newAdmin) external;
    function addMinter(address minter) external;
    function removeMinter(address minter) external;
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function decimals() external pure returns (uint8);
}
