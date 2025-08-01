// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract QubicToken is ERC20, AccessControlEnumerable {
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint8 constant DECIMALS = 0;

    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    error InvalidAmount();

    constructor() ERC20("Wrapped Qubic", "WQUBIC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Sets the admin
     * @param newAdmin Address of the new admin
     */
    function setAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAdmin != address(0), "Admin cannot be zero address");
        address admin = getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _revokeRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        emit AdminUpdated(admin, newAdmin);
    }

    /**
     * @notice Adds a new operator
     * @param newOperator Address of the new operator
     * @return True if the role was granted, false otherwise
     */
    function addOperator(address newOperator) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(newOperator != address(0), "Operator cannot be zero address");
        bool success = _grantRole(OPERATOR_ROLE, newOperator);
        emit OperatorAdded(newOperator);
        return success;
    }

    /**
     * @notice Removes an operator
     * @param operator Address of the operator to remove
     * @return True if the role was revoked, false otherwise
     */
    function removeOperator(address operator) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        bool success = _revokeRole(OPERATOR_ROLE, operator);
        emit OperatorRemoved(operator);
        return success;
    }

    /**
     * @notice Mints new tokens to a recipient
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(OPERATOR_ROLE) {
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
    function burn(address from, uint256 amount) external onlyRole(OPERATOR_ROLE) {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _burn(from, amount);
        emit Burned(from, amount);
    }

    /**
     * @notice Gets the admin
     * @return Admin address
     */
    function getAdmin() external view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    /**
     * @notice Gets the operators
     * @return Operators
     */
    function getOperators() external view returns (address[] memory) {
        return getRoleMembers(OPERATOR_ROLE);
    }

    /**
     * @notice Gets the decimals
     * @return Decimals
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
