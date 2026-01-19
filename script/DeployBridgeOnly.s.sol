// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract DeployBridgeOnlyScript is Script {
    function setUp() public {}

    function run() public {
        // EXISTING TOKEN ADDRESS
        address existingToken = 0x5438615E84178C951C0EB84Ec9Af1045eA2A7C78;

        vm.startBroadcast();

        // Initial fee 0.05% (2 decimal places: 0.05 * 100 = 5)
        uint256 baseFee = 5;

        // Initial admins
        address[] memory initialAdmins = new address[](3);
        initialAdmins[0] = 0x464800222D2AB38F696f0f74fe6A9fA5A2693E12;
        initialAdmins[1] = 0xDb29Aedd947eBa1560dd31CffEcf63bbB817aB4A;
        initialAdmins[2] = 0x7002b4761B7B836b20F07e680b5B95c755197102;

        // Multisig thresholds (2 of 3)
        uint256 adminThreshold = 2; // Require 2 admins to approve admin actions
        uint256 managerThreshold = 2; // Require 2 managers to approve manager actions

        // Fee recipient (treasury address - same as admin3, can be changed later via multisig)
        address feeRecipient = 0x7002b4761B7B836b20F07e680b5B95c755197102;

        // Deploy only the bridge with existing token
        QubicBridge bridge = new QubicBridge(
            existingToken,
            baseFee,
            initialAdmins,
            adminThreshold,
            managerThreshold,
            feeRecipient,
            1000, // minTransferAmount
            0 // maxTransferAmount (no limit)
        );

        vm.stopBroadcast();

        console.log("========================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
        console.log("Existing Token: %s", existingToken);
        console.log("New Bridge: %s", address(bridge));
        console.log("Admin Threshold: %s", adminThreshold);
        console.log("Manager Threshold: %s", managerThreshold);
        console.log("");
        console.log(
            "IMPORTANT: You need to manually add the bridge as operator to the token:"
        );
        console.log("Call token.addOperator(%s) as admin", address(bridge));
        console.log("========================================");
    }
}
