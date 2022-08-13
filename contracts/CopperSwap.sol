//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./CopperToken.sol";

/** @title Uniswap CPR/WETH pair Exchange */
contract CopperSwap is Ownable {
    address private _cpr;
    address private _weth;
    ISwapRouter private _swapRouter;

    uint24 public constant poolFee = 3000;

    constructor(
        address cpr_,
        address weth_,
        address swapRouter_
    ) {
        _cpr = cpr_;
        _weth = weth_;
        _swapRouter = ISwapRouter(swapRouter_);
    }

    /**
    @notice Exchanges the exact amount of WETH for CPR.
    @param amountIn Amount of WETH to be swapped.
    @return amountOut Amount of CPR received for WETH.
    */
    function swapExactInputSingle(uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        TransferHelper.safeTransferFrom(
            _weth,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(_weth, address(_swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _weth,
                tokenOut: _cpr,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = _swapRouter.exactInputSingle(params);
    }
}
