pragma solidity ^0.4.11;

contract RandaoAdminEvent{
    event LogCampaignInit(uint256 indexed lotteyID, uint256 indexed campaignID, bytes32 mainLotteryCommit, uint256 bountypot);
    event LogCampaignStart(uint256 indexed lotteyID,
                            uint256 indexed campaignID,
                             uint256 bStart,
                             uint256 bRevealsStart,
                             uint256 bFinaliseStart,
                             uint256 bFinalised,
                             uint256 deposit,
                             uint256 bountypot,
                             bytes32 operatorCommit,
                             uint256 minParticipants,
                             uint256 minReveals);
    event LogCampaignInitFailed(uint256 indexed lotteyID, uint256 error);
    event LogCampaignStartFailed(uint256 indexed lotteyID, uint256 indexed campaignID, uint256 error);
    event LogDepositReturned(uint256 indexed lotteyID, uint256 indexed CampaignId, address indexed to, uint deposit);
    event LogBountyPayed(uint256 indexed lotteyID, uint256 indexed CampaignId, address indexed to, uint amount, uint deposit);
    event LogMainLotteryReveal(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 _s, uint block_number);
    event LogOperatorManagerReveal(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 _s, uint block_number);
    event LogRefundBounty(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 bountypot);
    event LogSendBountyIndex(uint256 indexed lotteyID, uint256 indexed CampaignId, uint256 index , uint256 length);
    event LogRefundDepositIndex(uint256 indexed lotteyID, uint256 indexed CampaignId, uint256 index , uint256 length);
}
