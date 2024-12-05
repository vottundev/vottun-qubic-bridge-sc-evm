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

    function setUp() public {
        vm.startPrank(admin);

        token = new QubicToken();
        bridge = new QubicBridge(address(token));

        // admin adds bridge manager and token operator
        assertEq(bridge.addManager(manager), true);
        assertEq(token.addOperator(address(bridge)), true);

        // bridge manager adds bridge operator
        vm.startPrank(manager);
        assertEq(bridge.addOperator(operator), true);

        deal(address(token), alice, 1000);
        deal(address(token), bob, 1000);
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

    function test_createOrder() public {
        uint256 amount = 100;
        address originAccount = alice;
        string memory destinationAccount = queen;
        uint256 expectedOrderId = 1;

        // User creates the order
        vm.startPrank(originAccount);
        token.approve(address(bridge), amount);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderCreated(expectedOrderId, originAccount, destinationAccount, amount);
        bridge.createOrder(destinationAccount, amount);

        assertEq(token.balanceOf(originAccount), 1000 - amount);
        assertEq(token.balanceOf(address(bridge)), amount);

        QubicBridge.PullOrder memory order = bridge.getOrder(expectedOrderId);
        assertEq(order.originAccount, originAccount);
        assertEq(order.destinationAccount, destinationAccount);
        assertEq(order.amount, amount);
        assertEq(order.done, false);

        // operator authorizes the order
        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderConfirmed(expectedOrderId, originAccount, destinationAccount, amount);
        bridge.confirmOrder(expectedOrderId);
        assertEq(token.balanceOf(address(bridge)), 0);

        order = bridge.getOrder(expectedOrderId);
        assertEq(order.done, true);

        // operator fails to confirm the order again
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector, address(bridge));
        bridge.confirmOrder(expectedOrderId);

        // operator fails to revert the order
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector, address(bridge));
        bridge.revertOrder(expectedOrderId);
    }

    function test_revertOrder() public {
        uint256 amount = 100;
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
        bridge.revertOrder(expectedOrderId);
        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(token.balanceOf(originAccount), initialOriginBalance);

        // operator fails to revert the order again
        vm.expectRevert(QubicBridge.InvalidOrderId.selector, address(bridge));
        bridge.revertOrder(expectedOrderId);

        // operator fails to confirm the order
        vm.expectRevert(QubicBridge.InvalidOrderId.selector, address(bridge));
        bridge.confirmOrder(expectedOrderId);
    }

    function test_executeOrder() public {
        uint256 originOrderId = 1;
        uint256 amount = 100;
        string memory originAccount = queen;
        address destinationAccount = bob;

        vm.startPrank(operator);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderExecuted(originOrderId, originAccount, destinationAccount, amount);
        bridge.executeOrder(originOrderId, originAccount, destinationAccount, amount);
        assertEq(token.balanceOf(destinationAccount), 1000 + amount);
    }

    function test_executeOrder_invalid() public {
        uint256 orderId = 1;
        string memory originAccount = queen;
        address destinationAccount = bob;
        uint256 amount = 100;

        // invalid operator
        vm.startPrank(bob);
        vm.expectRevert(address(bridge)); //AccessControl.AccessControlUnauthorizedAccount.signature, address(bridge));
        bridge.executeOrder(orderId, originAccount, destinationAccount, amount);

        // invalid amount
        vm.startPrank(operator);
        vm.expectRevert(QubicBridge.InvalidAmount.selector, address(bridge));
        bridge.executeOrder(orderId, originAccount, destinationAccount, 0);

        // invalid destination account
        vm.startPrank(operator);
        vm.expectRevert(QubicBridge.InvalidDestinationAccount.selector, address(bridge));
        bridge.executeOrder(orderId, originAccount, address(0), amount);
    }
}
