// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IMultiTokenSwap, TokensMustBeDifferent, PoolDetails, PoolNotExists, PoolAlreadyExists, ZeroAddressesNotAllowed, ZeroAmountNotAllowed, ImpossibleOperation, InsufficientBalance, IncorrectExchangeRate} from "./IMultiTokenSwap.sol";

/**
 * @author daiwo
 * @title The implementation of the IMultiTokenSwap interface
 * @notice This contract allows for swapping between multiple tokens based on their pools details
 * @custom:security-contact owner@daiwo.me
 */
contract MultiTokenSwap is Ownable, ReentrancyGuard, Pausable, IMultiTokenSwap {
    using SafeERC20 for ERC20;

    uint256 public constant DECIMALS = 18;
    uint128 public constant MAX_RATE_THRESHOLD = 1e30;

    mapping(bytes32 => PoolDetails) private poolIdsToDetails;

    /**
     * @notice Emitted when new pool is added
     * @dev Helps to detect new pool adding
     * @param tokenZeroth Address of zeroth token at pool, sorted by ascending order between incoming tokens sequence
     * @param tokenFirst Address of first token at pool, sorted by ascending order between incoming tokens sequence
     */
    event PoolAdded(address indexed tokenZeroth, address indexed tokenFirst);

    /**
     * @notice Emitted when the exchange rates for a token pool are updated
     * @dev Helps to detect new state of exchange rates for specific token pool
     * @param tokenZeroth Address of zeroth token at pool, sorted by ascending order between incoming tokens sequence
     * @param tokenFirst Address of first token at pool, sorted by ascending order between incoming tokens sequence
     * @param exchangeRateZerothToFirst Exchange rate per one zeroth token in first tokens amount
     * @param exchangeRateFirstToZeroth Exchange rate per one first token in zeroth tokens amount
     */
    event ExchangeRateUpdated(
        address indexed tokenZeroth,
        address indexed tokenFirst,
        uint256 exchangeRateZerothToFirst,
        uint256 exchangeRateFirstToZeroth
    );

    /**
     * @notice Emitted when the admin of smart contract withdraws some tokens
     * @dev Helps to detect when the admin of smart contract withdraws some tokens
     * @param admin EOA address of the admin
     * @param token Address of the token that was withdrawn
     * @param amount Amount of tokens withdrawn
     */
    event Withdraw(
        address indexed admin,
        address indexed token,
        uint256 amount
    );

    /**
     * @notice Emitted when the user swaps tokens
     * @dev Helps to detect when the user swaps tokens
     * @param user EOA address of the user
     * @param tokenIn Address of the incoming token to swap
     * @param tokenOut Address of the outgoing token to swap
     * @param amountIn Amount of the incoming token to swap
     * @param amountOut Amount of the outgoing token to swap
     */
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /**
     * @notice Once call when the contract is creating
     * @dev Helps to initialize initial contract owner
     */
    constructor() Ownable(_msgSender()) {}

    /**
     * @notice Pause the contract
     * @dev Helps temporary to stop all the contract functions
     */
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Unpause the contract
     * @dev Helps recover the contract from paused state
     */
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Withdraw tokens from the contract by the admin
     * @dev Helps to withdraw tokens from the contract by the admin
     * @param token Address of the token that will be withdrawn
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(
        address token,
        uint256 amount
    ) public onlyOwner whenNotPaused {
        address sender = _msgSender();

        if (amount == 0) {
            revert ZeroAmountNotAllowed(token);
        }

        uint256 balance = ERC20(token).balanceOf(address(this));

        if (amount > balance) {
            revert InsufficientBalance(sender, token, amount, balance);
        }

        ERC20(token).safeTransfer(sender, amount);

        emit Withdraw(sender, token, amount);
    }

    /**
     * @notice Allows to get exact pool id based on tokens sequence in ascending order
     * @dev Helps to get pool id based on tokens sequence in ascending order
     * @param tokenA Address of the first token in tokens sequence
     * @param tokenB Address of the second token in tokens sequence
     * @return id Representing the incoming pool id based on tokens sequence in ascending order, encoded in bytes32 by keccak256
     * @return tokenZeroth Address of zeroth token at pool, sorted by ascending order between incoming tokens sequence
     * @return tokenFirst Address of first token at pool, sorted by ascending order between incoming tokens sequence
     */
    function getPoolId(
        address tokenA,
        address tokenB
    ) public pure returns (bytes32, address, address) {
        if (tokenA == tokenB) {
            revert TokensMustBeDifferent(tokenA, tokenB);
        }

        if (tokenA == address(0) || tokenB == address(0)) {
            revert ZeroAddressesNotAllowed(tokenA, tokenB);
        }

        (address tokenZeroth, address tokenFirst) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        bytes32 id = keccak256(abi.encodePacked(tokenZeroth, tokenFirst));

        return (id, tokenZeroth, tokenFirst);
    }

    /**
     * @notice Allows to get exchange rates based on tokens positions in sequence in ascending order
     * @dev Helps to get exchange rates based on tokens positions in sequence in ascending order
     * @param tokenA Address of the first token in tokens sequence
     * @param tokenZeroth Address of zeroth token at pool, sorted by ascending order between incoming tokens sequence
     * @param exchangeRateToTokenB Exchange rate per one token B in A tokens amount
     * @param exchangeRateToTokenA Exchange rate per one token A in B tokens amount
     * @return exchangeRateZerothToFirst Exchange rate per one zeroth token in first tokens amount
     * @return exchangeRateFirstToZeroth Exchange rate per one first token in zeroth tokens amount
     */
    function getExchangeRatesBasedOnTokensSequence(
        address tokenA,
        address tokenZeroth,
        uint256 exchangeRateToTokenB,
        uint256 exchangeRateToTokenA
    ) public pure returns (uint256, uint256) {
        uint256 exchangeRateZerothToFirst;
        uint256 exchangeRateFirstToZeroth;

        if (tokenA == tokenZeroth) {
            exchangeRateZerothToFirst = exchangeRateToTokenB;
            exchangeRateFirstToZeroth = exchangeRateToTokenA;
        } else {
            exchangeRateZerothToFirst = exchangeRateToTokenA;
            exchangeRateFirstToZeroth = exchangeRateToTokenB;
        }

        if (
            exchangeRateZerothToFirst < 1 ||
            exchangeRateFirstToZeroth < 1 ||
            exchangeRateZerothToFirst > MAX_RATE_THRESHOLD ||
            exchangeRateFirstToZeroth > MAX_RATE_THRESHOLD
        ) {
            revert IncorrectExchangeRate();
        }

        return (exchangeRateZerothToFirst, exchangeRateFirstToZeroth);
    }

    /**
     * @notice Allows to add new pool based on tokens positions in sequence in ascending order
     * @dev Helps to add new pool based on tokens positions in sequence in ascending order
     * @param tokenA Address of the first token in tokens sequence
     * @param tokenB Address of the second token in tokens sequence
     * @param exchangeRateToTokenB Exchange rate per one token B in A tokens amount
     * @param exchangeRateToTokenA Exchange rate per one token A in B tokens amount
     */
    function addNewPool(
        address tokenA,
        address tokenB,
        uint256 exchangeRateToTokenB,
        uint256 exchangeRateToTokenA
    ) external onlyOwner {
        (bytes32 id, address tokenZeroth, address tokenFirst) = getPoolId(
            tokenA,
            tokenB
        );

        PoolDetails memory poolDetails = poolIdsToDetails[id];

        if (poolDetails.tokenZeroth != address(0)) {
            revert PoolAlreadyExists(id, tokenZeroth, tokenFirst);
        }

        (
            uint256 exchangeRateZerothToFirst,
            uint256 exchangeRateFirstToZeroth
        ) = getExchangeRatesBasedOnTokensSequence(
                tokenA,
                tokenZeroth,
                exchangeRateToTokenB,
                exchangeRateToTokenA
            );

        poolIdsToDetails[id] = PoolDetails({
            tokenZeroth: tokenZeroth,
            tokenFirst: tokenFirst,
            exchangeRateZerothToFirst: exchangeRateZerothToFirst,
            exchangeRateFirstToZeroth: exchangeRateFirstToZeroth
        });

        emit PoolAdded(tokenZeroth, tokenFirst);
        emit ExchangeRateUpdated(
            tokenZeroth,
            tokenFirst,
            exchangeRateZerothToFirst,
            exchangeRateFirstToZeroth
        );
    }

    /**
     * @notice Allows to update existing pool details
     * @dev Helps to update existing pool details
     * @param tokenA Address of the first token in tokens sequence
     * @param tokenB Address of the second token in tokens sequence
     * @param exchangeRateToTokenB Exchange rate per one token B in A tokens amount
     * @param exchangeRateToTokenA Exchange rate per one token A in B tokens amount
     */
    function updateExchangeRate(
        address tokenA,
        address tokenB,
        uint256 exchangeRateToTokenB,
        uint256 exchangeRateToTokenA
    ) external onlyOwner {
        (bytes32 id, address tokenZeroth, address tokenFirst) = getPoolId(
            tokenA,
            tokenB
        );

        if (poolIdsToDetails[id].tokenZeroth == address(0)) {
            revert PoolNotExists(id, tokenZeroth, tokenFirst);
        }

        (
            uint256 exchangeRateZerothToFirst,
            uint256 exchangeRateFirstToZeroth
        ) = getExchangeRatesBasedOnTokensSequence(
                tokenA,
                tokenZeroth,
                exchangeRateToTokenB,
                exchangeRateToTokenA
            );

        poolIdsToDetails[id]
            .exchangeRateZerothToFirst = exchangeRateZerothToFirst;
        poolIdsToDetails[id]
            .exchangeRateFirstToZeroth = exchangeRateFirstToZeroth;

        emit ExchangeRateUpdated(
            tokenZeroth,
            tokenFirst,
            exchangeRateZerothToFirst,
            exchangeRateFirstToZeroth
        );
    }

    /**
     * @notice Allows to get amount based on price and decimals
     * @dev Helps to get amount based on price and decimals
     * @param price Price of the token
     * @param decimals Decimals of the token
     * @return amount Amount of the token
     */
    function getRawAmount(
        uint256 price,
        uint256 decimals
    ) public pure returns (uint256) {
        if (decimals == DECIMALS) {
            return price;
        }

        if (decimals < DECIMALS) {
            return price / (10 ** (DECIMALS - decimals));
        }

        return price * (10 ** (decimals - DECIMALS));
    }

    /**
     * @notice Allows to swap tokens for tokens
     * @dev Helps to swap tokens for tokens
     * @param tokenIn Address of the incoming token that swap processes in
     * @param tokenOut Address of the outcoming token that swap processes out
     * @param amountIn Amount in tokenIn units that will be swapped
     */
    function swapTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external nonReentrant whenNotPaused {
        address sender = _msgSender();
        (bytes32 id, address tokenZeroth, address tokenFirst) = getPoolId(
            tokenIn,
            tokenOut
        );

        PoolDetails memory poolDetails = poolIdsToDetails[id];

        if (poolDetails.tokenZeroth == address(0)) {
            revert PoolNotExists(id, tokenZeroth, tokenFirst);
        }

        if (amountIn == 0) {
            revert ZeroAmountNotAllowed(tokenIn);
        }

        uint256 exchangeRate = tokenIn == poolDetails.tokenZeroth
            ? poolDetails.exchangeRateZerothToFirst
            : poolDetails.exchangeRateFirstToZeroth;

        uint256 amountOut = (amountIn * exchangeRate) / 10 ** DECIMALS;

        uint8 decimalsOfTokenIn = ERC20(tokenIn).decimals();
        uint8 decimalsOfTokenOut = ERC20(tokenOut).decimals();

        uint256 balanceIn = ERC20(tokenIn).balanceOf(sender);
        uint256 balanceOut = ERC20(tokenOut).balanceOf(address(this));

        uint256 rawAmountIn = getRawAmount(amountIn, decimalsOfTokenIn);
        uint256 rawAmountOut = getRawAmount(amountOut, decimalsOfTokenOut);

        if (rawAmountIn < 1) {
            revert ImpossibleOperation(tokenIn, rawAmountIn, rawAmountOut);
        }

        if (balanceIn < rawAmountIn) {
            revert InsufficientBalance(sender, tokenIn, rawAmountIn, balanceIn);
        }

        if (rawAmountOut < 1) {
            revert ImpossibleOperation(tokenOut, rawAmountIn, rawAmountOut);
        }

        if (balanceOut < rawAmountOut) {
            revert InsufficientBalance(
                address(this),
                tokenOut,
                rawAmountOut,
                balanceOut
            );
        }

        ERC20(tokenOut).safeTransfer(sender, rawAmountOut);
        ERC20(tokenIn).safeTransferFrom(sender, address(this), rawAmountIn);

        emit Swap(sender, tokenIn, tokenOut, amountIn, amountOut);
    }
}
