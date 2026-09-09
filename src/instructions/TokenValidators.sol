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

/// @notice OnlyTakerTokenBalanceNonZero opcode, fail if taker token balance is zero (NFT-compatible)
/// @dev Encoding: [address token]
/// @dev Since EIP-7702, user may delegate it's account to certain code, potentially sharing
///   authorization given even by soulbound NFT with other users
library OnlyTakerTokenBalanceNonZero {
    using InstructionArgs for bytes;
    using InstructionArgs for bytes32;

    using MemoryPtrLib for MemoryPtr;
    using InstructionBuilder for MemoryPtr;

    error TakerTokenBalanceIsZero(address taker, address token);

    Opcode constant opcode = Opcode.OnlyTakerTokenBalanceNonZero;

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

    function exec(Context memory ctx, bytes calldata args) internal view {
        address token = parse(args);
        uint256 balance = IERC20(token).balanceOf(ctx.query.taker);
        require(balance > 0, TakerTokenBalanceIsZero(ctx.query.taker, token));
    }
}

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

/// @notice OnlyTakerTokenSupplyShareGte opcode, fail if taker token share is below expected share
/// @dev Encoding: [address token, uint64 share]
library OnlyTakerTokenSupplyShareGte {
    using InstructionArgs for bytes;
    using InstructionArgs for bytes32;

    using MemoryPtrLib for MemoryPtr;
    using InstructionBuilder for MemoryPtr;

    error TakerTokenBalanceSupplyShareWrongShare(uint64 share);
    error TakerTokenBalanceSupplyShareIsLessThanRequired(
        address taker, address token, uint256 balance, uint256 totalSupply, uint64 share
    );

    Opcode constant opcode = Opcode.OnlyTakerTokenSupplyShareGte;

    uint256 constant ONE = 1e18;

    function sizeOf(address, uint64) internal pure returns (uint256) {
        return InstructionBuilder.sizeOf() + 20 + 8;
    }

    function build(address token, uint64 share) internal pure returns (bytes memory) {
        return build(MemoryPtrLib.alloc(sizeOf(token, share)), token, share).resolve();
    }

    function build(MemoryPtr ptrStart, address token, uint64 share) internal pure returns (MemoryPtr ptr) {
        require(share <= ONE, TakerTokenBalanceSupplyShareWrongShare(share));

        ptr = ptrStart.pushHeader(opcode);
        ptr = ptr.push(token).push(share, 8);
        ptrStart.patchLength(ptr);
    }

    function parse(bytes calldata args) internal pure returns (address token, uint64 share) {
        token = args.at(0).asAddress();
        share = args.at(20).asU64();
    }

    function exec(Context memory ctx, bytes calldata args) internal view {
        (address token, uint64 share) = parse(args);
        uint256 balance = IERC20(token).balanceOf(ctx.query.taker);
        uint256 totalSupply = IERC20(token).totalSupply();

        // balance / totalSupply >= share
        require(
            totalSupply > 0 && balance * ONE >= share * totalSupply,
            TakerTokenBalanceSupplyShareIsLessThanRequired(ctx.query.taker, token, balance, totalSupply, share)
        );
    }
}
