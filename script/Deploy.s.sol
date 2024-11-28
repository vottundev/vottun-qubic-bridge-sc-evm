// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {QubicToken} from "../src/QubicToken.sol";
import {QubicBridge} from "../src/QubicBridge.sol";

contract QubicDeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        QubicToken token = new QubicToken();
        QubicBridge bridge = new QubicBridge(address(token));

        token.addMinter(address(bridge));
        bridge.addManager(msg.sender);

        vm.stopBroadcast();

        console.log("Token: %s", address(token));
        console.log("Bridge: %s", address(bridge));
    }
}
