pragma solidity ^0.4.11;

contract RandaoEvent{
    event LogCommit(uint256 indexed lotteyID, uint256 indexed CampaignId, bytes32 commitment);
    event LogReveal(uint256 indexed lotteyID, uint256 indexed CampaignId, uint256 secret);
}