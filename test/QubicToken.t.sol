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
    address admin = makeAddr("admin");
    address operator = makeAddr("operator");

    function setUp() public {
        vm.startPrank(admin);
        token = new QubicToken();

        // Add operator
        token.addOperator(operator);
    }

    function test_AddRemoveOperator() public {
        vm.startPrank(admin);

        vm.expectEmit(address(token));
        emit QubicToken.OperatorAdded(bob);
        assertEq(token.addOperator(bob), true);

        vm.expectEmit(address(token));
        emit QubicToken.OperatorRemoved(bob);
        assertEq(token.removeOperator(bob), true);
    }

    function test_MintTokens() public {
        vm.startPrank(operator);
        token.mint(bob, 100);
        assertEq(token.balanceOf(bob), 100);
    }

    function test_BurnTokens() public {
        vm.startPrank(operator);
        token.mint(bob, 100);
        token.burn(bob, 100);
        assertEq(token.balanceOf(bob), 0);
    }
}
