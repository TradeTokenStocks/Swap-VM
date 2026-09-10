// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IStockMultiplier } from "./interfaces/ITokenizedStocks.sol";

import { Context } from "../libs/VM.sol";
import { Opcode } from "../libs/OpcodeList.sol";
import { MemoryPtr, MemoryPtrLib } from "../libs/MemoryPtr.sol";
import { InstructionBuilder } from "../libs/InstructionBuilder.sol";
import { InstructionArgs } from "../libs/InstructionArgs.sol";

/// @notice OnlyTxOriginTokenBalanceNonZero opcode, fail if tx.origin token balance is zero (NFT-compatible)
///   The opcode allows authorized user to fill the order through 3rd-party contracts
/// @dev Encoding: [address token]
/// @dev Validations through tx.origin are considered weak due to possible transaction flow
///   interception: any contract executing tx originated from tx.origin can pass the validation
library OnlyTxOriginTokenBalanceNonZero {
    using InstructionArgs for bytes;
    using InstructionArgs for bytes32;

    using MemoryPtrLib for MemoryPtr;
    using InstructionBuilder for MemoryPtr;

    error TxOriginTokenBalanceIsZero(address txOrigin, address token);

    Opcode constant opcode = Opcode.OnlyTxOriginTokenBalanceNonZero;

    function sizeOf(address) internal pure returns (uint256) {
        return InstructionBuilder.sizeOf() + 20;
    }

    function build(address token) internal pure returns (bytes memory) {
        return build(MemoryPtrLib.alloc(sizeOf(token)), token).resolve();
    }

    function build(MemoryPtr ptrStart, address token) internal pure returns (MemoryPtr ptr) {
        ptr = ptrStart.pushHeader(opcode);
        ptr = ptr.push(token);
        ptrStart.patchLength(ptr);
    }

    function parse(bytes calldata args) internal pure returns (address token) {
        token = args.at(0).asAddress();
    }

    function exec(Context memory, bytes calldata args) internal view {
        address token = parse(args);
        uint256 balance = IERC20(token).balanceOf(tx.origin);
        require(balance > 0, TxOriginTokenBalanceIsZero(tx.origin, token));
    }
}

/// @notice CheckStockMultiplierRange opcode, fail if token multiplier is not in range expected value
/// @dev Encoding: [address token, uint256 min_multiplier, uint256 max_multiplier]
library CheckStockMultiplierRange {
    using InstructionArgs for bytes;
    using InstructionArgs for bytes32;

    using MemoryPtrLib for MemoryPtr;
    using InstructionBuilder for MemoryPtr;

    error MinMultiplierMustBeGreaterThanZero(uint256 min_multiplier);
    error MaxMultiplierMustBeGreaterThanMinMultiplier(uint256 max_multiplier, uint256 min_multiplier);
    error TokenMultiplierIsZero(address token);
    error CurrentMultiplierIsNotInRange(address taker, address token, uint256 current_multiplier, uint256 min_multiplier, uint256 max_multiplier);

    Opcode constant opcode = Opcode.CheckStockMultiplierRange;

    function sizeOf(address, uint256, uint256) internal pure returns (uint256) {
        return InstructionBuilder.sizeOf() + 20 + 32 + 32;
    }

    function build(address token, uint256 min_multiplier, uint256 max_multiplier) internal pure returns (bytes memory) {
        return build(MemoryPtrLib.alloc(sizeOf(token, min_multiplier, max_multiplier)), token, min_multiplier, max_multiplier).resolve();
    }

    function build(MemoryPtr ptrStart, address token, uint256 min_multiplier, uint256 max_multiplier) internal pure returns (MemoryPtr ptr) {
        require(min_multiplier > 0, MinMultiplierMustBeGreaterThanZero(min_multiplier));
        require(min_multiplier <= max_multiplier, MaxMultiplierMustBeGreaterThanMinMultiplier(max_multiplier, min_multiplier));
        ptr = ptrStart.pushHeader(opcode);
        ptr = ptr.push(token).push(min_multiplier, 32).push(max_multiplier, 32);
        ptrStart.patchLength(ptr);
    }

    function parse(bytes calldata args) internal pure returns (address token, uint256 min_multiplier, uint256 max_multiplier) {
        token = args.at(0).asAddress();
        min_multiplier = args.at(20).asU256();
        max_multiplier = args.at(52).asU256();
    }

    function exec(Context memory ctx, bytes calldata args) internal view {
        (address token, uint256 min_multiplier, uint256 max_multiplier) = parse(args);
        uint256 current_multiplier = IStockMultiplier(token).multiplier();

        require(current_multiplier >= min_multiplier && current_multiplier <= max_multiplier, CurrentMultiplierIsNotInRange(ctx.query.taker, token, current_multiplier, min_multiplier, max_multiplier));
    }
}
