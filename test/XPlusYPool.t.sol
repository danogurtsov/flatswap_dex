// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/XPlusYPool.sol";
import "../src/libraries/SimpleToken.sol";

contract XPlusYTest is Test {

    XPlusYPool public pool;
    SimpleToken public usdz;
    SimpleToken public usdw;
    SimpleToken public usdb;
    SimpleToken public etho;
    SimpleToken public ethy;

    address owner = 0x738390bB2EC2b545F97A4A7158c79C5Ae595228e;
    address lpOne = 0xb4ffb0f4e1e79351a27890f651ad5E6696E037D1; // lp on setup
    address lpTwo = 0x2Bd93343DED12d371A49e3fB205846862A74AF39; // lp on setup
    address tester = 0xf0b38A993C631E7f58c9dcfFeFA227257a126f7A;

    uint marketUSD;
    uint marketETH;

    function setUp() public {

        vm.startPrank(owner);

        pool = new XPlusYPool();

        // init market for USD

        usdz = new SimpleToken("USDZ", "USDZ");
        usdw = new SimpleToken("USDW", "USDW");
        usdb = new SimpleToken("USDB", "USDB");

        marketUSD = pool.initNewMarket(address(usdz));
        pool.allowNewTokenForMarket(marketUSD, address(usdw));
        pool.allowNewTokenForMarket(marketUSD, address(usdb));

        // init market for ETH

        etho = new SimpleToken("ETHO", "ETHO");
        ethy = new SimpleToken("ETHY", "ETHY");

        marketETH = pool.initNewMarket(address(etho));
        pool.allowNewTokenForMarket(marketETH, address(ethy));

        // mint token balances for LPs

        address mintTarget;
        uint mintAmount;
        
        mintAmount = 100_000 * (10**18);

        mintTarget = lpOne;
        usdz.mint(mintTarget, mintAmount);
        usdw.mint(mintTarget, mintAmount);
        usdb.mint(mintTarget, mintAmount);

        mintTarget = lpTwo;
        usdz.mint(mintTarget, mintAmount);
        usdw.mint(mintTarget, mintAmount);
        usdb.mint(mintTarget, mintAmount);

        mintTarget = tester;
        usdz.mint(mintTarget, mintAmount);
        usdw.mint(mintTarget, mintAmount);
        usdb.mint(mintTarget, mintAmount);

        mintAmount = 5 * (10**18);

        mintTarget = lpOne;
        etho.mint(mintTarget, mintAmount);
        ethy.mint(mintTarget, mintAmount);

        mintTarget = lpTwo;
        etho.mint(mintTarget, mintAmount);
        ethy.mint(mintTarget, mintAmount);

        mintTarget = tester;
        etho.mint(mintTarget, mintAmount);
        ethy.mint(mintTarget, mintAmount);

        // fund USD market - LP One

        address lp;
        address tokenDeposited;
        uint amountDeposited;
        uint amountDepositedAccumulated;
        uint market;

        lp = lpOne;
        vm.stopPrank();
        vm.startPrank(lp);
        amountDepositedAccumulated = 0;
        
        market = marketUSD;
        amountDeposited = 40_000 * (10**18);
        tokenDeposited = address(usdz);
            IERC20(tokenDeposited).approve(address(pool),amountDeposited);
            pool.deposit(market, tokenDeposited, amountDeposited);
            amountDepositedAccumulated += amountDeposited;
            require(pool.balanceLP(market, lp) == amountDepositedAccumulated, "Test: LP One failed USDZ deposit");

        market = marketUSD;
        amountDeposited = 30_000 * (10**18);
        tokenDeposited = address(usdw);
            IERC20(tokenDeposited).approve(address(pool),amountDeposited);
            pool.deposit(market, tokenDeposited, amountDeposited);
            amountDepositedAccumulated += amountDeposited;
            require(pool.balanceLP(market, lp) == amountDepositedAccumulated, "Test: LP One failed USDW deposit");
        
        market = marketUSD;
        amountDeposited = 20_000 * (10**18);
        tokenDeposited = address(usdb);
            IERC20(tokenDeposited).approve(address(pool),amountDeposited);
            pool.deposit(market, tokenDeposited, amountDeposited);
            amountDepositedAccumulated += amountDeposited;
            require(pool.balanceLP(market, lp) == amountDepositedAccumulated, "Test: LP One failed USDB deposit");

        // fund USD market - LP Two

        lp = lpTwo;
        vm.stopPrank();
        vm.startPrank(lp);
        amountDepositedAccumulated = 0;

        market = marketUSD;
        amountDeposited = 10_000 * (10**18);
        tokenDeposited = address(usdz);
            IERC20(tokenDeposited).approve(address(pool),amountDeposited);
            pool.deposit(market, tokenDeposited, amountDeposited);
            amountDepositedAccumulated += amountDeposited;
            require(pool.balanceLP(market, lp) == amountDepositedAccumulated, "Test: LP Two failed USDZ deposit");

        market = marketUSD;
        amountDeposited = 10_000 * (10**18);
        tokenDeposited = address(usdw);
            IERC20(tokenDeposited).approve(address(pool),amountDeposited);
            pool.deposit(market, tokenDeposited, amountDeposited);
            amountDepositedAccumulated += amountDeposited;
            require(pool.balanceLP(market, lp) == amountDepositedAccumulated, "Test: LP Two failed USDZ deposit");
        
        market = marketUSD;
        amountDeposited = 5_000 * (10**18);
        tokenDeposited = address(usdb);
            IERC20(tokenDeposited).approve(address(pool),amountDeposited);
            pool.deposit(market, tokenDeposited, amountDeposited);
            amountDepositedAccumulated += amountDeposited;
            require(pool.balanceLP(market, lp) == amountDepositedAccumulated, "Test: LP Two failed USDZ deposit");
    }

    function test_DeployAndDeposits() public {
        // Will fail on reverts in Setup, in fact checks Deploy + First Deposits
        assertEq(true, true);
    }

    function test_lpEarnOnSwapsCorrectly() public {

        // 1. Make swap

        vm.stopPrank();
        vm.startPrank(tester);

        uint market = marketUSD;

        uint swapAmountIn = 5_000 * (10**18);
        usdz.approve(address(pool),swapAmountIn);
        
        uint amountOutBefore = usdw.balanceOf(tester);
        uint invariantBefore = pool.invariant(market);

        pool.swap(market, address(usdz), address(usdw), swapAmountIn);

        uint amountOutAfter = usdw.balanceOf(tester);
        uint invariantAfter = pool.invariant(market);

        uint fee =  swapAmountIn * pool.feeRate() / 10_000;

        assertEq(swapAmountIn, amountOutAfter - amountOutBefore + fee, "Swap fee accrued wrong for user");
        assertEq(fee, invariantAfter - invariantBefore, "Fee accrued to invariant wrong");

        // 2. Check that LP could earn fee

        vm.stopPrank();
        vm.startPrank(lpTwo);

        uint lpOneBalance = pool.balanceLP(marketUSD, lpOne);
        uint lpTwoBalance = pool.balanceLP(marketUSD, lpTwo);

        uint feeWithdrawnExpected = fee * lpTwoBalance / (lpOneBalance + lpTwoBalance);

        uint balanceOutBefore = usdz.balanceOf(lpTwo);
        pool.withdraw(marketUSD, address(usdz));
        uint balanceOutAfter = usdz.balanceOf(lpTwo);

        uint feeWithdrawnFact = balanceOutAfter - balanceOutBefore - lpTwoBalance;

        assertEq(feeWithdrawnFact, feeWithdrawnExpected, "LP withdrew wrong fee as reward");

    }





}
