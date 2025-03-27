// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LotteryPool} from "../src/LotteryPool.sol";
import {PoolPlayHook} from "../src/PoolPlayHook.sol";
import {PoolPlayRouter} from "../src/PoolPlayRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {LinkToken} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from
    "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import "forge-std/console.sol";

contract LotteryPoolTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    VRFCoordinatorV2_5Mock public vrfCoordinator;
    LotteryPool public lotteryPool;
    PoolPlayHook public hook;
    PoolPlayRouter public router;
    IPoolManager public poolManager;
    MockERC20 public token0;
    MockERC20 public token1;
    LinkToken public linkToken;
    PoolKey public poolkey;
    PoolId public poolId;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");

    event LotteryCreated(uint256 indexed lotteryId, PoolId poolId, address token);
    event FeeDeposited(uint256 indexed lotteryId, uint256 epoch, uint256 amount, address swapper);
    event WinnerSelected(uint256 indexed lotteryId, uint256 indexed epoch, address indexed winner, uint256 prize);
    event EpochStarted(uint256 indexed lotteryId, uint256 epoch, uint40 startTime, uint40 endTime);

    function setUp() public {
        // Deploy Uniswap V4 PoolManager and routers
        deployFreshManagerAndRouters();
        poolManager = IPoolManager(manager);

        // Deploy tokens
        token0 = new MockERC20("Token0", "TKN0", 18);
        token1 = new MockERC20("Token1", "TKN1", 18);
        linkToken = new LinkToken();

        // Deploy VRF Coordinator Mock
        vrfCoordinator = new VRFCoordinatorV2_5Mock(1e6, 10e6, 1e18);

        // Deploy and configure LotteryPool
        lotteryPool = new LotteryPool(address(vrfCoordinator));
        lotteryPool.setLinkToken(address(linkToken));

        // Fund LotteryPool with LINK correctly
        linkToken.grantMintAndBurnRoles(address(this));
        uint256 linkAmount = 20 ether;
        linkToken.mint(address(lotteryPool), linkAmount);
        vm.prank(address(lotteryPool));
        linkToken.approve(address(vrfCoordinator), linkAmount);
        vrfCoordinator.fundSubscription(lotteryPool.subscriptionId(), linkAmount);

        // Deploy PoolPlayHook with precomputed address
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        address hookAddress = address(flags);

        deployCodeTo("PoolPlayHook.sol", abi.encode(poolManager, address(0), address(lotteryPool)), hookAddress);
        hook = PoolPlayHook(payable(hookAddress));

        // Deploy PoolPlayRouter
        router = new PoolPlayRouter(address(poolManager), address(hook));

        // Update hook’s allowedRouter
        vm.store(address(hook), keccak256(abi.encode("allowedRouter")), bytes32(uint256(uint160(address(router)))));

        // Approve tokens for hook and router
        token0.approve(address(hook), type(uint256).max);
        token1.approve(address(hook), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);

        // Initialize Uniswap V4 pool
        (key,) =
            initPool(Currency.wrap(address(token0)), Currency.wrap(address(token1)), hook, 3000, 60, SQRT_PRICE_1_1);
        poolId = key.toId();
        poolkey = key;

        // Initialize pool in hook via router (assumes onlyAllowedRouter)
        vm.prank(address(router));
        hook.initializePool(poolId, 100, 1 days, 1);

        // Add initial liquidity
        vm.startPrank(owner);
        token0.mint(owner, 20 ether); // Mint tokens to owner
        token1.mint(owner, 20 ether);
        token0.approve(address(modifyLiquidityRouter), type(uint256).max); // Approve router
        token1.approve(address(modifyLiquidityRouter), type(uint256).max);
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
        vm.stopPrank();

        // Mint tokens for user1
        token0.mint(user1, 1000 ether);
        token1.mint(user1, 1000 ether);

        // Set approvals for user1
        vm.startPrank(user1);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        token0.approve(address(poolManager), type(uint256).max);
        token1.approve(address(poolManager), type(uint256).max);
        token0.approve(address(lotteryPool), type(uint256).max);
        vm.stopPrank();

        vm.prank(address(hook));
        token0.approve(address(lotteryPool), type(uint256).max);
    }

    function test_CreateLottery() public {
        vm.expectEmit(true, true, false, true);
        emit LotteryCreated(1, poolId, address(token0));

        vm.prank(user1);
        uint256 lotteryId = lotteryPool.createLottery(poolId, address(token0), 1 days, 100);

        (PoolId poolid, address token, uint48 distributionInterval, uint24 lotteryFeeBps, uint256 currentEpoch) =
            lotteryPool.getLottery(lotteryId);

        assertEq(lotteryId, 1);
        assertEq(PoolId.unwrap(poolid), PoolId.unwrap(poolId));
        assertEq(token, address(token0));
        assertEq(distributionInterval, 1 days);
        assertEq(lotteryFeeBps, 100);
        assertEq(currentEpoch, 1);
    }

    function test_DepositFee_ETH() public {
        vm.prank(user1);
        uint256 lotteryId = lotteryPool.createLottery(poolId, address(0), 1 days, 100);

        uint256 amount = 1 ether;
        vm.deal(user1, amount);
        vm.prank(user1);
        lotteryPool.depositFee{value: amount}(lotteryId, amount, user1);

        (uint256 totalFees,,) = lotteryPool.getEpoch(lotteryId, 1);
        address[] memory participants = lotteryPool.getEpochParticipants(lotteryId, 1);

        assertEq(totalFees, amount);
        assertEq(participants.length, 1);
        assertEq(participants[0], user1);
    }

    function test_DepositFee_ERC20() public {
        vm.prank(user1);
        uint256 lotteryId = lotteryPool.createLottery(poolId, address(token0), 1 days, 100);

        uint256 amount = 1 ether;
        vm.prank(user1);
        token0.approve(address(lotteryPool), amount);
        vm.prank(user1);
        lotteryPool.depositFee(lotteryId, amount, user1);

        (uint256 totalFees,,) = lotteryPool.getEpoch(lotteryId, 1);
        address[] memory participants = lotteryPool.getEpochParticipants(lotteryId, 1);

        assertEq(totalFees, amount);
        assertEq(participants.length, 1);
        assertEq(participants[0], user1);
    }

    function test_UpdateLottery_NewEpoch() public {
        vm.prank(user1);
        uint256 lotteryId = lotteryPool.createLottery(poolId, address(0), 1 days, 100);

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(user1);
        lotteryPool.updateLottery(lotteryId);

        (,,,, uint256 currentEpoch) = lotteryPool.getLottery(lotteryId);
        assertEq(currentEpoch, 2);

        (, uint40 startTime, uint40 endTime) = lotteryPool.getEpoch(lotteryId, 2);
        assertEq(startTime, uint40(block.timestamp));
        assertEq(endTime, uint40(block.timestamp + 1 days));
    }

    function test_SimulateSwapAndFee() public {
        vm.prank(user1);
        uint256 lotteryId = lotteryPool.createLottery(poolId, address(token0), 1 days, 100);

        // Direct depositFee test
        vm.startPrank(user1);
        token0.approve(address(lotteryPool), 0.01e18);
        lotteryPool.depositFee(lotteryId, 0.01e18, user1);
        (uint256 totalFees,,) = lotteryPool.getEpoch(lotteryId, 1);
        vm.stopPrank();

        vm.startPrank(user1);
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -1 ether,
            sqrtPriceLimitX96: SQRT_PRICE_1_1 - 1
        });
        router.swap(poolkey, params, user1, 100);
        vm.stopPrank();

        (totalFees,,) = lotteryPool.getEpoch(lotteryId, 1);
        address[] memory participants = lotteryPool.getEpochParticipants(lotteryId, 1);

        assertGt(totalFees, 0);
        assertEq(participants.length, 1);
        assertEq(participants[0], user1);
    }
}
