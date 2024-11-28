// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract QubicToken is ERC20 {
    address public admin;
    mapping(address => bool) internal isMinter;
    address[] public minters;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error MinterAlreadyAdded();
    error MinterNotAdded();

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyMinter() {
        if (!isMinter[msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    constructor() ERC20("Wrapped Qubic", "WQUBIC") {
        admin = msg.sender;
    }

    /**
     * @notice Sets a new admin and revokes the previous admin's role
     * @param newAdmin Address of the new admin
     */
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
        admin = newAdmin;
        emit AdminUpdated(msg.sender, newAdmin);
    }

    /**
     * @notice Adds a new minter
     * @param minter Address of the new minter
     */
    function addMinter(address minter) external onlyAdmin {
        if (isMinter[minter]) {
            revert MinterAlreadyAdded();
        }
        isMinter[minter] = true;
        minters.push(minter);
        emit MinterAdded(minter);
    }

    /**
     * @notice Removes a minter
     * @param minter Address of the minter to remove
     */
    function removeMinter(address minter) external onlyAdmin {
        if (!isMinter[minter]) {
            revert MinterNotAdded();
        }

        for (uint256 i = 0; i < minters.length; i++) {
            if (minters[i] == minter) {
                minters[i] = minters[minters.length - 1];
                minters.pop();
                break;
            }
        }

        delete isMinter[minter];

        emit MinterRemoved(minter);
    }

    /**
     * @notice Mints new tokens to a recipient
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyMinter {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burns tokens from a sender
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyMinter {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _burn(from, amount);
        emit Burned(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
