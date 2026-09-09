// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { IStockMultiplier } from "../src/instructions/interfaces/ITokenizedStocks.sol";

contract StockMultiplier is IStockMultiplier {

    uint256 private _multiplier;

    constructor(uint256 initial_multiplier) {
        _multiplier = initial_multiplier;
    }


    function setMultiplier(uint256 new_multiplier) external {
        _multiplier = new_multiplier;
    }

    function multiplier() external view returns (uint256) {
        return _multiplier;
    }
}
