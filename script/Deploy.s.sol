// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract QubicDeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Initial fee 0.05% (2 decimal places: 0.05 * 100 = 5)
        uint256 baseFee = 5;

        // Initial admins
        address[] memory initialAdmins = new address[](3);
        initialAdmins[0] = 0x464800222D2AB38F696f0f74fe6A9fA5A2693E12;
        initialAdmins[1] = 0x0e60B83F83c5d2684acE779dea8A957e91D02475;
        initialAdmins[2] = 0x090378a9c80c5E1Ced85e56B2128c1e514E75357;

        // Multisig thresholds (2 of 3)
        uint256 adminThreshold = 2; // Require 2 admins to approve admin actions
        uint256 managerThreshold = 2; // Require 2 managers to approve manager actions

        // Fee recipient (treasury address - same as admin3, can be changed later via multisig)
        address feeRecipient = 0x090378a9c80c5E1Ced85e56B2128c1e514E75357;

        // Transfer limits
        uint256 minTransferAmount = 1000; // Minimum 1000 QUs to prevent dust attacks
        uint256 maxTransferAmount = 0; // No maximum limit (0 = unlimited)

        QubicToken token = new QubicToken();
        QubicBridge bridge = new QubicBridge(
            address(token),
            baseFee,
            initialAdmins,
            adminThreshold,
            managerThreshold,
            feeRecipient,
            minTransferAmount,
            maxTransferAmount
        );

        token.addOperator(address(bridge));

        vm.stopBroadcast();

        console.log("Token: %s", address(token));
        console.log("Bridge: %s", address(bridge));
        console.log("Admin 1: %s", initialAdmins[0]);
        console.log("Admin 2: %s", initialAdmins[1]);
        console.log("Admin 3: %s", initialAdmins[2]);
        console.log("Admin Threshold: %s", adminThreshold);
        console.log("Manager Threshold: %s", managerThreshold);
    }
}
