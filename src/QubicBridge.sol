// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./QubicToken.sol";

contract QubicBridge is AccessControlEnumerable, ReentrancyGuardTransient, Pausable {
    /**
     * @notice State
     */
    uint256 public baseFee;

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
     * @notice Constants
     */
    address public immutable token;
    bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint8 constant QUBIC_ACCOUNT_LENGTH = 60;

    /**
     * @notice Events
     */
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event ManagerAdded(address indexed manager);
    event ManagerRemoved(address indexed manager);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event BaseFeeUpdated(uint256 baseFee);
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
    event EmergencyTokenWithdrawn(address tokenAddress, address to, uint256 amount);
    event EmergencyEtherWithdrawn(address to, uint256 amount);

    /**
     * @notice Custom Errors
     */
    error InvalidAddress();
    error InvalidBaseFee();
    error InvalidDestinationAccount();
    error InvalidAmount();
    error InvalidFeePct();
    error InvalidFeeRecipient();
    error InvalidOrderId();
    error InsufficientApproval();
    error AlreadyConfirmed();
    error AlreadyExecuted();
    error TokenTransferFailed();
    error EtherTransferFailed();

    /**
     * @notice Constructor
     * @param _token Address of the bridge token
     * @param _baseFee Base fee (2 decimal places)
     */
    constructor(address _token, uint256 _baseFee) {
        token = _token;
        baseFee = _baseFee;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    /**
     * @notice Sets the admin
     * @param newAdmin Address of the new admin
     */
    function setAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
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
        if (newManager == address(0)) {
            revert InvalidAddress();
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
        if (newOperator == address(0)) {
            revert InvalidAddress();
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
    function removeOperator(address operator) external onlyRole(MANAGER_ROLE) returns (bool) {
        bool success = _revokeRole(OPERATOR_ROLE, operator);
        emit OperatorRemoved(operator);
        return success;
    }

    /**
     * @notice Sets the base fee
     * @param _baseFee Amount of the base fee (2 decimal places)
     */
    function setBaseFee(uint256 _baseFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_baseFee > 100 * 100) {
            revert InvalidBaseFee();
        }
        baseFee = _baseFee;
        emit BaseFeeUpdated(_baseFee);
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
        if (!bypassDestinationAccountCheck && !isQubicAddress(destinationAccount)) {
            revert InvalidDestinationAccount();
        }
        if (QubicToken(token).allowance(msg.sender, address(this)) < amount) {
            revert InsufficientApproval();
        }
        if (amount == 0 || amount > type(uint248).max) {
            revert InvalidAmount();
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
     * @param feePct Percentage of the transfer fee that the recipient will receive
     * @param feeRecipient Address of the recipient of the transfer fee
     */
    function confirmOrder(
        uint256 orderId,
        uint256 feePct,
        address feeRecipient
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
        if (feeRecipient == address(0)) {
            revert InvalidFeeRecipient();
        }

        uint256 fee = getTransferFee(amount, feePct);
        uint256 amountAfterFee = amount - fee;

        // Mark the order done
        pullOrders[orderId].done = true;

        // Transfer the fee to the recipient
        if (fee > 0) {
            QubicToken(token).transfer(feeRecipient, fee);
        }

        // Burn the amount after fee
        QubicToken(token).burn(address(this), amountAfterFee);

        emit OrderConfirmed(orderId, order.originAccount, order.destinationAccount, amount);
    }

    /**
     * @notice Called by the operator backend to revert a failed transfer-out order
     * @param orderId Order ID
     * @param feePct Percentage of the transfer fee that the recipient will receive
     * @param feeRecipient Address of the recipient of the transfer fee
     */
    function revertOrder(
        uint256 orderId,
        uint256 feePct,
        address feeRecipient
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
        if (feeRecipient == address(0)) {
            revert InvalidFeeRecipient();
        }

        // Delete the order
        delete pullOrders[orderId];

        uint256 fee = getTransferFee(amount, feePct);
        uint256 amountAfterFee = amount - fee;

        // Transfer the fee to the recipient
        if (fee > 0) {
            QubicToken(token).transfer(feeRecipient, fee);
        }

        // Transfer the amount to the origin account
        QubicToken(token).transfer(order.originAccount, amountAfterFee);

        emit OrderReverted(orderId, order.originAccount, order.destinationAccount, amount);
    }

    /**
     * @notice Called by the operator backend to execute a transfer-in order initiated in the origin network
     * @param originOrderId Order ID in the origin network
     * @param originAccount Origin account in the origin network
     * @param destinationAccount Destination account in this network
     * @param amount Amount of QubicToken to receive
     * @param feePct Percentage of the transfer fee that the recipient will receive
     * @param feeRecipient Address of the recipient of the transfer fee
     */
    function executeOrder(
        uint256 originOrderId,
        string calldata originAccount,
        address destinationAccount,
        uint256 amount,
        uint256 feePct,
        address feeRecipient
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
        if (feeRecipient == address(0)) {
            revert InvalidFeeRecipient();
        }

        uint256 fee = getTransferFee(amount, feePct);
        uint256 amountAfterFee = amount - fee;

        if (amountAfterFee == 0) {
            revert InvalidAmount();
        }

        // Mark the order as executed
        pushOrders[originOrderId] = true;

        // Mint the fee to the recipient
        if (fee > 0) {
            QubicToken(token).mint(feeRecipient, fee);
        }

        // Mint the amount to the destination account
        QubicToken(token).mint(destinationAccount, amountAfterFee);

        emit OrderExecuted(originOrderId, originAccount, destinationAccount, amount);
    }

    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Called by the admin to withdraw tokens in case of emergency
     * @param tokenAddress Address of the token to withdraw
     * @param amount Amount of tokens to withdraw
     */
    function emergencyTokenWithdraw(address tokenAddress, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        (bool success, ) = tokenAddress.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));

        if (!success) {
            revert TokenTransferFailed();
        }

        emit EmergencyTokenWithdrawn(tokenAddress, msg.sender, amount);
    }

    /**
     * @notice Called by the admin to withdraw all Ether in case of emergency
     */
    function emergencyEtherWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 amount = address(this).balance;
        (bool success, ) = msg.sender.call{value: amount}("");

        if (!success) {
            revert EtherTransferFailed();
        }

        emit EmergencyEtherWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Calculates the transfer fee with a guaranteed minimum of 1
     * @dev Rounds up so that it favors the protocol
     * @param amount Transfer amount
     * @param feePct Percentage of the baseFee to apply (no decimal places)
     * @return The calculated fee amount
     */
    function getTransferFee(uint256 amount, uint256 feePct) internal view returns (uint256) {
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
     function getOrder(uint256 orderId) external view returns (PullOrder memory) {
        if (orderId == 0 || orderId > lastPullOrderId) {
            revert InvalidOrderId();
        }

        return pullOrders[orderId];
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

    /**
     * @notice Checks if an address is a valid Qubic address
     * @param addr Address to check
     * @return bool
     */
    function isQubicAddress(string memory addr) internal pure returns (bool) {
        bytes memory baddr = bytes(addr);

        if (baddr.length != QUBIC_ACCOUNT_LENGTH) {
            return false;
        }

        for (uint i = 0; i < QUBIC_ACCOUNT_LENGTH; i++) {
            bytes1 char = baddr[i];

            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x41 && char <= 0x5A) // A-Z
            ) {
                return false;
            }
        }

        return true;
    }
}
