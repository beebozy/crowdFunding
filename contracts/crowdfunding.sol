// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Crowdfunding {
    // Campaign structure to hold details of each campaign
    struct Campaign {
        address payable creator;    
        uint256 goal;               
        uint256 pledgedAmount;      
        uint256 deadline;           // Campaign end time in Unix timestamp
        bool isClaimed;             
        mapping(address => uint256) pledges;  
    }

    uint256 public campaignCount;  // Counter for campaign IDs
    mapping(uint256 => Campaign) public campaigns;  // Store all campaigns

    // Events to notify when certain actions are performed
    event CampaignCreated(uint256 campaignId, address creator, uint256 goal, uint256 deadline);
    event FundPledged(uint256 campaignId, address contributor, uint256 amount);
    event FundWithdrawn(uint256 campaignId, address creator, uint256 amount);
    event RefundIssued(uint256 campaignId, address contributor, uint256 amount);

    // Modifier to check if the sender is the creator of a campaign
    modifier onlyCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Only the creator can call this function");
        _;
    }

    // Function to create a new crowdfunding campaign
    function createCampaign(uint256 _goal, uint256 _durationInDays) external {
        require(_goal > 0, "Goal should be greater than zero");
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        // Increment campaign count and create a new campaign
        campaignCount++;
        Campaign storage newCampaign = campaigns[campaignCount];
        newCampaign.creator = payable(msg.sender);
        newCampaign.goal = _goal;
        newCampaign.deadline = deadline;

        emit CampaignCreated(campaignCount, msg.sender, _goal, deadline);
    }

    // Function to pledge funds to a specific campaign
    function pledgeFunds(uint256 _campaignId) external payable {
        Campaign storage campaign = campaigns[_campaignId];

        // Ensure the campaign is still active
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Pledge must be greater than zero");

        // Add the pledged amount to the campaign and update the contributor's record
        campaign.pledgedAmount += msg.value;
        campaign.pledges[msg.sender] += msg.value;

        emit FundPledged(_campaignId, msg.sender, msg.value);
    }

    // Function to allow the creator to withdraw funds if the goal is met
    function withdrawFunds(uint256 _campaignId) external onlyCreator(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];

        // Check if the campaign has met its goal and is not already claimed
        require(block.timestamp >= campaign.deadline, "Campaign is still ongoing");
        require(campaign.pledgedAmount >= campaign.goal, "Campaign goal not reached");
        require(!campaign.isClaimed, "Funds already claimed");

        // Mark as claimed and transfer the funds
        campaign.isClaimed = true;
        uint256 amount = campaign.pledgedAmount;
        campaign.pledgedAmount = 0;
        campaign.creator.transfer(amount);

        emit FundWithdrawn(_campaignId, campaign.creator, amount);
    }

    // Function to allow contributors to get a refund if the campaign did not reach its goal
    function requestRefund(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];

        // Ensure the campaign has ended and did not reach its goal
        require(block.timestamp >= campaign.deadline, "Campaign is still ongoing");
        require(campaign.pledgedAmount < campaign.goal, "Campaign was successful");
        uint256 pledgedAmount = campaign.pledges[msg.sender];
        require(pledgedAmount > 0, "No funds to refund");

        // Update the pledged amount and transfer the refund to the contributor
        campaign.pledges[msg.sender] = 0;
        payable(msg.sender).transfer(pledgedAmount);

        emit RefundIssued(_campaignId, msg.sender, pledgedAmount);
    }

    // Function to get details of a campaign
    function getCampaignDetails(uint256 _campaignId)
        external
        view
        returns (
            address creator,
            uint256 goal,
            uint256 pledgedAmount,
            uint256 deadline,
            bool isClaimed
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (campaign.creator, campaign.goal, campaign.pledgedAmount, campaign.deadline, campaign.isClaimed);
    }
}
