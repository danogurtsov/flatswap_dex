// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";

interface FlashloanReceiver {
    function onFlashloanCall() external ;
}

contract XPlusYPool {

    using SafeERC20 for IERC20;
   
     struct Market {
        mapping (address => bool) tokens;
        mapping (address => uint256) reserves;
        uint256 invariant;
        uint256 decimals;
        mapping (address => uint256) balancesLP;
        uint256 totalSupplyLP;
    }

    mapping (uint256 => Market) public markets;
    uint256 marketNonce;
    address public gov;

    uint256 public feeRate = 300; // 0.3 %

    event RouteStatusChanged(address tokenFrom, address tokenTo, bool statusUpdated);
    event Swap(uint256 market, address tokenFrom, address tokenTo, uint256 amountIn, uint256 amountOut);
    event Deposit(uint256 market, address tokenIn, uint256 amountIn, uint256 mintedLP);
    event Withdraw(uint256 market, address tokenOut, uint256 amountOut, uint256 burntLP);

    constructor() {
        gov = msg.sender;
    }

    
    function initNewMarket(address _firstToken) public returns (uint marketId) {
        require(msg.sender == gov, "XPlusY: msg.sender != gov");
        uint256 _marketId = marketNonce;
        Market storage market = markets[_marketId];
        market.tokens[_firstToken] = true;
        market.decimals = IERC20(_firstToken).decimals();
        marketNonce += 1;
        return marketId;
    }

    function allowNewTokenForMarket(uint256 _marketId, address _token) public returns (bool){
        Market storage market = markets[_marketId];
        require(msg.sender == gov, "XPlusY: msg.sender != gov");
        require(IERC20(_token).decimals() == market.decimals);

        market.tokens[_token] = true;
        return true;
    }


    function deposit (uint256 _marketId, address _tokenIn, uint256 _amountIn) public returns (bool) {
        Market storage market = markets[_marketId];
        require(market.tokens[_tokenIn], "XPlusY: _tokenIn is not allowed for this Market");

        // receive tokens
        IERC20 token = IERC20(_tokenIn);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amountIn);
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 amountIn = balanceAfter - balanceBefore;
        
        uint256 lpMinted = amountIn * (market.totalSupplyLP + amountIn) / (market.invariant + amountIn);   
        
        market.totalSupplyLP += lpMinted;
        market.balancesLP[msg.sender] += lpMinted;

        market.invariant += amountIn;
        market.reserves[_tokenIn] += amountIn;

        emit Deposit(_marketId, _tokenIn, _amountIn, lpMinted);
        return true;
    }

    function withdraw (uint256 _marketId, address _tokenOut) public returns (bool) {
        Market storage market = markets[_marketId];
        require(market.tokens[_tokenOut], "XPlusY: _tokenOut is not allowed for this Market");

        // send tokens
        uint lpBalanceToBurn = market.balancesLP[msg.sender];
        uint amountOut = lpBalanceToBurn * market.invariant / market.totalSupplyLP;
        IERC20(_tokenOut).safeTransfer(msg.sender, amountOut);

        market.totalSupplyLP -= lpBalanceToBurn;
        market.balancesLP[msg.sender] = 0;

        market.invariant -= amountOut;
        market.reserves[_tokenOut] += amountOut;

        emit Withdraw(_marketId, _tokenOut, amountOut, lpBalanceToBurn);
        return true;
    }

    function swap (uint256 _marketId, address _tokenIn, address _tokenOut, uint256 _amountIn) public {
        Market storage market = markets[_marketId];
        require(market.tokens[_tokenIn], "XPlusY: _tokenIn is not allowed for this Market");
        require(market.tokens[_tokenOut], "XPlusY: _tokenOut is not allowed for this Market");

        IERC20 token = IERC20(_tokenIn);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amountIn);
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 amountIn = balanceAfter - balanceBefore;

        uint256 fee = amountIn * feeRate / 10_000;
        uint256 amountOut = amountIn - fee;
        IERC20(_tokenOut).safeTransfer(msg.sender, amountOut);

        market.reserves[_tokenIn] += amountIn;
        market.reserves[_tokenOut] -= amountOut;
        market.invariant += fee;

        emit Swap(_marketId, _tokenIn, _tokenOut, amountIn, amountOut);
    }

    function flashloan (address _tokenOut, uint256 _amountOut, address _receiver) public {
        
        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(address(this));

        IERC20(_tokenOut).safeTransfer(_receiver, _amountOut);
        FlashloanReceiver(_receiver).onFlashloanCall();

        uint256 balanceAfter = IERC20(_tokenOut).balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "XPlusY: flashloan not repaid");
    }

    function balanceLP (uint _marketId, address _lpHolder) public view returns (uint) {
        Market storage market = markets[_marketId];
        return market.balancesLP[_lpHolder];
    }

    function invariant (uint _marketId) public view returns (uint) {
        Market storage market = markets[_marketId];
        return market.invariant;
    }

}
