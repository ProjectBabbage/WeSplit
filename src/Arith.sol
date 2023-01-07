// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title WeSplit arithmetic library.
/// @author Project Babbage.
library Arith {
    /// @notice Compute the division of `x` by `y` rounding up.
    function divUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x + y - 1) / y;
    }
}
