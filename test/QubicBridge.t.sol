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
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    string queen = "FRDMFRRRCQTOUBOKAEJZEPLIOSVBQKYRCWILPZSJJCWNDYVXIMSAUVQFIXOM";

    function setUp() public {
        token = new QubicToken();
        bridge = new QubicBridge(address(token));

        token.setAdmin(address(admin));
        bridge.setAdmin(admin);

        vm.startPrank(admin);

        token.addManager(address(bob));
        token.addManager(address(bridge));
        token.removeManager(address(bob));

        bridge.addManager(manager);

        deal(address(token), alice, 1000);
        deal(address(token), bob, 1000);
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
        uint256 createdOrderId = bridge.createOrder(destinationAccount, amount);

        assertEq(createdOrderId, expectedOrderId);
        assertEq(token.balanceOf(originAccount), 1000 - amount);
        assertEq(token.balanceOf(address(bridge)), amount);

        QubicBridge.PullOrder memory order = bridge.getOrder(createdOrderId);
        assertEq(order.originAccount, originAccount);
        assertEq(order.destinationAccount, destinationAccount);
        assertEq(order.amount, amount);
        assertEq(order.done, false);

        // manager authorizes the order
        vm.startPrank(manager);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderConfirmed(createdOrderId, originAccount, destinationAccount, amount);
        bridge.confirmOrder(createdOrderId);
        assertEq(token.balanceOf(address(bridge)), 0);

        order = bridge.getOrder(createdOrderId);
        assertEq(order.done, true);

        // Manager fails to confirm the order again
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector, address(bridge));
        bridge.confirmOrder(createdOrderId);

        // Manager fails to revert the order
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector, address(bridge));
        bridge.revertOrder(createdOrderId);
    }

    function test_revertOrder() public {
        uint256 amount = 100;
        address originAccount = alice;
        string memory destinationAccount = queen;
        uint256 expectedOrderId = 1;

        // User creates the order
        vm.startPrank(originAccount);
        token.approve(address(bridge), amount);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderCreated(expectedOrderId, originAccount, destinationAccount, amount);
        uint256 createdOrderId = bridge.createOrder(destinationAccount, amount);

        assertEq(createdOrderId, expectedOrderId);
        assertEq(token.balanceOf(originAccount), 1000 - amount);
        assertEq(token.balanceOf(address(bridge)), amount);

        // manager reverts the order
        vm.startPrank(manager);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderReverted(createdOrderId, originAccount, destinationAccount, amount);
        bridge.revertOrder(createdOrderId);
        assertEq(token.balanceOf(address(bridge)), 0);

        // Manager fails to revert the order again
        vm.expectRevert(QubicBridge.InvalidOrderId.selector, address(bridge));
        bridge.revertOrder(createdOrderId);

        // Manager fails to confirm the order
        vm.expectRevert(QubicBridge.InvalidOrderId.selector, address(bridge));
        bridge.confirmOrder(createdOrderId);
    }

    function test_executeOrder() public {
        uint256 originOrderId = 1;
        uint256 amount = 100;
        string memory originAccount = queen;
        address destinationAccount = bob;

        vm.startPrank(manager);

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

        // invalid manager
        vm.startPrank(destinationAccount);
        vm.expectRevert(address(bridge)); //AccessControl.AccessControlUnauthorizedAccount.signature, address(bridge));
        bridge.executeOrder(orderId, originAccount, destinationAccount, amount);

        // invalid amount
        vm.startPrank(manager);
        vm.expectRevert(QubicBridge.InvalidAmount.selector, address(bridge));
        bridge.executeOrder(orderId, originAccount, destinationAccount, 0);

        // invalid destination account
        vm.startPrank(manager);
        vm.expectRevert(QubicBridge.InvalidDestinationAccount.selector, address(bridge));
        bridge.executeOrder(orderId, originAccount, address(0), amount);
    }
}
