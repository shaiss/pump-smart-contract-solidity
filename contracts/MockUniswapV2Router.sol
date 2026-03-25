// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice PumpCloneFactory only needs `WETH()` in its constructor; migration is not implemented in this repo.
contract MockUniswapV2Router {
    address public immutable weth;

    constructor(address _weth) {
        weth = _weth;
    }

    function WETH() external view returns (address) {
        return weth;
    }
}

/// @notice Holds a valid contract address for router.WETH(); bonding curve uses native ETH, not WETH calls.
contract PlaceholderWETH {
    receive() external payable {}
}
