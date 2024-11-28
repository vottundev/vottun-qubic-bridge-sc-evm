// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test, console} from "forge-std/Test.sol";
import {QubicToken} from "../src/QubicToken.sol";

contract QubicProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}
}

contract QubicTokenTest is Test {
    QubicToken public token;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    function setUp() public {
        token = new QubicToken();
        token.addMinter(alice);
    }

    function test_MintTokens() public {
        vm.startPrank(alice);
        token.mint(bob, 100);
        assertEq(token.balanceOf(bob), 100);
    }

    function test_BurnTokens() public {
        vm.startPrank(alice);
        token.mint(bob, 100);
        token.burn(bob, 100);
        assertEq(token.balanceOf(bob), 0);
    }
}
