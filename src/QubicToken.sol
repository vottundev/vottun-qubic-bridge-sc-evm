// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract QubicToken is ERC20 {
    address public admin;
    mapping(address => bool) internal isManager;
    address[] public managers;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event ManagerAdded(address indexed manager);
    event ManagerRemoved(address indexed manager);

    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error ManagerAlreadyAdded();
    error ManagerNotAdded();

    modifier onlyAdmin() {
        if (msg.sender != admin) {
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

    constructor() ERC20("Wrapped Qubic", "WQUBIC") {
        admin = msg.sender;
    }

    /**
     * @notice Sets a new admin and revokes the previous admin's role
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
     * @notice Mints new tokens to a recipient
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyManager {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burns tokens from a sender
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyManager {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _burn(from, amount);
        emit Burned(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
