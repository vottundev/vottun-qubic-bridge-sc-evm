// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

/**
 * @title TestMultisig Script
 * @notice Script para testear funciones multisig del QubicBridge en Base Sepolia
 * 
 * Uso:
 *   forge script script/TestMultisig.s.sol:TestMultisig \
 *     --rpc-url $BASE_SEPOLIA_RPC_URL \
 *     --private-key $ADMIN_PRIVATE_KEY \
 *     --broadcast
 */
contract TestMultisig is Script {
    address constant BRIDGE_ADDRESS = 0x50B0A6391BB06cc0C7a228D41352EE91d496aE78;
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant MANAGER_ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08;

    function run() public {
        QubicBridge bridge = QubicBridge(BRIDGE_ADDRESS);
        
        console.log("=== QubicBridge Multisig Testing ===");
        console.log("Bridge Address:", BRIDGE_ADDRESS);
        console.log("");
        
        // Verificar estado actual
        _printCurrentState(bridge);
        
        // Descomenta la función que quieres testear:
        // testSetBaseFee(bridge);
        // testAddManager(bridge);
        // testEmergencyPause(bridge);
    }

    function _printCurrentState(QubicBridge bridge) internal view {
        console.log("--- Estado Actual ---");
        console.log("Base Fee:", bridge.baseFee());
        console.log("Admin Threshold:", bridge.adminThreshold());
        console.log("Manager Threshold:", bridge.managerThreshold());
        console.log("Fee Recipient:", bridge.feeRecipient());
        console.log("Paused:", bridge.paused());
        
        address[] memory admins = bridge.getAdmins();
        console.log("Admins:", admins.length);
        for (uint i = 0; i < admins.length; i++) {
            console.log("  Admin", i + 1, ":", admins[i]);
        }
        
        address[] memory managers = bridge.getManagers();
        console.log("Managers:", managers.length);
        for (uint i = 0; i < managers.length; i++) {
            console.log("  Manager", i + 1, ":", managers[i]);
        }
        
        address[] memory operators = bridge.getOperators();
        console.log("Operators:", operators.length);
        for (uint i = 0; i < operators.length; i++) {
            console.log("  Operator", i + 1, ":", operators[i]);
        }
        
        bytes32[] memory pending = bridge.getPendingProposals();
        console.log("Pending Proposals:", pending.length);
        console.log("");
    }

    /**
     * @notice Test: Cambiar base fee a 300 (3%)
     * @dev Requiere 2 aprobaciones de admin
     */
    function testSetBaseFee(QubicBridge bridge) internal {
        console.log("=== Test: Set Base Fee ===");
        
        uint256 newBaseFee = 300; // 3%
        bytes memory data = abi.encodeWithSelector(bridge.setBaseFee.selector, newBaseFee);
        
        console.log("Creando proposal para setBaseFee(", newBaseFee, ")...");
        
        vm.startBroadcast();
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopBroadcast();
        
        console.log("Proposal ID:", vm.toString(proposalId));
        console.log("Proposal creado. Ahora necesitas que otro admin apruebe.");
        console.log("Para aprobar, ejecuta:");
        console.log("  cast send");
        console.log(BRIDGE_ADDRESS);
        console.log("approveProposal(bytes32)");
        console.log(vm.toString(proposalId));
        console.log("");
    }

    /**
     * @notice Test: Agregar un nuevo manager
     * @dev Requiere 2 aprobaciones de admin
     */
    function testAddManager(QubicBridge bridge) internal {
        console.log("=== Test: Add Manager ===");
        
        // Cambia esta dirección por la del nuevo manager
        address newManager = 0x1234567890123456789012345678901234567890;
        
        bytes memory data = abi.encodeWithSelector(bridge.addManager.selector, newManager);
        
        console.log("Creando proposal para addManager(", newManager, ")...");
        
        vm.startBroadcast();
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopBroadcast();
        
        console.log("Proposal ID:", vm.toString(proposalId));
        console.log("Proposal creado. Necesitas 2 aprobaciones de admin.");
        console.log("");
    }

    /**
     * @notice Test: Emergency Pause
     * @dev Requiere 2 aprobaciones de admin
     */
    function testEmergencyPause(QubicBridge bridge) internal {
        console.log("=== Test: Emergency Pause ===");
        
        bytes memory data = abi.encodeWithSelector(bridge.emergencyPause.selector);
        
        console.log("Creando proposal para emergencyPause()...");
        
        vm.startBroadcast();
        bytes32 proposalId = bridge.proposeAction(data, DEFAULT_ADMIN_ROLE);
        vm.stopBroadcast();
        
        console.log("Proposal ID:", vm.toString(proposalId));
        console.log("Proposal creado. Necesitas 2 aprobaciones de admin.");
        console.log("");
    }

    /**
     * @notice Helper: Obtener detalles de un proposal
     */
    function getProposalDetails(bytes32 proposalId) internal view {
        QubicBridge bridge = QubicBridge(BRIDGE_ADDRESS);
        
        (
            address proposer,
            bytes memory data,
            uint256 approvalCount,
            bool executed,
            uint256 createdAt,
            bytes32 roleRequired
        ) = bridge.getProposal(proposalId);
        
        console.log("=== Proposal Details ===");
        console.log("Proposal ID:", vm.toString(proposalId));
        console.log("Proposer:", proposer);
        console.log("Approval Count:", approvalCount);
        console.log("Executed:", executed);
        console.log("Created At:", createdAt);
        console.log("Role Required:", vm.toString(roleRequired));
        console.log("");
    }
}




