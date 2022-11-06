// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/FungibleV3LP.sol";
import "dependencies/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FungibleV3LPTest is Test {
    FungibleV3LP public fungibleV3LP;

    address private constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    INonfungiblePositionManager positionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    function setUp() public {
        // fork ETH mainnet locally
        string[] memory cmds = new string[](2);
        cmds[0] = "cat";
        cmds[1] = ".api";
        bytes memory result = vm.ffi(cmds);
        string memory rpcURL = string(result);
        uint256 forkId = vm.createFork(rpcURL);
        vm.selectFork(forkId);
        vm.rollFork(forkId, 15907000);
        fungibleV3LP = new FungibleV3LP(positionManager, weth, usdc, 3000);

        // make test contract a whale
        address testContract = address(this);
        vm.startPrank(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
        IERC20(weth).transfer(testContract, 10_000e18);
        vm.stopPrank();

        vm.prank(0x55FE002aefF02F77364de339a1292923A15844B8);
        IERC20(usdc).transfer(testContract, 10_000_000e6);
        vm.stopPrank();
    }

    function testNameAndSymbol() public {
        assertEq(fungibleV3LP.name(), "USDC-WETH-3000-v3LP");
        assertEq(fungibleV3LP.symbol(), "USDC-WETH-3000-v3LP");
    }

    function testAddLiquidity() public {
        // approve fungibleV3LP to spend test contract's tokens
        IERC20(weth).approve(address(fungibleV3LP), type(uint256).max);
        IERC20(usdc).approve(address(fungibleV3LP), type(uint256).max);

        uint amountADesired = 100e6;
        uint amountBDesired = 100e18;
        uint amountAMin=0;
        uint amountBMin=0;
        address to = address(this);
        uint deadline = block.timestamp;

        require(amountADesired <= IERC20(usdc).balanceOf(address(this)),'not enough token A');
        require(amountBDesired <= IERC20(weth).balanceOf(address(this)),'not enough token B');
        console.log('balanceA: %s',IERC20(usdc).balanceOf(address(this)));
        console.log('balanceB: %s',IERC20(weth).balanceOf(address(this)));
        
        assert(fungibleV3LP.balanceOf(address(this)) == 0);
        assert(IERC20(usdc).balanceOf(address(fungibleV3LP))==0);
        assert(IERC20(weth).balanceOf(address(fungibleV3LP))==0);
        
        fungibleV3LP.addLiquidity(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );

        assert(fungibleV3LP.balanceOf(address(this)) > 0);
        assert(IERC20(usdc).balanceOf(address(fungibleV3LP))==0);
        assert(IERC20(weth).balanceOf(address(fungibleV3LP))==0);
    }

    function testAddLiquidityTwoTimes() public {
        // approve fungibleV3LP to spend test contract's tokens
        IERC20(weth).approve(address(fungibleV3LP), type(uint256).max);
        IERC20(usdc).approve(address(fungibleV3LP), type(uint256).max);

        uint amountADesired = 10e6;
        uint amountBDesired = 10e18;
        uint amountAMin=0;
        uint amountBMin=0;
        address to = address(this);
        uint deadline = block.timestamp;

        fungibleV3LP.addLiquidity(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );

        //second time should be slightly different pathway...
        fungibleV3LP.addLiquidity(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );


    }


    function testRemoveLiquidity() public {
        // approve fungibleV3LP to spend test contract's tokens
        IERC20(weth).approve(address(fungibleV3LP), type(uint256).max);
        IERC20(usdc).approve(address(fungibleV3LP), type(uint256).max);

        uint amountADesired = 100e6;
        uint amountBDesired = 100e18;
        uint amountAMin=0;
        uint amountBMin=0;
        address to = address(this);
        uint deadline = block.timestamp;
        
        fungibleV3LP.addLiquidity(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );

        uint256 userLiquidity = fungibleV3LP.balanceOf(address(this));

        fungibleV3LP.approve(address(fungibleV3LP),type(uint256).max);
        fungibleV3LP.removeLiquidity(
            userLiquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );

        assert(IERC20(usdc).balanceOf(address(fungibleV3LP))==0);
        assert(IERC20(weth).balanceOf(address(fungibleV3LP))==0);
    }
}
