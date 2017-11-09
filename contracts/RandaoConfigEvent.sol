pragma solidity ^0.4.11;

contract RandaoConfigEvent{
    event LogBlacklisted(uint256 indexed lotteyID, uint256 indexed CampaignId,  // log the height at which blacklist occured too
                            address _blacklistee);
    event LogSetRandaoBlockConfiguration(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 bStart, uint256 bRevealsStart, uint256 bFinaliseStart, uint256 bFinalised);

    event LogSetBRevealsStart(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 bRevealsStart);
    event LogSetBFinaliseStart(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 bFinaliseStart);
    event LogSetBFinaliseStop(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 bFinalised);
    event LogSetThresholds(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 minParticipants, uint256 minReveals);
    event LogSetBlacklistThreshold(uint256 _blacklistThreshold);
    event LogSetDeposit(uint256 indexed _lotteryRoundID, uint256 indexed _campaignID, uint256 _deposit);

    event LogSetKycContract(address old, address _kycContract);
    event LogSetQuantaAddress(address old, address _qntAcc);
    event LogSetOperatorManagerAddress(address old, address _operatorAcc);
    event LogSetLotteryAddress(address old, address _lotteryAcc);   
    event LogNonRevealCount(address _participant, uint256 num);
}