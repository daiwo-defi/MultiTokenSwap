// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @notice Using for manage pool details
 * @dev Helps manage info about pool details
 * @param tokenZeroth Address of zeroth token at pool, sorted by ascending order between incoming tokens sequence
 * @param tokenFirst Address of first token at pool, sorted by ascending order between incoming tokens sequence
 * @param exchangeRateZerothToFirst Exchange rate per one zeroth token in first tokens amount
 * @param exchangeRateFirstToZeroth Exchange rate per one first token in zeroth tokens amount
 */
struct PoolDetails {
    address tokenZeroth;
    address tokenFirst;
    uint256 exchangeRateZerothToFirst;
    uint256 exchangeRateFirstToZeroth;
}

/**
 * @dev Reverting while one of the token in tokens sequence are the same
 * @param tokenA Represent the first token in tokens sequence
 * @param tokenB Represent the second token in tokens sequence
 */
error TokensMustBeDifferent(address tokenA, address tokenB);

/**
 * @dev Reverting while pool with exact incoming id doesn't not exists
 * @param id Representing the incoming pool id based on tokens sequence in ascending order, encoded in bytes32 by keccak256
 * @param tokenA Represent the first token in tokens sequence
 * @param tokenB Represent the second token in tokens sequence
 */
error PoolNotExists(bytes32 id, address tokenA, address tokenB);

/**
 * @dev Reverting while pool with exact incoming id already exists
 * @param id Representing the incoming pool id based on tokens sequence in ascending order, encoded in bytes32 by keccak256
 * @param tokenA Represent the first token in tokens sequence
 * @param tokenB Represent the second token in tokens sequence
 */
error PoolAlreadyExists(bytes32 id, address tokenA, address tokenB);

/**
 * @dev Reverting while one of the token in tokens sequence are zero address
 * @param tokenA Represent the first token in tokens sequence
 * @param tokenB Represent the second token in tokens sequence
 */
error ZeroAddressesNotAllowed(address tokenA, address tokenB);

/**
 * @dev Reverting while one of the incoming amount is zero
 * @param target Represent the token address where amount is zero
 */
error ZeroAmountNotAllowed(address target);

/**
 * @dev Reverting while one of the incoming calculations is not possible
 * @param target Represent the token address where amount in is zero
 * @param amountIn Amount of incoming tokens
 * @param amountOut Amount of outgoing tokens
 */
error ImpossibleOperation(address target, uint256 amountIn, uint256 amountOut);

/**
 * @dev Reverting while not enough balance for operation
 * @param target Balance owner address
 * @param token Token address where balance is not enough
 * @param amount Amount that is required for operation
 * @param balance Current balance of the target address
 */
error InsufficientBalance(
    address target,
    address token,
    uint256 amount,
    uint256 balance
);

/**
 * @dev Reverting while one of the values of rate is not correct
 */
error IncorrectExchangeRate();

/**
 * @author daiwo
 * @title Abstract layer for MultiTokenSwap contract
 * @notice This contract is an abstract layer for the MultiTokenSwap contract, which allows for swapping between multiple tokens
 * @custom:security-contact owner@daiwo.me
 */
interface IMultiTokenSwap {
    /**
     * @notice Pause the contract
     * @dev Helps temporary to stop all the contract functions
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     * @dev Helps recover the contract from paused state
     */
    function unpause() external;

    /**
     * @notice Withdraw tokens from the contract by the admin
     * @dev Helps to withdraw tokens from the contract by the admin
     * @param token Address of the token that will be withdrawn
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(address token, uint256 amount) external;

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
    )
        external
        pure
        returns (bytes32 id, address tokenZeroth, address tokenFirst);

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
    )
        external
        pure
        returns (
            uint256 exchangeRateZerothToFirst,
            uint256 exchangeRateFirstToZeroth
        );

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
    ) external;

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
    ) external;

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
    ) external pure returns (uint256 amount);

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
    ) external;
}
