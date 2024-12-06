// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract QubicBridgeTest is Test {
    QubicToken public token;
    QubicBridge public bridge;

    address admin = makeAddr("admin");
    address manager = makeAddr("manager");
    address operator = makeAddr("operator");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    string queen = "FRDMFRRRCQTOUBOKAEJZEPLIOSVBQKYRCWILPZSJJCWNDYVXIMSAUVQFIXOM";
    uint256 initialBalance = 100_000_000;

    function setUp() public {
        vm.startPrank(admin);

        // Initial fee 2% (2 decimal places)
        uint256 baseFee = 2 * 100;

        token = new QubicToken();
        bridge = new QubicBridge(address(token), baseFee);

        // admin adds bridge manager and token operator
        assertEq(bridge.addManager(manager), true);
        assertEq(token.addOperator(address(bridge)), true);

        // bridge manager adds bridge operator
        vm.startPrank(manager);
        assertEq(bridge.addOperator(operator), true);

        deal(address(token), alice, initialBalance);
        deal(address(token), bob, initialBalance);
    }

    function test_AddRemoveManager() public {
        vm.startPrank(admin);

        vm.expectEmit(address(bridge));
        emit QubicBridge.ManagerAdded(bob);
        assertEq(bridge.addManager(bob), true);

        vm.expectEmit(address(bridge));
        emit QubicBridge.ManagerRemoved(bob);
        assertEq(bridge.removeManager(bob), true);
    }

    function test_AddRemoveOperator() public {
        vm.startPrank(manager);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OperatorAdded(bob);
        assertEq(bridge.addOperator(bob), true);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OperatorRemoved(bob);
        assertEq(bridge.removeOperator(bob), true);
    }

    function test_setBaseFee(uint256 baseFee) public {
        vm.assume(baseFee < 100 * 100);
        vm.startPrank(admin);
        bridge.setBaseFee(baseFee);
        assertEq(bridge.baseFee(), baseFee);
    }

    function test_setBaseFee_invalid() public {
        vm.startPrank(admin);
        vm.expectRevert(QubicBridge.InvalidBaseFee.selector, address(bridge));
        bridge.setBaseFee(101 * 100);
    }

    function test_createOrder(uint256 amount) public {
        vm.assume(amount > 1 && amount < initialBalance);
        uint256 feePct = 50;
        uint256 fee = getTransferFee(amount, bridge.baseFee(), feePct);
        address originAccount = alice;
        string memory destinationAccount = queen;
        uint256 expectedOrderId = 1;

        // User creates the order
        vm.startPrank(originAccount);
        token.approve(address(bridge), amount);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderCreated(expectedOrderId, originAccount, destinationAccount, amount);
        bridge.createOrder(destinationAccount, amount);

        assertEq(token.balanceOf(originAccount), initialBalance - amount);
        assertEq(token.balanceOf(address(bridge)), amount);

        QubicBridge.PullOrder memory order = bridge.getOrder(expectedOrderId);
        assertEq(order.originAccount, originAccount);
        assertEq(order.destinationAccount, destinationAccount);
        assertEq(order.amount, amount);
        assertEq(order.done, false);

        // operator confirms the order
        // the operator is the fee recipient
        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderConfirmed(expectedOrderId, originAccount, destinationAccount, amount);
        bridge.confirmOrder(expectedOrderId, feePct, operator);
        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(token.balanceOf(operator), fee);

        order = bridge.getOrder(expectedOrderId);
        assertEq(order.done, true);

        // operator fails to confirm the order again
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector, address(bridge));
        bridge.confirmOrder(expectedOrderId, feePct, operator);

        // operator fails to revert the order
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector, address(bridge));
        bridge.revertOrder(expectedOrderId, feePct, operator);
    }

    function test_revertOrder(uint256 amount) public {
        vm.assume(amount > 1 && amount < initialBalance);
        uint256 feePct = 50;
        uint256 fee = getTransferFee(amount, bridge.baseFee(), feePct);
        address originAccount = alice;
        uint256 initialOriginBalance = token.balanceOf(originAccount);
        string memory destinationAccount = queen;
        uint256 expectedOrderId = 1;

        // User creates the order
        vm.startPrank(originAccount);
        token.approve(address(bridge), amount);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderCreated(expectedOrderId, originAccount, destinationAccount, amount);
        bridge.createOrder(destinationAccount, amount);

        assertEq(expectedOrderId, expectedOrderId);
        assertEq(token.balanceOf(originAccount), initialOriginBalance - amount);
        assertEq(token.balanceOf(address(bridge)), amount);

        // operator reverts the order
        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderReverted(expectedOrderId, originAccount, destinationAccount, amount);
        bridge.revertOrder(expectedOrderId, feePct, operator);
        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(token.balanceOf(originAccount), initialOriginBalance - fee);

        // operator fails to revert the order again
        vm.expectRevert(QubicBridge.InvalidOrderId.selector, address(bridge));
        bridge.revertOrder(expectedOrderId, feePct, operator);

        // operator fails to confirm the order
        vm.expectRevert(QubicBridge.InvalidOrderId.selector, address(bridge));
        bridge.confirmOrder(expectedOrderId, feePct, operator);
    }

    function test_executeOrder(uint256 amount) public {
        vm.assume(amount > 1 && amount < initialBalance);
        uint256 originOrderId = 1;
        uint256 feePct = 50;
        uint256 fee = getTransferFee(amount, bridge.baseFee(), feePct);
        uint256 amountAfterFee = amount - fee;
        string memory originAccount = queen;
        address destinationAccount = bob;

        vm.startPrank(operator);

        // operator executes the order
        // the operator is the fee recipient
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderExecuted(originOrderId, originAccount, destinationAccount, amount);
        bridge.executeOrder(originOrderId, originAccount, destinationAccount, amount, feePct, operator);
        assertEq(token.balanceOf(destinationAccount), initialBalance + amountAfterFee);
        assertEq(token.balanceOf(operator), fee);
    }

    function test_executeOrder_invalid() public {
        uint256 orderId = 1;
        uint256 feePct = 50;
        string memory originAccount = queen;
        address destinationAccount = bob;
        uint256 amount = 1_000_000;

        // invalid operator
        vm.startPrank(bob);
        vm.expectRevert(address(bridge)); //AccessControl.AccessControlUnauthorizedAccount.signature, address(bridge));
        bridge.executeOrder(orderId, originAccount, destinationAccount, amount, feePct, operator);

        // invalid amount
        vm.startPrank(operator);
        vm.expectRevert(QubicBridge.InvalidAmount.selector, address(bridge));
        bridge.executeOrder(orderId, originAccount, destinationAccount, 0, feePct, operator);

        // invalid destination account
        vm.startPrank(operator);
        vm.expectRevert(QubicBridge.InvalidDestinationAccount.selector, address(bridge));
        bridge.executeOrder(orderId, originAccount, address(0), amount, feePct, operator);
    }

    function getTransferFee(uint256 amount, uint256 baseFee, uint256 feePct) internal pure returns (uint256) {
        // baseFee_decimals * feePct_decimals
        uint256 DENOMINATOR = 10000 * 100;
        // calculate rounding 1 up
        return (amount * baseFee * feePct + DENOMINATOR - 1) / DENOMINATOR;
    }
}
