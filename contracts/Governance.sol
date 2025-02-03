// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Governance is Ownable, Pausable {
    struct Proposal {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        uint256 executionTime;
        bool executed;
        bool canceled;
        address proposer;
        address targetContract;
        bytes data;
    }

    uint256 public proposalCount;
    uint256 public votingPeriod = 5 days; // Default 5-day voting period
    uint256 public executionDelay = 1 days; // Delay before execution after voting ends

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public isWhitelisted;

    IERC20 public governanceToken;

    event ProposalCreated(uint256 proposalId, string description, address proposer, uint256 endTime);
    event Voted(uint256 proposalId, address voter, bool vote);
    event ProposalExecuted(uint256 proposalId);
    event ProposalCanceled(uint256 proposalId);
    event Whitelisted(address indexed user);
    event RemovedFromWhitelist(address indexed user);
    event VotingPeriodUpdated(uint256 newPeriod);
    event ExecutionDelayUpdated(uint256 newDelay);

    // ✅ Fixed Constructor (Merged Both Into One)
    constructor(address initialOwner, address _governanceToken) Ownable(initialOwner) {
        governanceToken = IERC20(_governanceToken);
    }

    /** ✅ Whitelist Functions */
    function addWhitelisted(address user) external onlyOwner {
        isWhitelisted[user] = true;
        emit Whitelisted(user);
    }

    function removeWhitelisted(address user) external onlyOwner {
        isWhitelisted[user] = false;
        emit RemovedFromWhitelist(user);
    }

    /** ✅ Create Proposal */
    function createProposal(string memory description, address targetContract, bytes memory data) external whenNotPaused {
        require(isWhitelisted[msg.sender], "Not whitelisted to create proposals");
        require(governanceToken.balanceOf(msg.sender) >= 100 * 10**18, "Must hold at least 100 LYTH to propose");

        uint256 proposalId = proposalCount++;
        proposals[proposalId] = Proposal({
            id: proposalId,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            endTime: block.timestamp + votingPeriod,
            executionTime: 0,
            executed: false,
            canceled: false,
            proposer: msg.sender,
            targetContract: targetContract,
            data: data
        });

        emit ProposalCreated(proposalId, description, msg.sender, proposals[proposalId].endTime);
    }

    /** ✅ Vote on Proposal */
    function vote(uint256 proposalId, bool voteFor) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.canceled, "Proposal was canceled");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(block.timestamp <= proposal.endTime, "Voting period expired");

        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "Must hold governance tokens to vote");

        hasVoted[proposalId][msg.sender] = true;
        if (voteFor) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }

        emit Voted(proposalId, msg.sender, voteFor);
    }

    /** ✅ Finalize Proposal (Sets Execution Time) */
    function finalizeProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.canceled, "Proposal was canceled");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal did not pass");
        require(block.timestamp > proposal.endTime, "Voting period not ended");

        proposal.executionTime = block.timestamp + executionDelay;
    }

    /** ✅ Execute Proposal */
    function executeProposal(uint256 proposalId) external onlyOwner whenNotPaused {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal was canceled");
        require(block.timestamp >= proposal.executionTime, "Execution delay active");

        proposal.executed = true;
        (bool success, ) = proposal.targetContract.call(proposal.data);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(proposalId);
    }

    /** ✅ Cancel Proposal */
    function cancelProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];

        require(msg.sender == proposal.proposer || msg.sender == owner(), "Only proposer or owner can cancel");
        require(!proposal.executed, "Cannot cancel executed proposal");
        
        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /** ✅ Admin Functions */
    function setVotingPeriod(uint256 newPeriod) external onlyOwner whenNotPaused {
        require(newPeriod >= 1 days && newPeriod <= 14 days, "Voting period out of range");
        votingPeriod = newPeriod;
        emit VotingPeriodUpdated(newPeriod);
    }

    function setExecutionDelay(uint256 newDelay) external onlyOwner whenNotPaused {
        require(newDelay >= 1 hours && newDelay <= 7 days, "Execution delay out of range");
        executionDelay = newDelay;
        emit ExecutionDelayUpdated(newDelay);
    }

    function pauseGovernance() external onlyOwner {
        _pause();
    }

    function unpauseGovernance() external onlyOwner {
        _unpause();
    }
}
