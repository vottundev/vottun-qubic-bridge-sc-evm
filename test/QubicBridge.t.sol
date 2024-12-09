// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract QubicBridgeTest is Test {
    QubicToken public token;
    QubicBridge public bridge;

    // accounts
    address admin = makeAddr("admin");
    address manager = makeAddr("manager");
    address operator = makeAddr("operator");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // constants
    string constant QUBIC_DESTINATION = "FRDMFRRRCQTOUBOKAEJZEPLIOSVBQKYRCWILPZSJJCWNDYVXIMSAUVQFIXOM";
    uint256 constant INITIAL_BALANCE = 100_000_000;
    uint256 constant BASE_FEE = 200; // 2%
    uint256 constant OPERATOR_FEE_PCT = 50; // 50%

    function setUp() public {
        vm.startPrank(admin);
        token = new QubicToken();
        bridge = new QubicBridge(address(token), BASE_FEE);

        // Setup roles
        bridge.addManager(manager);
        token.addOperator(address(bridge));

        vm.startPrank(manager);
        bridge.addOperator(operator);

        // Setup initial balances
        deal(address(token), alice, INITIAL_BALANCE);
        deal(address(token), bob, INITIAL_BALANCE);
        vm.stopPrank();
    }

    // ========== HELPER FUNCTIONS ==========

    function createTestOrder(
        address user,
        uint256 amount
    ) internal returns (uint256 orderId) {
        vm.startPrank(user);
        token.approve(address(bridge), amount);
        bridge.createOrder(QUBIC_DESTINATION, amount);
        vm.stopPrank();
        return 1; // First order ID
    }

    function getTransferFee(uint256 amount, uint256 feePct) internal pure returns (uint256) {
        uint256 DENOMINATOR = 10000 * 100;
        return (amount * BASE_FEE * feePct + DENOMINATOR - 1) / DENOMINATOR;
    }

    // ========== ADMIN ROLE TESTS ==========

    function test_AdminSetsNewAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        vm.startPrank(admin);

        vm.expectEmit(address(bridge));
        emit QubicBridge.AdminUpdated(admin, newAdmin);
        bridge.setAdmin(newAdmin);

        assertEq(bridge.getAdmin(), newAdmin);
    }

    function test_AdminSetsBaseFee(uint256 baseFee) public {
        vm.assume(baseFee < 100 * 100);
        vm.startPrank(admin);

        bridge.setBaseFee(baseFee);
        assertEq(bridge.baseFee(), baseFee);
    }

    function test_AdminFailsToSetBaseFee() public {
        vm.startPrank(admin);

        vm.expectRevert(QubicBridge.InvalidBaseFee.selector);
        bridge.setBaseFee(101 * 100);
    }

    // ========== MANAGER ROLE TESTS ==========

    function test_AdminSetsManager() public {
        vm.startPrank(admin);

        address newManager = makeAddr("newManager");

        vm.expectEmit(address(bridge));
        emit QubicBridge.ManagerAdded(newManager);
        assertTrue(bridge.addManager(newManager));

        vm.expectEmit(address(bridge));
        emit QubicBridge.ManagerRemoved(newManager);
        assertTrue(bridge.removeManager(newManager));
    }

    // ========== OPERATOR ROLE TESTS ==========

    function test_ManagerSetsOperator() public {
        vm.startPrank(manager);

        address newOperator = makeAddr("newOperator");

        vm.expectEmit(address(bridge));
        emit QubicBridge.OperatorAdded(newOperator);
        assertTrue(bridge.addOperator(newOperator));

        vm.expectEmit(address(bridge));
        emit QubicBridge.OperatorRemoved(newOperator);
        assertTrue(bridge.removeOperator(newOperator));
    }

    // ========== ORDER CREATION TESTS ==========

    function test_UserCreatesValidOrder(uint256 amount) public {
        vm.assume(amount > 1 && amount < INITIAL_BALANCE);

        uint256 initialBalance = token.balanceOf(alice);
        uint256 orderId = createTestOrder(alice, amount);

        // Verify balances
        assertEq(token.balanceOf(alice), initialBalance - amount);
        assertEq(token.balanceOf(address(bridge)), amount);

        // Verify order details
        QubicBridge.PullOrder memory order = bridge.getOrder(orderId);
        assertEq(order.originAccount, alice);
        assertEq(order.destinationAccount, QUBIC_DESTINATION);
        assertEq(order.amount, amount);
        assertEq(order.done, false);
    }

    function test_OrderCreationFailsInvalidInputs() public {
        // Test invalid amount
        vm.startPrank(alice);
        token.approve(address(bridge), 1);
        vm.expectRevert(QubicBridge.InvalidAmount.selector);
        bridge.createOrder(QUBIC_DESTINATION, 0);

        // Test invalid destination account
        vm.expectRevert(QubicBridge.InvalidDestinationAccount.selector);
        bridge.createOrder("INVALID", 100);

        // Test insufficient approval
        vm.expectRevert(QubicBridge.InsufficientApproval.selector);
        bridge.createOrder(QUBIC_DESTINATION, INITIAL_BALANCE + 1);
    }

    // ========== ORDER CONFIRMATION TESTS ==========

    function test_OperatorConfirmsOrder(uint256 amount) public {
        vm.assume(amount > 1 && amount < INITIAL_BALANCE);
        uint256 orderId = createTestOrder(alice, amount);
        uint256 fee = getTransferFee(amount, OPERATOR_FEE_PCT);

        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderConfirmed(orderId, alice, QUBIC_DESTINATION, amount);
        bridge.confirmOrder(orderId, OPERATOR_FEE_PCT, operator);

        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(token.balanceOf(operator), fee);

        QubicBridge.PullOrder memory order = bridge.getOrder(orderId);
        assertTrue(order.done);
    }

    function test_OrderConfirmationFailures() public {
        uint256 amount = 100_000;
        uint256 orderId = createTestOrder(alice, amount);

        // Confirm order
        vm.prank(operator);
        bridge.confirmOrder(orderId, OPERATOR_FEE_PCT, operator);

        // Try to confirm again
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector);
        vm.prank(operator);
        bridge.confirmOrder(orderId, OPERATOR_FEE_PCT, operator);

        // Try to revert confirmed order
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector);
        vm.prank(operator);
        bridge.revertOrder(orderId, OPERATOR_FEE_PCT, operator);
    }

    // ========== ORDER REVERT TESTS ==========

    function test_OperatorRevertsOrder() public {
        uint256 amount = 100_000;
        uint256 initialBalance = token.balanceOf(alice);
        uint256 fee = getTransferFee(amount, OPERATOR_FEE_PCT);
        uint256 orderId = createTestOrder(alice, amount);

        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderReverted(orderId, alice, QUBIC_DESTINATION, amount);
        bridge.revertOrder(orderId, OPERATOR_FEE_PCT, operator);

        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(token.balanceOf(alice), initialBalance - fee);
        assertEq(token.balanceOf(operator), fee);
    }

    // ========== ORDER EXECUTION TESTS ==========

    function test_OperatorExecutesOrder(uint256 amount) public {
        vm.assume(amount > 1 && amount < INITIAL_BALANCE);
        uint256 orderId = 1;
        uint256 initialBalance = token.balanceOf(bob);
        uint256 fee = getTransferFee(amount, OPERATOR_FEE_PCT);
        uint256 amountAfterFee = amount - fee;

        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderExecuted(orderId, QUBIC_DESTINATION, bob, amount);
        bridge.executeOrder(orderId, QUBIC_DESTINATION, bob, amount, OPERATOR_FEE_PCT, operator);

        assertEq(token.balanceOf(bob), initialBalance + amountAfterFee);
        assertEq(token.balanceOf(operator), fee);
    }

    function test_ExecuteOrderFailsInvalidInputs() public {
        uint256 orderId = 1;
        uint256 amount = 100_000;

        // Test unauthorized caller
        vm.startPrank(bob);
        vm.expectRevert();
        bridge.executeOrder(orderId, QUBIC_DESTINATION, bob, amount, OPERATOR_FEE_PCT, operator);

        // Test invalid amount
        vm.startPrank(operator);
        vm.expectRevert(QubicBridge.InvalidAmount.selector);
        bridge.executeOrder(orderId, QUBIC_DESTINATION, bob, 0, OPERATOR_FEE_PCT, operator);

        // Test invalid destination
        vm.expectRevert(QubicBridge.InvalidDestinationAccount.selector);
        bridge.executeOrder(orderId, QUBIC_DESTINATION, address(0), amount, OPERATOR_FEE_PCT, operator);
    }
}
