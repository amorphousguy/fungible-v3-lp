// SPDX-License-Identifier: MIT
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


// Derived from https://docs.uniswap.org/protocol/guides/providing-liquidity/the-full-contract
contract UniswapV3position is IERC721Receiver {
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    /// @notice Represents the deposit of an NFT
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    struct AmountStruc {
        uint256 amount0;
        uint256 amount1;
    }

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    constructor(INonfungiblePositionManager _nonfungiblePositionManager) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // get position information

        _createDeposit(operator, tokenId);

        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
    }


    
    /// @notice Calls the mint function defined in periphery, mints the same amount of each token.
    /// For this example we are providing 1000 DAI and 1000 USDC in liquidity
    /// @return tokenId The id of the newly minted ERC721
    /// @return liquidity The amount of liquidity for the position
    /// @return amount The amount of token0, token1
    function mintNewPosition(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickHigher,
        AmountStruc memory _amountToMint,
        AmountStruc memory _amountMin
    )
        internal
        returns (
            uint256 tokenId,
            uint128 liquidity,
            AmountStruc memory amount
        )
    {
        console.log("Transfering assets");
        // transfer tokens to contract
        if (_amountToMint.amount0 > 0)
            TransferHelper.safeTransferFrom(
                _token0,
                msg.sender,
                address(this),
                _amountToMint.amount0
            );
        if (_amountToMint.amount1 > 0)
            TransferHelper.safeTransferFrom(
                _token1,
                msg.sender,
                address(this),
                _amountToMint.amount1
            );

        console.log("approving assets");
        // Approve the position manager
        if (_amountToMint.amount0 > 0)
            TransferHelper.safeApprove(
                _token0,
                address(nonfungiblePositionManager),
                _amountToMint.amount0
            );
        if (_amountToMint.amount1 > 0)
            TransferHelper.safeApprove(
                _token1,
                address(nonfungiblePositionManager),
                _amountToMint.amount1
            );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: _token0,
                token1: _token1,
                fee: _fee,
                tickLower: _tickLower,
                tickUpper: _tickHigher,
                amount0Desired: _amountToMint.amount0,
                amount1Desired: _amountToMint.amount1,
                amount0Min: _amountMin.amount0,
                amount1Min: _amountMin.amount1,
                recipient: address(this),
                deadline: block.timestamp
            });

        console.log("Mint uniswap liquidity position");
        // Note that the pool must already exist.  Call createPool beforehand just in case
        (tokenId, liquidity, amount.amount0, amount.amount1) = nonfungiblePositionManager
            .mint(params);

        console.log("Minted uniswap liquidity position");

        // Create a deposit
        _createDeposit(msg.sender, tokenId);

        // Remove allowance and refund in both assets.
        if (amount.amount0 < _amountToMint.amount0) {
            TransferHelper.safeApprove(
                _token0,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = _amountToMint.amount0 - amount.amount0;
            TransferHelper.safeTransfer(_token0, msg.sender, refund0);
        }

        if (amount.amount1 < _amountToMint.amount1) {
            TransferHelper.safeApprove(
                _token1,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = _amountToMint.amount1 - amount.amount1;
            TransferHelper.safeTransfer(_token0, msg.sender, refund1);
        }
    }


    /// @notice Calls the mint function defined in periphery, mints the same amount of each token.
    /// For this example we are providing 1000 DAI and 1000 USDC in liquidity
    /// @return tokenId The id of the newly minted ERC721
    /// @return liquidity The amount of liquidity for the position
    /// @return amount The amount of token0, token1
    function mintNewPositionInternal(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickHigher,
        AmountStruc memory _amountToMint,
        AmountStruc memory _amountMin
    )
        internal
        returns (
            uint256 tokenId,
            uint128 liquidity,
            AmountStruc memory amount
        )
    {
      
        // Approve the position manager
        if (_amountToMint.amount0 > 0)
            TransferHelper.safeApprove(
                _token0,
                address(nonfungiblePositionManager),
                _amountToMint.amount0
            );
        if (_amountToMint.amount1 > 0)
            TransferHelper.safeApprove(
                _token1,
                address(nonfungiblePositionManager),
                _amountToMint.amount1
            );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: _token0,
                token1: _token1,
                fee: _fee,
                tickLower: _tickLower,
                tickUpper: _tickHigher,
                amount0Desired: _amountToMint.amount0,
                amount1Desired: _amountToMint.amount1,
                amount0Min: _amountMin.amount0,
                amount1Min: _amountMin.amount1,
                recipient: address(this),
                deadline: block.timestamp
            });

        // Note that the pool must already exist.  Call createPool beforehand just in case
        (tokenId, liquidity, amount.amount0, amount.amount1) = nonfungiblePositionManager
            .mint(params);

   
        // Create a deposit
        _createDeposit(msg.sender, tokenId);

    }


    /// @notice Collects the fees associated with provided liquidity
    /// @dev The contract must hold the erc721 token before it can collect fees
    /// @param tokenId The id of the erc721 token
    /// @return amount The amount of fees collected in token0, token1
    function collectAllFees(uint256 tokenId)
        internal
        returns (AmountStruc memory amount)
    {
        // Caller must own the ERC721 position, meaning it must be a deposit

        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount.amount0, amount.amount1) = nonfungiblePositionManager.collect(params);

        // send collected fee back to owner
        //_sendToOwner(tokenId, amount0, amount1);
    }


    /// @notice Increases liquidity in the current range
    /// @dev Pool must be initialized already to add liquidity
    /// @param tokenId The id of the erc721 token
    /// @param amount The amount to add of token0, token1
    function increaseLiquidityCurrentRange(
        uint256 tokenId,
        AmountStruc memory amountAdd,
        AmountStruc memory amountMin
    )
        internal
        returns (
            uint128 liquidity,
            AmountStruc memory amount
        )
    {
        TransferHelper.safeTransferFrom(
            deposits[tokenId].token0,
            msg.sender,
            address(this),
            amountAdd.amount0
        );
        TransferHelper.safeTransferFrom(
            deposits[tokenId].token1,
            msg.sender,
            address(this),
            amountAdd.amount1
        );

        TransferHelper.safeApprove(
            deposits[tokenId].token0,
            address(nonfungiblePositionManager),
            amountAdd.amount0
        );
        TransferHelper.safeApprove(
            deposits[tokenId].token1,
            address(nonfungiblePositionManager),
            amountAdd.amount1
        );

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amountAdd.amount0,
                    amount1Desired: amountAdd.amount1,
                    amount0Min: amountMin.amount0,
                    amount1Min: amountMin.amount1,
                    deadline: block.timestamp
                });

        (liquidity, amount.amount0, amount.amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);

              // Remove allowance and refund in both assets.
        if (amount.amount0 < amountAdd.amount0) {
            TransferHelper.safeApprove(
                deposits[tokenId].token0,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = amountAdd.amount0 - amount.amount0;
            TransferHelper.safeTransfer(deposits[tokenId].token0, msg.sender, refund0);
        }

        if (amount.amount1 < amountAdd.amount1) {
            TransferHelper.safeApprove(
                deposits[tokenId].token1,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = amountAdd.amount1 - amount.amount1;
            TransferHelper.safeTransfer(deposits[tokenId].token0, msg.sender, refund1);
        }
    }

 /// @notice A function that decreases the current liquidity by half. An example to show how to call the `decreaseLiquidity` function defined in periphery.
    /// @param tokenId The id of the erc721 token
    /// @return amount The amount received back in token0, token1
    function decreaseLiquidityByFactor(uint256 tokenId, uint128 decreaseLiquidityAmount)
        external
        returns (AmountStruc memory amount)
    {

        // get liquidity data for tokenId
        uint128 liquidity = deposits[tokenId].liquidity;
        require(liquidity > decreaseLiquidityAmount,'not enough liquidity in Uniswap');

        uint128 NewLiquidity = liquidity - decreaseLiquidityAmount;

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: NewLiquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount.amount0, amount.amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );


        // send collected fees to owner
        TransferHelper.safeTransfer(deposits[tokenId].token0, msg.sender, amount.amount0);
        TransferHelper.safeTransfer(deposits[tokenId].token1, msg.sender, amount.amount1);
    }


    /// @notice A function that decreases the current liquidity by half. An example to show how to call the `decreaseLiquidity` function defined in periphery.
    /// @param tokenId The id of the erc721 token
    /// @return amount The amount received back in token0, token1
    function burnPosition(uint256 tokenId)
        internal
        returns (AmountStruc memory amount)
    {
        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: 0,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount.amount0, amount.amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );
    }
}
