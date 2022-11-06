
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/FungibleV3LP.sol";
import "dependencies/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "hardhat/console.sol";

contract FungibleV3LPTest is Test {
    FungibleV3LP public fungibleV3LP;

    address constant private weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant private usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    INonfungiblePositionManager positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    function setUp() public {
        fungibleV3LP = new FungibleV3LP(positionManager, weth, usdc, 3000);
    }

    function testName() public {
        console.log(fungibleV3LP.name());
        assertEq(fungibleV3LP.name(), "USD Coin-Wrapped Ether-0-v3LP");
    }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}