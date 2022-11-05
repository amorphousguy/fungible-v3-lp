
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

import "forge-std/Test.sol";
import "../src/FungibleV3LP.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "dependencies/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract FungibleV3LPTest is Test {
    FungibleV3LP public contract;

    IERC20 constant private weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant private usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    INonfungiblePositionManager positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    function setUp() public {
        contract = new FungibleV3LP(positionManager, weth, usdc, 10000);
    }

    // function testIncrement() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}