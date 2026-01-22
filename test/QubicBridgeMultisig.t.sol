// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract QubicBridgeMultisigTest is Test {
    QubicToken public token;
    QubicBridge public bridge;

    // accounts
    address admin1 = makeAddr("admin1");
    address admin2 = makeAddr("admin2");
    address admin3 = makeAddr("admin3");
    address manager1 = makeAddr("manager1");
    address manager2 = makeAddr("manager2");
    address manager3 = makeAddr("manager3");
    address operator = makeAddr("operator");
    address alice = makeAddr("alice");
    address nonAdmin = makeAddr("nonAdmin");
    address treasury = makeAddr("treasury");

    // constants
    uint256 constant BASE_FEE = 200; // 2%
    uint256 constant ADMIN_THRESHOLD = 2; // Require 2 admin approvals
    uint256 constant MANAGER_THRESHOLD = 2; // Require 2 manager approvals
    uint256 constant INITIAL_BALANCE = 100_000_000;

    bytes32 constant DEFAULT_ADMIN_ROLE =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    function setUp() public {
        // Deploy with 3 admins and threshold=2 from the start
        vm.startPrank(admin1);
        token = new QubicToken();

        // Initialize with 3 admins
        address[] memory initialAdmins = new address[](3);
        initialAdmins[0] = admin1;
        initialAdmins[1] = admin2;
        initialAdmins[2] = admin3;

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

        // Add 3 managers via multisig (need 2 approvals)
        bytes memory addManager1Data = abi.encodeWithSelector(
            bridge.addManager.selector,
            manager1
        );
        bytes32 proposalId = bridge.proposeAction(
            addManager1Data,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(proposalId); // admin1 approves
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId); // admin2 approves

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Add manager2
        vm.prank(admin1);
        bytes memory addManager2Data = abi.encodeWithSelector(
            bridge.addManager.selector,
            manager2
        );
        proposalId = bridge.proposeAction(addManager2Data, DEFAULT_ADMIN_ROLE);

        vm.prank(admin1);
        bridge.approveProposal(proposalId);

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Add manager3
        vm.prank(admin1);
        bytes memory addManager3Data = abi.encodeWithSelector(
            bridge.addManager.selector,
            manager3
        );
        proposalId = bridge.proposeAction(addManager3Data, DEFAULT_ADMIN_ROLE);

        vm.prank(admin1);
        bridge.approveProposal(proposalId);

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        vm.prank(admin1);
        token.addOperator(address(bridge));

        // Setup initial balances
        deal(address(token), alice, INITIAL_BALANCE);
    }

    // ========== PROPOSAL CREATION TESTS ==========

    function test_AdminCanCreateProposal() public {
        vm.startPrank(admin1);

        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );

        // We can't predict the exact proposalId, so we just check the event is emitted
        vm.expectEmit(false, true, false, false);
        emit QubicBridge.ProposalCreated(
            bytes32(0),
            admin1,
            data,
            DEFAULT_ADMIN_ROLE
        );

        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);

        assertTrue(proposalId != bytes32(0), "Proposal ID should not be zero");
        vm.stopPrank();
    }

    function test_ManagerCanCreateProposal() public {
        vm.startPrank(manager1);

        bytes memory data = abi.encodeWithSelector(
            bridge.addOperator.selector,
            operator
        );

        bytes32 proposalId = bridge.proposeAction(data, MANAGER_ROLE);

        assertTrue(proposalId != bytes32(0), "Proposal ID should not be zero");
        vm.stopPrank();
    }

    function test_RevertWhen_NonAdminCreatesAdminProposal() public {
        vm.startPrank(nonAdmin);

        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );

        vm.expectRevert(QubicBridge.UnauthorizedRole.selector);
        bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);

        vm.stopPrank();
    }

    function test_RevertWhen_NonManagerCreatesManagerProposal() public {
        vm.startPrank(nonAdmin);

        bytes memory data = abi.encodeWithSelector(
            bridge.addOperator.selector,
            operator
        );

        vm.expectRevert(QubicBridge.UnauthorizedRole.selector);
        bridge.proposeAction(data, MANAGER_ROLE);

        vm.stopPrank();
    }

    function test_RevertWhen_InvalidRoleProvided() public {
        vm.startPrank(admin1);

        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 invalidRole = keccak256("INVALID_ROLE");

        vm.expectRevert(QubicBridge.UnauthorizedRole.selector);
        bridge.proposeAction(data, invalidRole);

        vm.stopPrank();
    }

    // ========== PROPOSAL APPROVAL TESTS ==========

    function test_AdminCanApproveAdminProposal() public {
        // Admin1 creates proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Admin2 approves
        vm.startPrank(admin2);

        vm.expectEmit(true, true, false, true);
        emit QubicBridge.ProposalApproved(proposalId, admin2, 1);

        bridge.approveProposal(proposalId);

        assertTrue(
            bridge.hasApprovedProposal(proposalId, admin2),
            "Admin2 should have approved"
        );
        vm.stopPrank();
    }

    function test_ManagerCanApproveManagerProposal() public {
        // Manager1 creates proposal
        vm.startPrank(manager1);
        bytes memory data = abi.encodeWithSelector(
            bridge.addOperator.selector,
            operator
        );
        bytes32 proposalId = bridge.proposeAction(data, MANAGER_ROLE);
        vm.stopPrank();

        // Manager2 approves
        vm.startPrank(manager2);
        bridge.approveProposal(proposalId);

        assertTrue(
            bridge.hasApprovedProposal(proposalId, manager2),
            "Manager2 should have approved"
        );
        vm.stopPrank();
    }

    function test_RevertWhen_NonAdminApprovesAdminProposal() public {
        // Admin1 creates proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Non-admin tries to approve
        vm.startPrank(nonAdmin);
        vm.expectRevert(QubicBridge.UnauthorizedRole.selector);
        bridge.approveProposal(proposalId);
        vm.stopPrank();
    }

    function test_RevertWhen_ApprovingTwice() public {
        // Admin1 creates proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Admin2 approves once
        vm.startPrank(admin2);
        bridge.approveProposal(proposalId);

        // Admin2 tries to approve again
        vm.expectRevert(QubicBridge.ProposalAlreadyApproved.selector);
        bridge.approveProposal(proposalId);
        vm.stopPrank();
    }

    function test_RevertWhen_ApprovingNonExistentProposal() public {
        vm.startPrank(admin1);
        bytes32 fakeProposalId = keccak256("fake");

        vm.expectRevert(QubicBridge.ProposalNotFound.selector);
        bridge.approveProposal(fakeProposalId);
        vm.stopPrank();
    }

    // ========== PROPOSAL EXECUTION TESTS ==========

    function test_ExecuteProposalAfterThreshold() public {
        // Admin1 creates proposal to change baseFee
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Admin2 approves (threshold = 2)
        vm.startPrank(admin2);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        // Get approval count
        (, , uint256 approvalCount, , , ) = bridge.getProposal(proposalId);
        assertEq(approvalCount, 1, "Should have 1 approval");

        // Admin3 approves (now we have 2)
        vm.startPrank(admin3);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        // Now execute
        vm.startPrank(admin1);

        bridge.executeProposal(proposalId);

        // Verify baseFee was changed
        assertEq(bridge.baseFee(), 300, "Base fee should be updated to 300");
        vm.stopPrank();
    }

    function test_ExecuteManagerProposal() public {
        // Manager1 creates proposal to add operator
        vm.startPrank(manager1);
        bytes memory data = abi.encodeWithSelector(
            bridge.addOperator.selector,
            operator
        );
        bytes32 proposalId = bridge.proposeAction(data, MANAGER_ROLE);
        vm.stopPrank();

        // Manager2 approves
        vm.startPrank(manager2);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        // Manager3 approves (threshold = 2, now we have 2)
        vm.startPrank(manager3);
        bridge.approveProposal(proposalId);

        // Execute
        bridge.executeProposal(proposalId);
        vm.stopPrank();

        // Verify operator was added
        assertTrue(
            bridge.hasRole(OPERATOR_ROLE, operator),
            "Operator should be added"
        );
    }

    function test_RevertWhen_ExecutingWithoutThreshold() public {
        // Admin1 creates proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Only 1 approval, threshold is 2
        vm.startPrank(admin2);
        vm.expectRevert(QubicBridge.InsufficientApprovals.selector);
        bridge.executeProposal(proposalId);
        vm.stopPrank();
    }

    function test_RevertWhen_ExecutingTwice() public {
        // Create and approve proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin3);
        bridge.approveProposal(proposalId);

        // Execute once
        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Try to execute again
        vm.prank(admin1);
        vm.expectRevert(QubicBridge.ProposalAlreadyExecuted.selector);
        bridge.executeProposal(proposalId);
    }

    function test_NonAdminCanExecuteApprovedProposal() public {
        // Create and approve proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin3);
        bridge.approveProposal(proposalId);

        // Non-admin CAN execute once threshold is met
        vm.prank(nonAdmin);
        bridge.executeProposal(proposalId);

        // Verify it was executed
        assertEq(bridge.baseFee(), 300);
    }

    // ========== PROPOSAL CANCELLATION TESTS ==========

    function test_ProposerCanCancelProposal() public {
        // Admin1 creates proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);

        vm.expectEmit(true, true, false, true);
        emit QubicBridge.ProposalCancelled(proposalId, admin1);

        bridge.cancelProposal(proposalId);

        // Verify proposal is marked as executed (cancelled)
        (, , , bool executed, , ) = bridge.getProposal(proposalId);
        assertTrue(executed, "Proposal should be marked as executed/cancelled");
        vm.stopPrank();
    }

    function test_AdminCanCancelAnyProposal() public {
        // Admin1 creates proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Admin2 cancels it
        vm.startPrank(admin2);
        bridge.cancelProposal(proposalId);
        vm.stopPrank();

        // Verify it's cancelled
        (, , , bool executed, , ) = bridge.getProposal(proposalId);
        assertTrue(executed, "Proposal should be cancelled");
    }

    function test_RevertWhen_NonAdminNonProposerCancels() public {
        // Admin1 creates proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Non-admin tries to cancel
        vm.startPrank(nonAdmin);
        vm.expectRevert(QubicBridge.UnauthorizedRole.selector);
        bridge.cancelProposal(proposalId);
        vm.stopPrank();
    }

    function test_RevertWhen_CancellingExecutedProposal() public {
        // Create, approve and execute proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin3);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Try to cancel executed proposal
        vm.prank(admin1);
        vm.expectRevert(QubicBridge.ProposalAlreadyExecuted.selector);
        bridge.cancelProposal(proposalId);
    }

    // ========== THRESHOLD MANAGEMENT TESTS ==========

    function test_AdminCanUpdateAdminThreshold() public {
        // Create proposal to update threshold to 3
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setAdminThreshold.selector,
            3
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        // Admin2 approves (threshold is 2)
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Execute
        vm.prank(admin1);
        vm.expectEmit(true, false, false, true);
        emit QubicBridge.AdminThresholdUpdated(3);
        bridge.executeProposal(proposalId);

        assertEq(bridge.adminThreshold(), 3, "Admin threshold should be 3");
    }

    function test_AdminCanUpdateFeeRecipient() public {
        address newTreasury = makeAddr("newTreasury");

        // Admin1 proposes to change feeRecipient
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setFeeRecipient.selector,
            newTreasury
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        // Admin2 approves (threshold is 2)
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Execute
        vm.prank(admin1);
        vm.expectEmit(true, true, false, false);
        emit QubicBridge.FeeRecipientUpdated(treasury, newTreasury);
        bridge.executeProposal(proposalId);

        assertEq(
            bridge.feeRecipient(),
            newTreasury,
            "Fee recipient should be updated"
        );
    }

    function test_AdminCanUpdateManagerThreshold() public {
        // Create proposal to update manager threshold to 3
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setManagerThreshold.selector,
            3
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        // Admin2 approves (threshold is 2)
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Execute
        vm.prank(admin1);
        vm.expectEmit(true, false, false, true);
        emit QubicBridge.ManagerThresholdUpdated(3);
        bridge.executeProposal(proposalId);

        assertEq(bridge.managerThreshold(), 3, "Manager threshold should be 3");
    }

    function test_RevertWhen_SettingZeroThreshold() public {
        vm.startPrank(admin1);

        // Try to call directly (should revert with OnlyProposal)
        vm.expectRevert(QubicBridge.OnlyProposal.selector);
        bridge.setAdminThreshold(0);

        vm.expectRevert(QubicBridge.OnlyProposal.selector);
        bridge.setManagerThreshold(0);

        vm.stopPrank();
    }

    function test_RevertWhen_NonAdminUpdatesThreshold() public {
        vm.startPrank(nonAdmin);

        vm.expectRevert();
        bridge.setAdminThreshold(3);

        vm.expectRevert();
        bridge.setManagerThreshold(3);

        vm.stopPrank();
    }

    // ========== VIEW FUNCTION TESTS ==========

    function test_GetPendingProposals() public {
        // Create multiple proposals
        vm.startPrank(admin1);
        bytes memory data1 = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes memory data2 = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            400
        );

        bytes32 proposalId1 = bridge.proposeAction(data1, DEFAULT_ADMIN_ROLE);
        bytes32 proposalId2 = bridge.proposeAction(data2, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        bytes32[] memory pending = bridge.getPendingProposals();

        assertEq(pending.length, 2, "Should have 2 pending proposals");
        assertEq(pending[0], proposalId1, "First proposal should match");
        assertEq(pending[1], proposalId2, "Second proposal should match");
    }

    function test_GetProposalDetails() public {
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        (
            address proposer,
            bytes memory returnedData,
            uint256 approvalCount,
            bool executed,
            uint256 createdAt,
            bytes32 roleRequired
        ) = bridge.getProposal(proposalId);

        assertEq(proposer, admin1, "Proposer should be admin1");
        assertEq(returnedData, data, "Data should match");
        assertEq(approvalCount, 0, "Should have 0 approvals");
        assertFalse(executed, "Should not be executed");
        assertTrue(createdAt > 0, "Should have creation time");
        assertEq(
            roleRequired,
            DEFAULT_ADMIN_ROLE,
            "Role should be DEFAULT_ADMIN_ROLE"
        );
    }

    function test_HasApprovedProposal() public {
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Check before approval
        assertFalse(
            bridge.hasApprovedProposal(proposalId, admin2),
            "Should not have approved yet"
        );

        // Approve
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Check after approval
        assertTrue(
            bridge.hasApprovedProposal(proposalId, admin2),
            "Should have approved"
        );
    }

    function test_PendingProposalsRemovedAfterExecution() public {
        // Create proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Verify it's in pending
        bytes32[] memory pending = bridge.getPendingProposals();
        assertEq(pending.length, 1, "Should have 1 pending proposal");

        // Approve and execute
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin3);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Verify it's removed from pending
        pending = bridge.getPendingProposals();
        assertEq(pending.length, 0, "Should have 0 pending proposals");
    }

    function test_PendingProposalsRemovedAfterCancellation() public {
        // Create proposal
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);

        // Verify it's in pending
        bytes32[] memory pending = bridge.getPendingProposals();
        assertEq(pending.length, 1, "Should have 1 pending proposal");

        // Cancel
        bridge.cancelProposal(proposalId);
        vm.stopPrank();

        // Verify it's removed from pending
        pending = bridge.getPendingProposals();
        assertEq(pending.length, 0, "Should have 0 pending proposals");
    }

    // ========== INTEGRATION TESTS ==========

    function test_CompleteWorkflow_AddManager() public {
        // First remove one manager to make room (MAX_MANAGERS = 3 and setUp already adds 3)
        vm.startPrank(admin1);
        bytes memory removeData = abi.encodeWithSelector(
            bridge.removeManager.selector,
            manager3
        );
        bytes32 removeProposalId = bridge.proposeAction(
            removeData,
            DEFAULT_ADMIN_ROLE
        );
        vm.stopPrank();

        // Need 2 approvals for admin threshold
        vm.prank(admin2);
        bridge.approveProposal(removeProposalId);

        vm.prank(admin3);
        bridge.approveProposal(removeProposalId);

        vm.prank(admin1);
        bridge.executeProposal(removeProposalId);

        // Now add new manager
        address newManager = makeAddr("newManager");

        // 1. Admin1 proposes to add new manager
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.addManager.selector,
            newManager
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // 2. Admin2 and Admin3 approve
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin3);
        bridge.approveProposal(proposalId);

        // 3. Execute
        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // 4. Verify new manager was added
        assertTrue(
            bridge.hasRole(MANAGER_ROLE, newManager),
            "New manager should be added"
        );
    }

    function test_CompleteWorkflow_EmergencyPause() public {
        // 1. Admin1 proposes emergency pause
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.emergencyPause.selector
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // 2. Get approvals
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin3);
        bridge.approveProposal(proposalId);

        // 3. Execute
        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // 4. Verify bridge is paused
        assertTrue(bridge.paused(), "Bridge should be paused");
    }

    function test_MultipleProposalsInParallel() public {
        // Create multiple proposals
        vm.startPrank(admin1);
        bytes memory data1 = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            300
        );
        bytes memory data2 = abi.encodeWithSelector(
            bridge.setBaseFee.selector,
            400
        );

        bytes32 proposalId1 = bridge.proposeAction(data1, DEFAULT_ADMIN_ROLE);
        bytes32 proposalId2 = bridge.proposeAction(data2, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Approve both
        vm.startPrank(admin2);
        bridge.approveProposal(proposalId1);
        bridge.approveProposal(proposalId2);
        vm.stopPrank();

        vm.startPrank(admin3);
        bridge.approveProposal(proposalId1);
        bridge.approveProposal(proposalId2);
        vm.stopPrank();

        // Execute first
        vm.prank(admin1);
        bridge.executeProposal(proposalId1);
        assertEq(bridge.baseFee(), 300, "Base fee should be 300");

        // Execute second
        vm.prank(admin1);
        bridge.executeProposal(proposalId2);
        assertEq(bridge.baseFee(), 400, "Base fee should be 400");
    }

    // ========== FEE RECIPIENT TESTS ==========

    function test_RevertWhen_NonAdminTriesToSetFeeRecipient() public {
        address newTreasury = makeAddr("newTreasury");

        // Non-admin tries to propose changing feeRecipient
        vm.prank(nonAdmin);
        bytes memory data = abi.encodeWithSelector(
            bridge.setFeeRecipient.selector,
            newTreasury
        );
        vm.expectRevert(QubicBridge.UnauthorizedRole.selector);
        bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
    }

    function test_RevertWhen_SetFeeRecipientToZeroAddress() public {
        // Admin proposes to set feeRecipient to zero address
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setFeeRecipient.selector,
            address(0)
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        // Admin2 approves
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Execute should fail
        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    function test_FeesGoToNewRecipientAfterUpdate() public {
        address newTreasury = makeAddr("newTreasury");

        // 1. Change feeRecipient via multisig
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.setFeeRecipient.selector,
            newTreasury
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Verify feeRecipient was updated
        assertEq(
            bridge.feeRecipient(),
            newTreasury,
            "Fee recipient should be updated to newTreasury"
        );

        // 2. Use existing manager1 to add operator (manager1 was added in setUp)
        vm.startPrank(manager1);
        bytes memory addOpData = abi.encodeWithSelector(
            bridge.addOperator.selector,
            operator
        );
        bytes32 opProposalId = bridge.proposeAction(addOpData, MANAGER_ROLE);
        bridge.approveProposal(opProposalId);
        vm.stopPrank();

        vm.prank(manager2);
        bridge.approveProposal(opProposalId);

        vm.prank(manager1);
        bridge.executeProposal(opProposalId);

        // Add bridge as operator to token so it can mint
        vm.prank(admin1);
        token.addOperator(address(bridge));

        // 3. Execute an order and verify fees go to new treasury
        uint256 amount = 100_000;
        vm.prank(operator);
        bridge.executeOrder(1, "QUBICADDRESS", alice, amount, 50);

        uint256 expectedFee = (amount * BASE_FEE * 50) / (10000 * 100);
        assertEq(
            token.balanceOf(newTreasury),
            expectedFee,
            "Fees should go to new treasury"
        );
        assertEq(token.balanceOf(treasury), 0, "Old treasury should have 0");
    }

    // ========== ADMIN MANAGEMENT TESTS ==========

    function test_AdminCanAddNewAdmin() public {
        // First remove one admin to make room (MAX_ADMINS = 3)
        vm.startPrank(admin1);
        bytes memory removeData = abi.encodeWithSelector(
            bridge.removeAdmin.selector,
            admin3
        );
        bytes32 removeProposalId = bridge.proposeAction(
            removeData,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(removeProposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(removeProposalId);

        vm.prank(admin1);
        bridge.executeProposal(removeProposalId);

        // Now add new admin
        address newAdmin = makeAddr("newAdmin");

        vm.startPrank(admin1);
        bytes memory addData = abi.encodeWithSelector(
            bridge.addAdmin.selector,
            newAdmin
        );
        bytes32 proposalId = bridge.proposeAction(addData, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Verify
        assertTrue(
            bridge.hasRole(DEFAULT_ADMIN_ROLE, newAdmin),
            "New admin should be added"
        );
    }

    function test_RevertWhen_AddingAdminExceedsMaxAdmins() public {
        // Already have 3 admins, try to add a 4th
        address newAdmin = makeAddr("newAdmin");

        vm.startPrank(admin1);
        bytes memory addData = abi.encodeWithSelector(
            bridge.addAdmin.selector,
            newAdmin
        );
        bytes32 proposalId = bridge.proposeAction(addData, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Execution should fail
        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    function test_AdminCanRemoveAdmin() public {
        // Remove admin3 (threshold=2, so we can remove 1 admin safely)
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.removeAdmin.selector,
            admin3
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Verify
        assertFalse(
            bridge.hasRole(DEFAULT_ADMIN_ROLE, admin3),
            "Admin3 should be removed"
        );
    }

    function test_RevertWhen_RemovingAdminWouldBreakThreshold() public {
        // We have 3 admins, threshold=2
        // Remove one admin (leaves 2, which equals threshold - OK)
        vm.startPrank(admin1);
        bytes memory removeData1 = abi.encodeWithSelector(
            bridge.removeAdmin.selector,
            admin3
        );
        bytes32 proposalId1 = bridge.proposeAction(
            removeData1,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(proposalId1);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId1);

        vm.prank(admin1);
        bridge.executeProposal(proposalId1);

        // Now we have 2 admins, threshold=2
        // Try to remove another admin (would leave 1, which is < threshold - SHOULD FAIL)
        vm.startPrank(admin1);
        bytes memory removeData2 = abi.encodeWithSelector(
            bridge.removeAdmin.selector,
            admin2
        );
        bytes32 proposalId2 = bridge.proposeAction(
            removeData2,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(proposalId2);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId2);

        // Execution should fail with ThresholdExceedsCount
        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId2);
    }

    // ========== MANAGER MANAGEMENT TESTS ==========

    function test_ManagerCanRemoveManager() public {
        // Remove manager3 (threshold=2, so we can remove 1 manager safely)
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.removeManager.selector,
            manager3
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Verify
        assertFalse(
            bridge.hasRole(MANAGER_ROLE, manager3),
            "Manager3 should be removed"
        );
    }

    function test_RevertWhen_RemovingManagerWouldBreakThreshold() public {
        // We have 3 managers, threshold=2
        // Remove one manager (leaves 2, which equals threshold - OK)
        vm.startPrank(admin1);
        bytes memory removeData1 = abi.encodeWithSelector(
            bridge.removeManager.selector,
            manager3
        );
        bytes32 proposalId1 = bridge.proposeAction(
            removeData1,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(proposalId1);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId1);

        vm.prank(admin1);
        bridge.executeProposal(proposalId1);

        // Now we have 2 managers, threshold=2
        // Try to remove another manager (would leave 1, which is < threshold - SHOULD FAIL)
        vm.startPrank(admin1);
        bytes memory removeData2 = abi.encodeWithSelector(
            bridge.removeManager.selector,
            manager2
        );
        bytes32 proposalId2 = bridge.proposeAction(
            removeData2,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(proposalId2);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId2);

        // Execution should fail with ThresholdExceedsCount
        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId2);
    }

    // ========== OPERATOR MANAGEMENT TESTS ==========

    function test_ManagerCanRemoveOperator() public {
        // First add an operator
        vm.startPrank(manager1);
        bytes memory addData = abi.encodeWithSelector(
            bridge.addOperator.selector,
            operator
        );
        bytes32 addProposalId = bridge.proposeAction(addData, MANAGER_ROLE);
        bridge.approveProposal(addProposalId);
        vm.stopPrank();

        vm.prank(manager2);
        bridge.approveProposal(addProposalId);

        vm.prank(manager1);
        bridge.executeProposal(addProposalId);

        // Verify operator was added
        assertTrue(
            bridge.hasRole(OPERATOR_ROLE, operator),
            "Operator should be added"
        );

        // Now remove the operator
        vm.startPrank(manager1);
        bytes memory removeData = abi.encodeWithSelector(
            bridge.removeOperator.selector,
            operator
        );
        bytes32 removeProposalId = bridge.proposeAction(
            removeData,
            MANAGER_ROLE
        );
        bridge.approveProposal(removeProposalId);
        vm.stopPrank();

        vm.prank(manager2);
        bridge.approveProposal(removeProposalId);

        vm.prank(manager1);
        bridge.executeProposal(removeProposalId);

        // Verify operator was removed
        assertFalse(
            bridge.hasRole(OPERATOR_ROLE, operator),
            "Operator should be removed"
        );
    }

    // ========== EMERGENCY FUNCTION TESTS ==========

    function test_AdminCanEmergencyUnpause() public {
        // First pause the bridge
        vm.startPrank(admin1);
        bytes memory pauseData = abi.encodeWithSelector(
            bridge.emergencyPause.selector
        );
        bytes32 pauseProposalId = bridge.proposeAction(
            pauseData,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(pauseProposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(pauseProposalId);

        vm.prank(admin1);
        bridge.executeProposal(pauseProposalId);

        assertTrue(bridge.paused(), "Bridge should be paused");

        // Now unpause
        vm.startPrank(admin1);
        bytes memory unpauseData = abi.encodeWithSelector(
            bridge.emergencyUnpause.selector
        );
        bytes32 unpauseProposalId = bridge.proposeAction(
            unpauseData,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(unpauseProposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(unpauseProposalId);

        vm.prank(admin1);
        bridge.executeProposal(unpauseProposalId);

        assertFalse(bridge.paused(), "Bridge should be unpaused");
    }

    function test_AdminCanEmergencyWithdrawTokens() public {
        // Setup: Give bridge some tokens
        uint256 amount = 50_000;
        vm.prank(alice);
        token.transfer(address(bridge), amount);

        assertEq(
            token.balanceOf(address(bridge)),
            amount,
            "Bridge should have tokens"
        );

        // First pause the bridge (required for emergency withdraw)
        vm.startPrank(admin1);
        bytes memory pauseData = abi.encodeWithSelector(
            bridge.emergencyPause.selector
        );
        bytes32 pauseProposalId = bridge.proposeAction(
            pauseData,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(pauseProposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(pauseProposalId);

        vm.prank(admin1);
        bridge.executeProposal(pauseProposalId);

        assertTrue(bridge.paused(), "Bridge should be paused");

        // Emergency withdraw
        address recipient = makeAddr("recipient");
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.emergencyTokenWithdraw.selector,
            address(token),
            recipient,
            amount
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Verify
        assertEq(
            token.balanceOf(recipient),
            amount,
            "Recipient should receive tokens"
        );
        assertEq(
            token.balanceOf(address(bridge)),
            0,
            "Bridge should have 0 tokens"
        );
    }

    function test_RevertWhen_EmergencyWithdrawToZeroAddress() public {
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.emergencyTokenWithdraw.selector,
            address(token),
            address(0),
            1000
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Execution should fail
        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    function test_AdminCanEmergencyWithdrawEther() public {
        // Setup: Give bridge some ETH
        uint256 amount = 5 ether;
        vm.deal(address(bridge), amount);

        assertEq(address(bridge).balance, amount, "Bridge should have ETH");

        // First pause the bridge (required for emergency withdraw)
        vm.startPrank(admin1);
        bytes memory pauseData = abi.encodeWithSelector(
            bridge.emergencyPause.selector
        );
        bytes32 pauseProposalId = bridge.proposeAction(
            pauseData,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(pauseProposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(pauseProposalId);

        vm.prank(admin1);
        bridge.executeProposal(pauseProposalId);

        assertTrue(bridge.paused(), "Bridge should be paused");

        // Emergency withdraw
        address recipient = makeAddr("recipient");
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.emergencyEtherWithdraw.selector,
            recipient
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        bridge.executeProposal(proposalId);

        // Verify
        assertEq(recipient.balance, amount, "Recipient should receive ETH");
        assertEq(address(bridge).balance, 0, "Bridge should have 0 ETH");
    }

    function test_RevertWhen_EmergencyEtherWithdrawToZeroAddress() public {
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.emergencyEtherWithdraw.selector,
            address(0)
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        bridge.approveProposal(proposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        // Execution should fail
        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    // ============ Self-Proposal Prevention Tests ============

    function test_RevertWhen_AdminProposesThemselvesAsAdmin() public {
        // Admin1 proposes themselves as admin (already admin) -> reverts at execution (AlreadyAdmin)
        vm.prank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.addAdmin.selector,
            admin1
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);

        vm.prank(admin1);
        bridge.approveProposal(proposalId);
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    function test_RevertWhen_ProposeAddManagerWhoIsAlreadyManager() public {
        // Admin proposes addManager(manager1) but manager1 is already manager -> AlreadyManager at execution
        // Advance block to avoid proposalId collision with setUp
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        vm.prank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.addManager.selector,
            manager1
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);

        vm.prank(admin1);
        bridge.approveProposal(proposalId);
        vm.prank(admin2);
        bridge.approveProposal(proposalId);

        vm.prank(admin1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    function test_RevertWhen_ProposeAddOperatorWhoIsAlreadyOperator() public {
        // Add alice as operator first, then propose addOperator(alice) again -> AlreadyOperator at execution
        vm.prank(manager1);
        bytes32 addOpId = bridge.proposeAction(
            abi.encodeWithSelector(bridge.addOperator.selector, alice),
            MANAGER_ROLE
        );
        vm.prank(manager1);
        bridge.approveProposal(addOpId);
        vm.prank(manager2);
        bridge.approveProposal(addOpId);
        vm.prank(manager1);
        bridge.executeProposal(addOpId);

        // Advance block to avoid proposalId collision
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Now try to add alice again - should fail with AlreadyOperator
        vm.prank(manager1);
        bytes32 proposalId = bridge.proposeAction(
            abi.encodeWithSelector(bridge.addOperator.selector, alice),
            MANAGER_ROLE
        );
        vm.prank(manager1);
        bridge.approveProposal(proposalId);
        vm.prank(manager2);
        bridge.approveProposal(proposalId);
        vm.prank(manager1);
        vm.expectRevert("Proposal execution failed");
        bridge.executeProposal(proposalId);
    }

    function test_AdminCanProposeOtherAddressAsAdmin() public {
        // Admin1 proposes a different address as admin - should work
        address newAdmin = makeAddr("newAdmin");

        // First we need to remove an admin to make room (max 3)
        vm.startPrank(admin1);
        bytes memory removeData = abi.encodeWithSelector(
            bridge.removeAdmin.selector,
            admin3
        );
        bytes32 removeProposalId = bridge.proposeAction(
            removeData,
            DEFAULT_ADMIN_ROLE
        );
        bridge.approveProposal(removeProposalId);
        vm.stopPrank();

        vm.prank(admin2);
        bridge.approveProposal(removeProposalId);

        vm.prank(admin1);
        bridge.executeProposal(removeProposalId);

        // Now propose adding a new admin
        vm.startPrank(admin1);
        bytes memory data = abi.encodeWithSelector(
            bridge.addAdmin.selector,
            newAdmin // proposing someone else - should succeed
        );
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopPrank();

        // Verify proposal was created
        (address proposer, , , , , ) = bridge.getProposal(proposalId);
        assertEq(proposer, admin1, "Proposer should be admin1");
    }

    function test_ManagerCanProposeOtherAddressAsOperator() public {
        // Manager1 proposes a different address as operator - should work
        address newOperator = makeAddr("newOperator");

        vm.startPrank(manager1);
        bytes memory data = abi.encodeWithSelector(
            bridge.addOperator.selector,
            newOperator // proposing someone else - should succeed
        );
        bytes32 proposalId = bridge.proposeAction(data, MANAGER_ROLE);
        vm.stopPrank();

        // Verify proposal was created
        (address proposer, , , , , ) = bridge.getProposal(proposalId);
        assertEq(proposer, manager1, "Proposer should be manager1");
    }
}
