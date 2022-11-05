// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./UniswapV3position.sol";
import "dependencies/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract FungibleV3LP is UniswapV3position, ERC20 {
    //pool variables
    address tokenA;
    address tokenB;
    uint24 fee;

    //current active NFT
    uint256 activeTokenId;

    constructor(
        INonfungiblePositionManager _nonfungiblePositionManager,
        address _tokenA,
        address _tokenB,
        uint24 _fee
    )
        UniswapV3position(_nonfungiblePositionManager)
        ERC20(tName(_tokenA, _tokenB), tSymbol(_tokenA, _tokenB))
    {
        tokenA = _tokenA;
        tokenB = _tokenB;
        if (tokenA>tokenB) (tokenA,tokenB) = (tokenB,tokenA); //swap order so tokenA is smallest (token0)
        fee = _fee;
    }

    function tName(address a, address b) private view returns (string memory) {
        if (a>b) (a,b) = (b,a);  //make lowest address first (token0)
        return
            string(
                abi.encodePacked(
                    IERC20Metadata(a).name(),
                    IERC20Metadata(b).name(),
                    string("v3LP")
                )
            );
    }

    function tSymbol(address a, address b)
        private
        view
        returns (string memory)
    {
        if (a>b) (a,b) = (b,a);  //make lowest address first (token0)
        return
            string(
                abi.encodePacked(
                    IERC20Metadata(a).symbol(),
                    IERC20Metadata(b).symbol(),
                    string("v3LP")
                )
            );
    }

    function addLiquidity(
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        external
        returns (
            uint amountA,
            uint amountB,
            uint liquidity
        )
    {
        //consolidate to avoid stack problems
        AmountStruc memory amountDesired;
        AmountStruc memory amountMin;
        amountDesired.amount0 = amountADesired;
        amountDesired.amount1 = amountBDesired;
        amountMin.amount0 = amountAMin;
        amountMin.amount1 = amountBMin;
        delete amountADesired;
        delete amountBDesired;
        delete amountAMin;
        delete amountBMin;

        //calculate using oracles right tickLower + tickHigher to use
        int24 tickLower = TickMath.MIN_TICK;
        int24 tickHigher = TickMath.MAX_TICK;

        //burn current NFT fully
        //check if there is a current
        if (activeTokenId>0) {
            (AmountStruc memory amount) = collectAllFees(activeTokenId);  //brings all collected fees to this contract

            //withdraw liquidity from current collateral    
            (AmountStruc memory amount2) = burnPosition(activeTokenId);  //brings all liquidity from position
        } 
        
        //mint new position
         AmountStruc memory returnAmount;
        (activeTokenId, liquidity, returnAmount) = mintNewPosition(
            tokenA,
            tokenB,
            fee,
            tickLower,
            tickHigher,
            amountDesired,
            amountMin
        );

        //mint ERC20 LP token with 'liquidity' amount in 'to' address wallet
        _mint(to, liquidity); 

        return (returnAmount.amount0, returnAmount.amount1, liquidity);
    }

    function removeLiquidity(
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public returns (uint amountA, uint amountB) {
        //burn liquidity from msg.sender
        _burn(msg.sender,liquidity);

        //collect fees
        //decrease liquidity by 'liquidity' amount - but keep NFT 'alive'
        //send tokens + fees to holder

    }
}
