// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract QubicDeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Initial fee 2% (2 decimal places)
        uint256 baseFee = 2 * 100;

        QubicToken token = new QubicToken();
        QubicBridge bridge = new QubicBridge(address(token), baseFee);

        token.addOperator(address(bridge));
        bridge.addOperator(msg.sender);

        vm.stopBroadcast();

        console.log("Token: %s", address(token));
        console.log("Bridge: %s", address(bridge));
    }
}
