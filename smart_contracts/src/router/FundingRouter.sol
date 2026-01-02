// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title FundingRouter
/// @notice Splits harvested yield across configured public goods programs.
contract FundingRouter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant BPS_DENOMINATOR = 10_000;

    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    IERC20 public immutable asset;

    struct Program {
        address recipient;
        uint16 bps;
        string metadataURI;
        bool active;
    }

    Program[] internal programs;

    event ProgramAdded(
        uint256 indexed programId, address indexed recipient, uint16 bps, string metadataURI
    );
    event ProgramUpdated(
        uint256 indexed programId,
        address indexed recipient,
        uint16 bps,
        string metadataURI,
        bool active
    );
    event AllocationsSet(uint256 indexed programId, uint16 bps);
    event FundsRouted(uint256 indexed amount, address indexed caller);
    event ProgramToggled(uint256 indexed programId, bool active);

    error InvalidAddress();
    error InvalidBps();
    error BpsTooHigh();
    error LengthMismatch();
    error NothingToRoute();
    error InvalidProgramId();
    error NoActivePrograms();

    constructor(IERC20 asset_, address admin) {
        if (address(asset_) == address(0) || admin == address(0)) revert InvalidAddress();
        asset = asset_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);
    }

    function getPrograms() external view returns (Program[] memory) {
        return programs;
    }

    function addProgram(Program calldata program) external onlyRole(CONFIG_ROLE) {
        if (program.recipient == address(0)) revert InvalidAddress();
        if (program.bps > BPS_DENOMINATOR) revert InvalidBps();

        programs.push(program);
        emit ProgramAdded(programs.length - 1, program.recipient, program.bps, program.metadataURI);
    }

    function updateProgram(uint256 programId, Program calldata program)
        external
        onlyRole(CONFIG_ROLE)
    {
        if (programId >= programs.length) revert InvalidProgramId();
        if (program.recipient == address(0)) revert InvalidAddress();
        if (program.bps > BPS_DENOMINATOR) revert InvalidBps();

        programs[programId] = program;
        emit ProgramUpdated(
            programId, program.recipient, program.bps, program.metadataURI, program.active
        );
    }

    function setAllocations(uint16[] calldata bpsList) external onlyRole(CONFIG_ROLE) {
        if (bpsList.length != programs.length) revert LengthMismatch();

        uint256 totalBps;
        for (uint256 i = 0; i < bpsList.length; i++) {
            uint16 bps = bpsList[i];
            if (bps > BPS_DENOMINATOR) revert InvalidBps();
            programs[i].bps = bps;
            totalBps += bps;
            emit AllocationsSet(i, bps);
        }

        if (totalBps > BPS_DENOMINATOR) revert BpsTooHigh();
    }

    function route() external nonReentrant onlyRole(KEEPER_ROLE) {
        uint256 balance = asset.balanceOf(address(this));
        if (balance == 0) revert NothingToRoute();

        uint256 distributed;
        bool hasActive;
        for (uint256 i = 0; i < programs.length; i++) {
            Program memory program = programs[i];
            if (!program.active || program.recipient == address(0) || program.bps == 0) continue;

            hasActive = true;

            uint256 share = (balance * program.bps) / BPS_DENOMINATOR;
            if (share > 0) {
                asset.safeTransfer(program.recipient, share);
                distributed += share;
            }
        }

        if (!hasActive) revert NoActivePrograms();

        uint256 remainder = balance - distributed;
        if (remainder > 0 && programs.length > 0) {
            Program memory lastProgram = programs[programs.length - 1];
            if (lastProgram.active && lastProgram.recipient != address(0)) {
                asset.safeTransfer(lastProgram.recipient, remainder);
                distributed += remainder;
            }
        }

        emit FundsRouted(distributed, msg.sender);
    }

    function toggleProgram(uint256 programId, bool active) external onlyRole(CONFIG_ROLE) {
        if (programId >= programs.length) revert InvalidProgramId();
        programs[programId].active = active;
        emit ProgramToggled(programId, active);
    }

    function programCount() external view returns (uint256) {
        return programs.length;
    }
}
