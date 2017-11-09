pragma solidity ^0.4.11;

contract RandaoDBEvent{
    event LogRandom(uint256 indexed lotteyID, uint256 indexed CampaignId, uint256 random);
    event LogCampaignFailed(uint256 indexed lotteyID, uint256 indexed CampaignId, uint error);
}