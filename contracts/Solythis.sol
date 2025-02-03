// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IMultiSigTreasury {
    function approveTransaction(address recipient, uint256 amount) external;
}

contract Solythis is ERC20, Ownable, ReentrancyGuard, Pausable, EIP712 {
    
    struct Proposal {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 executionTime;
        address proposer;
        address targetContract;
        bytes data;
    }

    uint256 private _proposalIds;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    mapping(address => uint256) private _stakedLYTH;
    mapping(address => uint256) private _stakeTimestamp;
    mapping(address => bool) public isWhitelisted;

    IMultiSigTreasury public treasury;
    uint256 public stakingRewardRate = 5;  // Default 5% yearly

    event ProposalCreated(uint256 proposalId, string description, address proposer);
    event Voted(uint256 proposalId, address voter, bool vote);
    event ProposalExecuted(uint256 proposalId);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event FundsApproved(address indexed recipient, uint256 amount);
    event StakingRewardUpdated(uint256 newRewardRate);
    event Whitelisted(address indexed user);
    event RemovedFromWhitelist(address indexed user);

    constructor(address initialOwner, address _treasury) 
        ERC20("Solythis", "LYTH") 
        Ownable(initialOwner) 
        EIP712("Solythis", "1") 
    {
        _mint(initialOwner, 1_000_000_000 * 10 ** decimals());
        treasury = IMultiSigTreasury(_treasury);
    }

    /** 🔹 Governance: Whitelist Management */
    function addWhitelisted(address user) external onlyOwner {
        isWhitelisted[user] = true;
        emit Whitelisted(user);
    }

    function removeWhitelisted(address user) external onlyOwner {
        isWhitelisted[user] = false;
        emit RemovedFromWhitelist(user);
    }

    /** 🔹 Governance: Create Proposal */
    function createProposal(string memory description, address targetContract, bytes memory data) external whenNotPaused {
        require(isWhitelisted[msg.sender], "Not whitelisted to create proposals");
        require(balanceOf(msg.sender) > 0, "Must hold LYTH to propose");

        uint256 proposalId = _proposalIds++;
        proposals[proposalId] = Proposal({
            id: proposalId,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            executionTime: 0,
            proposer: msg.sender,
            targetContract: targetContract,
            data: data
        });

        emit ProposalCreated(proposalId, description, msg.sender);
    }

    /** 🔹 Governance: Vote on Proposal */
    function voteOnProposal(uint256 proposalId, bool voteFor) external whenNotPaused {
        require(_stakedLYTH[msg.sender] > 0, "Must have staked LYTH to vote");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 votingPower = _stakedLYTH[msg.sender];
        if (voteFor) {
            proposals[proposalId].votesFor += votingPower;
        } else {
            proposals[proposalId].votesAgainst += votingPower;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender, voteFor);
    }

    /** 🔹 Governance: Execution Delay */
    function finalizeProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.votesFor > proposal.votesAgainst, "Proposal did not pass");
        proposal.executionTime = block.timestamp + 1 days; // Mandatory 24-hour execution delay
    }

    function executeProposal(uint256 proposalId) external onlyOwner whenNotPaused nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(block.timestamp >= proposal.executionTime, "Execution delay active");
        require(proposal.votesFor > proposal.votesAgainst, "Not enough votes to pass");

        proposal.executed = true;
        (bool success, ) = proposal.targetContract.call(proposal.data);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(proposalId);
    }

    /** 🔹 Staking Functions */
    function stakeTokens(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Cannot stake 0");
        _transfer(msg.sender, address(this), amount);
        _stakedLYTH[msg.sender] += amount;
        _stakeTimestamp[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstakeTokens() external whenNotPaused nonReentrant {
        require(_stakedLYTH[msg.sender] > 0, "No staked LYTH");
        uint256 amount = _stakedLYTH[msg.sender];
        _stakedLYTH[msg.sender] = 0;
        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimStakingRewards() external whenNotPaused nonReentrant {
        require(_stakedLYTH[msg.sender] > 0, "No staked LYTH");
        uint256 stakedTime = block.timestamp - _stakeTimestamp[msg.sender];
        uint256 rewardAmount = (_stakedLYTH[msg.sender] * stakingRewardRate * stakedTime) / (365 days * 100);

        _mint(msg.sender, rewardAmount);
        _stakeTimestamp[msg.sender] = block.timestamp;

        emit StakingRewardUpdated(stakingRewardRate);
    }

    /** 🔹 Treasury Fund Approvals */
    function executeTreasuryTransaction(uint256 proposalId, address recipient, uint256 amount) external whenNotPaused nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.executed, "Proposal not executed yet");

        treasury.approveTransaction(recipient, amount);
        emit FundsApproved(recipient, amount);
    }

    /** 🔹 Admin Functions */
    function setStakingRewardRate(uint256 newRate) external onlyOwner whenNotPaused {
        require(newRate <= 20, "Reward rate too high");
        stakingRewardRate = newRate;
        emit StakingRewardUpdated(newRate);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
