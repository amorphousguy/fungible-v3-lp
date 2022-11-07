// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./UniswapV3position.sol";
import "./WadRayMath.sol";
import "dependencies/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "hardhat/console.sol";

contract FungibleV3LP is UniswapV3position, ERC20 {
    using WadRayMath for uint256;
    using Strings for uint24;

    //pool variables
    address private tokenA;
    address private tokenB;
    uint24 private fee;

    //current active NFT
    uint256 private activeTokenId;

    //fee factor
    uint256 private _liqFactor; //implements rebase token functionality [RaY]

    //factory
    IUniswapV3Factory uniswapFactory;


    constructor(
        INonfungiblePositionManager _nonfungiblePositionManager,
        IUniswapV3Factory _uniFactory,
        address _tokenA,
        address _tokenB,
        uint24 _fee
    )
        UniswapV3position(_nonfungiblePositionManager)
        ERC20(tSymbol(_tokenA, _tokenB, _fee), tSymbol(_tokenA, _tokenB, _fee))
    {
        uniswapFactory = _uniFactory;
        tokenA = _tokenA;
        tokenB = _tokenB;
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA); //swap order so tokenA is smallest (token0)
        fee = _fee;
        _liqFactor = WadRayMath.ray(); //initialize with factor of 1
    }

    function tSymbol(address a, address b, uint24 _fee)
        private
        view
        returns (string memory)
    {
        if (a > b) (a, b) = (b, a); //make lowest address first (token0)
        return
            string(
                abi.encodePacked(
                    IERC20Metadata(a).symbol(),
                    "-",
                    IERC20Metadata(b).symbol(),
                    "-",
                    _fee.toString(),
                    "-",
                    "v3LP"
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
        AmountStruc memory returnAmount;
        amountDesired.amount0 = amountADesired;
        amountDesired.amount1 = amountBDesired;
        amountMin.amount0 = amountAMin;
        amountMin.amount1 = amountBMin;
        delete amountADesired;
        delete amountBDesired;
        delete amountAMin;
        delete amountBMin;

        //calculate using oracles right tickLower + tickHigher to use
        (int24 tickLower, int24 tickHigher)=getNewInterval();
        console.log('ticklower: %s',absValue(int256(tickLower)));
        console.log('tickhigher: %s',absValue(int256(tickHigher)));


        //burn current NFT fully
        //check if there is a current NFT position
        if (activeTokenId>0) {
            uint256 oldLiquidity = deposits[activeTokenId].liquidity;
            console.log("step1");

            //withdraw liquidity from current collateral
            AmountStruc memory amount2 = burnPosition(activeTokenId); //brings all liquidity from position
                        
            console.log("step2");

            //collect all fees.  Accrue to token holders so far....
            AmountStruc memory amount = collectAllFees(activeTokenId); //brings all collected fees to this contract
            
            console.log("step3");

            //derive amount backing existing LPs as what was just transferred to this contract + any previous leftovers
            //derive amount backing existing LPs as what was just transferred to this contract + any previous leftovers
            AmountStruc memory amountDesiredExisting;
            AmountStruc memory amountMinExisting;
            
            amountDesiredExisting.amount0 = ERC20(tokenA).balanceOf(address(this));
            amountDesiredExisting.amount1 = ERC20(tokenB).balanceOf(address(this));
            console.log('tokenA balance: %s',amountDesiredExisting.amount0);
            console.log('tokenB balance: %s',amountDesiredExisting.amount1);
            amountMinExisting.amount0 = 0;
            amountMinExisting.amount1 = 0;
            console.log("step4");

            //mint new position for EXISTING tokens (ie, reposition liquidity)
            AmountStruc memory returnAmount;
            (activeTokenId, liquidity, returnAmount) = mintNewPositionInternal(
                tokenA,
                tokenB,
                fee,
                tickLower,
                tickHigher,
                amountDesiredExisting,
                amountMinExisting
            );

            console.log("step5");
            //update liquidity factor
            _liqFactor = _liqFactor * liquidity / oldLiquidity;

            console.log("step6");
            //Add liquidity of new depositor
            (liquidity, returnAmount) = increaseLiquidityCurrentRange(
                activeTokenId,
                amountDesired,
                amountMin
            );
            console.log("step6b");
            //update amounts to be minted in new position
            //amountDesired.amount0 = 
        } else {
            console.log("step1 new NFT");
            //mint new position for this user and send LP tokens
            (activeTokenId, liquidity, returnAmount) = mintNewPosition(
                tokenA,
                tokenB,
                fee,
                tickLower,
                tickHigher,
                amountDesired,
                amountMin
            );
        } 
        console.log("step7");
        //mint ERC20 LP token with 'liquidity' amount in 'to' address wallet
        _mint(to, liquidity.rayDivFloor(_liqFactor));

        return (returnAmount.amount0, returnAmount.amount1, liquidity);
    }

    function absValue(int num) internal pure returns (uint) {
        return (num>0) ? uint(num):uint(-num);
    }

    function getNewInterval() internal view returns (int24 tickLower, int24 tickHigher) {

         //get pool address
        address poolAddress = uniswapFactory.getPool(
            tokenA,
            tokenB,
            fee
        );

        console.log("in oracle");
        //get 10 datasamples of mean historical values
        int24[] memory historicMeanTick = new int24[](10);
        uint32 i;
        for (i = 0; i < 10; i++) {  //for loop example
            (historicMeanTick[i],)=OracleLibrary.consult(poolAddress,1+i*60*60);
        }
        console.log("read prices");
    
        //calculate L1 norm 
        uint L1TickNorm = 0;
        int24 j;
        for (j = 1; j < 9; j++) {  //for loop example
            L1TickNorm += absValue(int(historicMeanTick[9]) - 60*60*(j+1)*int(historicMeanTick[uint24(j)]) + 60*60*j*int(historicMeanTick[uint24(j-1)]))/(60*60);
        }
        L1TickNorm /=8;
        console.log("calculated norm");

        //center tick around current price
        tickLower = historicMeanTick[0] - int24(uint24(L1TickNorm))/2;
        tickHigher = historicMeanTick[0] + int24(uint24(L1TickNorm))/2;


        //ensure multiple of 60 (given 3000 fee....)
        //TODO: ensure right multiple given pool fee
        tickLower = (tickLower / 60) * 60;
        tickHigher = (tickHigher / 60) * 60;
    }

    function removeLiquidity(
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public returns (uint amountA, uint amountB) {
        
        uint256 oldLiquidity = deposits[activeTokenId].liquidity;

        //collect all fees and reinvest + calculate new factor
        //this also helps clear all collected fees for when we withdraw liquidity for msg.sender
        AmountStruc memory amount = collectAllFees(activeTokenId); //brings all collected fees to this contract
        AmountStruc memory amountMin;    
        amountMin.amount0 = 0;
        amountMin.amount0 = 0;
        //Add liquidity of new depositor
        if (amount.amount0 > 0 && amount.amount1 > 0) {
            increaseLiquidityCurrentRange(
                    activeTokenId,
                    amount,
                    amountMin
            );

            //update liquidity factor
            _liqFactor = _liqFactor * deposits[activeTokenId].liquidity / oldLiquidity;
        }

       //burn ERC20 from msg.sender
       _burn(msg.sender, liquidity);

        //decrease liquidity and send tokens to msg sender.  This will include latest collected fees proportional to the
        //amount that corresponds to them
        AmountStruc memory amountReturned = decreaseLiquidity(activeTokenId, uint128(liquidity.rayMulFloor(_liqFactor)));
        amount = collectAllFees(activeTokenId); //brings all collected fees to this contract

        // send collected fees to owner
        console.log('decrease liequidy before transfer');
        TransferHelper.safeTransfer(deposits[activeTokenId].token0, msg.sender, amountReturned.amount0);
        TransferHelper.safeTransfer(deposits[activeTokenId].token1, msg.sender, amountReturned.amount1);
        console.log('decrease liequidy after transfer');

    }
}
