// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "dependencies/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
//import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "dependencies/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

//debugging
import "hardhat/console.sol";


//derived from uniswap core 
library UniswapV3Utils {
    function createPoolifNecessary(
        address factory,
        address _token0,
        address _token1,
        uint24 _fee,
        uint160 _sqrtPriceX96,
        uint16 observationCardinalityNext
    ) internal returns (address poolAddress, bool _token0_denominator) {
        console.log(
            "create pool block: %s, time: %s",
            block.number,
            block.timestamp
        );
        console.log("create pool token 0: %s, token 1: %s", _token0, _token1);

        _token0_denominator = (_token1 > _token0);
        if (!_token0_denominator) (_token0, _token1) = (_token1, _token0);

        poolAddress = IUniswapV3Factory(factory).getPool(
            _token0,
            _token1,
            _fee
        );

        if (poolAddress == address(0)) {
            poolAddress = IUniswapV3Factory(factory).createPool(
                _token0,
                _token1,
                _fee
            );
            IUniswapV3Pool(poolAddress).initialize(_sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing, , , , , , ) = IUniswapV3Pool(
                poolAddress
            ).slot0();
            if (sqrtPriceX96Existing == 0) {
                IUniswapV3Pool(poolAddress).initialize(_sqrtPriceX96);
            }
        }
        IUniswapV3Pool(poolAddress).increaseObservationCardinalityNext(
            observationCardinalityNext
        );
        console.log("pool created address: %s", poolAddress);
    }
}