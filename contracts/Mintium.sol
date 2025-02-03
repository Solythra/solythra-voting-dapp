// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface INFTMarketplace {
    function mintNFT(address to, uint256 amount) external;
}

interface ILiquidityPool {
    function depositLiquidity(address user, uint256 amount) external;
    function withdrawRewards(address user) external;
}

interface IMultiSigTreasury {
    function approveTransaction(address recipient, uint256 amount) external;
}

contract Mintium is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    
    uint256 public transactionFee = 2; // 2% Transaction Fee
    uint256 public stakingRewardRate = 5; // 5% Staking Reward Rate
    uint256 public totalStaked; // Total Staked MNTM

    address public treasury;
    address public nftMarketplace;
    address public liquidityPool;
    
    mapping(address => uint256) public stakingBalances;
    mapping(address => uint256) public stakingStartTime;
    mapping(address => bool) public isExcludedFromFees;

    IMultiSigTreasury public treasuryContract;

    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount);
    event FeeUpdated(uint256 newFee);
    event StakingRewardUpdated(uint256 newRewardRate);
    event TreasuryUpdated(address newTreasury);
    event NFTMinted(address indexed user, uint256 amount);
    event LiquidityDeposited(address indexed user, uint256 amount);
    event LiquidityWithdrawn(address indexed user, uint256 amount);
    event ExcludedFromFees(address indexed user, bool isExcluded);

    /** ✅ Constructor: Set Initial Owner & Treasury */
    constructor(address initialOwner, address _treasury) 
        ERC20("Mintium", "MNTM") 
        Ownable(initialOwner) 
    {
        _mint(initialOwner, 100_000_000 * 10 ** decimals());
        treasuryContract = IMultiSigTreasury(_treasury);
        treasury = _treasury;  // ✅ Ensure treasury is set
        isExcludedFromFees[initialOwner] = true;
    }

    /** ✅ Fix: Override `_update` instead of `_transfer` */
    function _update(address from, address to, uint256 value) internal override {
        require(to != address(0), "Transfer to zero address is not allowed");

        if (isExcludedFromFees[from] || isExcludedFromFees[to]) {
            super._update(from, to, value);
        } else {
            uint256 feeAmount = (value * transactionFee) / 100;
            uint256 transferAmount = value - feeAmount;

            super._update(from, treasury, feeAmount); // Send fees to treasury
            super._update(from, to, transferAmount); // Send remaining to recipient
        }
    }

    /** ✅ Update Transaction Fee */
    function setTransactionFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Fee too high"); // Max 10%
        transactionFee = newFee;
        emit FeeUpdated(newFee);
    }

    /** ✅ Exclude Addresses from Fees */
    function setExcludedFromFees(address user, bool exclude) external onlyOwner {
        isExcludedFromFees[user] = exclude;
        emit ExcludedFromFees(user, exclude);
    }

    /** ✅ Set Staking Reward Rate */
    function setStakingRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 20, "Reward rate too high");
        stakingRewardRate = newRate;
        emit StakingRewardUpdated(newRate);
    }

    /** ✅ Stake Tokens */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        _transfer(msg.sender, address(this), amount);

        stakingBalances[msg.sender] += amount;
        stakingStartTime[msg.sender] = block.timestamp;
        totalStaked += amount;

        emit TokensStaked(msg.sender, amount);
    }

    /** ✅ Unstake Tokens */
    function unstake() external nonReentrant {
        require(stakingBalances[msg.sender] > 0, "No staked balance");

        uint256 amount = stakingBalances[msg.sender];
        stakingBalances[msg.sender] = 0;
        totalStaked -= amount;

        _transfer(address(this), msg.sender, amount);
        emit TokensUnstaked(msg.sender, amount);
    }

    /** ✅ Claim Staking Rewards */
    function claimStakingRewards() external nonReentrant {
        require(stakingBalances[msg.sender] > 0, "No staked balance");

        uint256 stakedDuration = block.timestamp - stakingStartTime[msg.sender];
        uint256 rewardAmount = (stakingBalances[msg.sender] * stakingRewardRate * stakedDuration) / (365 days * 100);

        _mint(msg.sender, rewardAmount);
        stakingStartTime[msg.sender] = block.timestamp;

        emit StakingRewardUpdated(stakingRewardRate);
    }

    /** ✅ Deposit Liquidity */
    function depositLiquidity(uint256 amount) external nonReentrant {
        require(liquidityPool != address(0), "Liquidity pool not set");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _transfer(msg.sender, liquidityPool, amount);
        ILiquidityPool(liquidityPool).depositLiquidity(msg.sender, amount);
        emit LiquidityDeposited(msg.sender, amount);
    }

    /** ✅ Withdraw Liquidity Rewards */
    function withdrawLiquidityRewards() external nonReentrant returns (bool) {
        require(liquidityPool != address(0), "Liquidity pool not set");
        ILiquidityPool(liquidityPool).withdrawRewards(msg.sender);
        emit LiquidityWithdrawn(msg.sender, stakingBalances[msg.sender]);
        return true;
    }
}
