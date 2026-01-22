// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract QubicBridgeTest is Test {
    QubicToken public token;
    QubicBridge public bridge;
    QubicBridgeHelper public qubicBridgeHelper;

    // accounts
    address admin = makeAddr("admin");
    address manager = makeAddr("manager");
    address operator = makeAddr("operator");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address treasury = makeAddr("treasury");

    uint256 testOrderId;

    // constants
    string constant QUBIC_DESTINATION =
        "FRDMFRRRCQTOUBOKAEJZEPLIOSVBQKYRCWILPZSJJCWNDYVXIMSAUVQFIXOM";
    uint256 constant INITIAL_BALANCE = 100_000_000;
    uint256 constant BASE_FEE = 200; // 2%
    uint256 constant OPERATOR_FEE_PCT = 50; // 50%
    uint256 constant ADMIN_THRESHOLD = 1; // For testing, use 1 approval
    uint256 constant MANAGER_THRESHOLD = 1; // For testing, use 1 approval

    function setUp() public {
        vm.startPrank(admin);
        token = new QubicToken();

        // Initialize with single admin for testing (threshold=1)
        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = admin;
        bridge = new QubicBridge(
            address(token),
            BASE_FEE,
            initialAdmins,
            ADMIN_THRESHOLD,
            MANAGER_THRESHOLD,
            treasury,
            1000,
            0
        );

        address[] memory helperAdmins = new address[](1);
        helperAdmins[0] = admin;
        qubicBridgeHelper = new QubicBridgeHelper(
            address(token),
            BASE_FEE,
            helperAdmins,
            ADMIN_THRESHOLD,
            MANAGER_THRESHOLD,
            treasury,
            1000,
            0
        );

        // Setup roles using multisig proposal system
        // Add manager via proposal
        bytes memory addManagerData = abi.encodeWithSelector(
            bridge.addManager.selector,
            manager
        );
        bytes32 proposalId = bridge.proposeAction(
            addManagerData,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(proposalId);
        bridge.executeProposal(proposalId);

        token.addOperator(address(bridge));

        // Add operator via proposal (manager proposes)
        vm.startPrank(manager);
        bytes memory addOperatorData = abi.encodeWithSelector(
            bridge.addOperator.selector,
            operator
        );
        bytes32 managerRole = keccak256("MANAGER_ROLE");
        bytes32 operatorProposalId = bridge.proposeAction(
            addOperatorData,
            managerRole
        );
        bridge.approveProposal(operatorProposalId);
        bridge.executeProposal(operatorProposalId);

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
        bridge.createOrder(QUBIC_DESTINATION, amount, false);
        vm.stopPrank();
        return ++testOrderId; // First order ID
    }

    // ========== ADMIN ROLE TESTS ==========

    function test_AdminAddsNewAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        vm.startPrank(admin);

        // Create and execute proposal
        bytes memory data = abi.encodeWithSelector(
            bridge.addAdmin.selector,
            newAdmin
        );
        bytes32 proposalId = bridge.proposeAction(
            data,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(proposalId);

        vm.expectEmit(address(bridge));
        emit QubicBridge.AdminAdded(newAdmin);
        bridge.executeProposal(proposalId);

        // Verify newAdmin has admin role
        assertTrue(bridge.hasRole(bridge.DEFAULT_ADMIN_ROLE(), newAdmin));
    }

    function test_AdminSetsBaseFee(uint256 baseFee) public {
        vm.assume(baseFee < 100 * 100);
        vm.startPrank(admin);

        // Create and execute proposal
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            baseFee
        );
        bytes32 proposalId = bridge.proposeAction(
            data,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(proposalId);
        bridge.executeProposal(proposalId);

        assertEq(bridge.baseFee(), baseFee);
    }

    function test_AdminFailsToSetBaseFee() public {
        vm.startPrank(admin);

        // Create and execute proposal with invalid fee
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            101 * 100
        );
        bytes32 proposalId = bridge.proposeAction(
            data,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(proposalId);

        // When the internal call fails, executeProposal reverts with a generic error
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    // ========== MANAGER ROLE TESTS ==========

    function test_AdminSetsManager() public {
        vm.startPrank(admin);

        address newManager = makeAddr("newManager");

        // Add manager via proposal
        bytes memory addData = abi.encodeWithSelector(
            bridge.addManager.selector,
            newManager
        );
        bytes32 addProposalId = bridge.proposeAction(
            addData,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(addProposalId);

        vm.expectEmit(address(bridge));
        emit QubicBridge.ManagerAdded(newManager);
        bridge.executeProposal(addProposalId);

        // Remove manager via proposal
        bytes memory removeData = abi.encodeWithSelector(
            bridge.removeManager.selector,
            newManager
        );
        bytes32 removeProposalId = bridge.proposeAction(
            removeData,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(removeProposalId);

        vm.expectEmit(address(bridge));
        emit QubicBridge.ManagerRemoved(newManager);
        bridge.executeProposal(removeProposalId);
    }

    // ========== OPERATOR ROLE TESTS ==========

    function test_ManagerSetsOperator() public {
        vm.startPrank(manager);

        address newOperator = makeAddr("newOperator");

        // Add operator via proposal
        bytes memory addData = abi.encodeWithSelector(
            bridge.addOperator.selector,
            newOperator
        );
        bytes32 managerRole = keccak256("MANAGER_ROLE");
        bytes32 addProposalId = bridge.proposeAction(addData, managerRole);
        bridge.approveProposal(addProposalId);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OperatorAdded(newOperator);
        bridge.executeProposal(addProposalId);

        // Remove operator via proposal
        bytes memory removeData = abi.encodeWithSelector(
            bridge.removeOperator.selector,
            newOperator
        );
        bytes32 removeProposalId = bridge.proposeAction(
            removeData,
            managerRole
        );
        bridge.approveProposal(removeProposalId);

        vm.expectEmit(address(bridge));
        emit QubicBridge.OperatorRemoved(newOperator);
        bridge.executeProposal(removeProposalId);
    }

    // ========== ORDER CREATION TESTS ==========

    function test_UserCreatesValidOrder(uint256 amount) public {
        vm.assume(amount >= 1000 && amount < INITIAL_BALANCE); // minTransferAmount = 1000

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
        bridge.createOrder(QUBIC_DESTINATION, 0, false);

        // Test invalid destination account
        vm.expectRevert(QubicBridge.InvalidDestinationAccount.selector);
        bridge.createOrder("INVALID", 100, false);

        // Test insufficient approval
        vm.expectRevert(QubicBridge.InsufficientApproval.selector);
        bridge.createOrder(QUBIC_DESTINATION, INITIAL_BALANCE + 1, false);
    }

    // ========== ORDER CONFIRMATION TESTS ==========

    function test_OperatorConfirmsOrder(uint256 amount) public {
        vm.assume(amount >= 1000 && amount < INITIAL_BALANCE); // minTransferAmount = 1000
        uint256 orderId = createTestOrder(alice, amount);
        uint256 fee = qubicBridgeHelper._getTransferFee(
            amount,
            OPERATOR_FEE_PCT
        );

        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderConfirmed(
            orderId,
            alice,
            QUBIC_DESTINATION,
            amount
        );
        bridge.confirmOrder(orderId, OPERATOR_FEE_PCT);

        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(token.balanceOf(treasury), fee);

        QubicBridge.PullOrder memory order = bridge.getOrder(orderId);
        assertTrue(order.done);
    }

    function test_OrderConfirmationFailures() public {
        uint256 amount = 100_000;
        uint256 orderId = createTestOrder(alice, amount);

        // Confirm order
        vm.prank(operator);
        bridge.confirmOrder(orderId, OPERATOR_FEE_PCT);

        // Try to confirm again
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector);
        vm.prank(operator);
        bridge.confirmOrder(orderId, OPERATOR_FEE_PCT);

        // Try to revert confirmed order
        vm.expectRevert(QubicBridge.AlreadyConfirmed.selector);
        vm.prank(operator);
        bridge.revertOrder(orderId, OPERATOR_FEE_PCT);
    }

    // ========== ORDER REVERT TESTS ==========

    function test_OperatorRevertsOrder() public {
        uint256 amount = 100_000;
        uint256 initialBalance = token.balanceOf(alice);
        uint256 fee = qubicBridgeHelper._getTransferFee(
            amount,
            OPERATOR_FEE_PCT
        );
        uint256 orderId = createTestOrder(alice, amount);

        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderReverted(
            orderId,
            alice,
            QUBIC_DESTINATION,
            amount
        );
        bridge.revertOrder(orderId, OPERATOR_FEE_PCT);

        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(token.balanceOf(alice), initialBalance - fee);
        assertEq(token.balanceOf(treasury), fee);
    }

    // ========== ORDER EXECUTION TESTS ==========

    function test_OperatorExecutesOrder(uint256 amount) public {
        vm.assume(amount >= 1000 && amount < INITIAL_BALANCE); // minTransferAmount = 1000
        uint256 orderId = 1;
        uint256 initialBalance = token.balanceOf(bob);
        uint256 fee = qubicBridgeHelper._getTransferFee(
            amount,
            OPERATOR_FEE_PCT
        );
        uint256 amountAfterFee = amount - fee;

        vm.startPrank(operator);
        vm.expectEmit(address(bridge));
        emit QubicBridge.OrderExecuted(orderId, QUBIC_DESTINATION, bob, amount);
        bridge.executeOrder(
            orderId,
            QUBIC_DESTINATION,
            bob,
            amount,
            OPERATOR_FEE_PCT
        );

        assertEq(token.balanceOf(bob), initialBalance + amountAfterFee);
        assertEq(token.balanceOf(treasury), fee);
    }

    function test_ExecuteOrderFailsInvalidInputs() public {
        uint256 orderId = 1;
        uint256 amount = 100_000;

        // Test unauthorized caller
        vm.startPrank(bob);
        vm.expectRevert();
        bridge.executeOrder(
            orderId,
            QUBIC_DESTINATION,
            bob,
            amount,
            OPERATOR_FEE_PCT
        );

        // Test invalid amount (below minimum)
        vm.startPrank(operator);
        vm.expectRevert(QubicBridge.AmountBelowMinimum.selector);
        bridge.executeOrder(
            orderId,
            QUBIC_DESTINATION,
            bob,
            0,
            OPERATOR_FEE_PCT
        );

        // Test invalid destination
        vm.expectRevert(QubicBridge.InvalidDestinationAccount.selector);
        bridge.executeOrder(
            orderId,
            QUBIC_DESTINATION,
            address(0),
            amount,
            OPERATOR_FEE_PCT
        );
    }

    // ========== EMERGENCY WITHDRAWALS ==========

    function test_EmergencyTokenWithdraw() public {
        uint256 amount = 100_000;

        vm.startPrank(alice);
        token.transfer(address(bridge), amount);
        vm.stopPrank();

        vm.startPrank(admin);
        // First pause the bridge (required for emergency withdraw)
        bytes memory pauseData = abi.encodeWithSelector(
            bridge.emergencyPause.selector
        );
        bytes32 pauseProposalId = bridge.proposeAction(
            pauseData,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(pauseProposalId);
        bridge.executeProposal(pauseProposalId);

        // Create and execute withdraw proposal
        bytes memory data = abi.encodeWithSelector(
            bridge.emergencyTokenWithdraw.selector,
            address(token),
            admin,
            amount
        );
        bytes32 proposalId = bridge.proposeAction(
            data,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(proposalId);
        bridge.executeProposal(proposalId);
        vm.stopPrank();

        assertEq(token.balanceOf(admin), amount);
    }

    function test_EmergencyEtherWithdraw() public {
        uint256 amount = 100_000;
        vm.deal(address(bridge), amount);

        vm.startPrank(admin);
        // First pause the bridge (required for emergency withdraw)
        bytes memory pauseData = abi.encodeWithSelector(
            bridge.emergencyPause.selector
        );
        bytes32 pauseProposalId = bridge.proposeAction(
            pauseData,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(pauseProposalId);
        bridge.executeProposal(pauseProposalId);

        // Create and execute withdraw proposal
        bytes memory data = abi.encodeWithSelector(
            bridge.emergencyEtherWithdraw.selector,
            admin
        );
        bytes32 proposalId = bridge.proposeAction(
            data,
            bridge.DEFAULT_ADMIN_ROLE()
        );
        bridge.approveProposal(proposalId);
        bridge.executeProposal(proposalId);
        vm.stopPrank();

        assertEq(address(admin).balance, amount);
    }

    // ========== TRANSFER FEE CALCULATION ==========

    function test_getTransferFee(uint256 amount, uint256 feePct) public view {
        vm.assume(feePct <= 100);
        vm.assume(amount < 10e18);
        uint256 fee = qubicBridgeHelper._getTransferFee(amount, feePct);
        assertLe(fee, amount);
    }
}

contract QubicBridgeHelper is QubicBridge {
    constructor(
        address token,
        uint256 baseFee,
        address[] memory admins,
        uint256 adminThreshold,
        uint256 managerThreshold,
        address feeRecipient,
        uint256 minTransferAmount,
        uint256 maxTransferAmount
    )
        QubicBridge(
            token,
            baseFee,
            admins,
            adminThreshold,
            managerThreshold,
            feeRecipient,
            minTransferAmount,
            maxTransferAmount
        )
    {}

    function _getTransferFee(
        uint256 amount,
        uint256 feePct
    ) public view returns (uint256) {
        return getTransferFee(amount, feePct);
    }
}
