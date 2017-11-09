pragma solidity ^0.4.11;

import "./RandaoDBEvent.sol";

contract RandaoDB is RandaoDBEvent{

    uint256 public lotteryID = 0;
    mapping (uint256 => Campaign[]) mapCampaign;

    address public configAddress;
    address public radaoAddress;
    address public adminAddress;

    struct Participant {
        uint256   secret;
        bytes32   commitment;
        uint256   reward;
        bool      rewarded;
        bool      depositReturned;
    }

    struct Campaign {
        uint256 bStart;
        uint256 bRevealsStart;
        uint256 bFinaliseStart;
        uint256 bFinalised;
        uint256 deposit;

        uint256 random;    
        uint256 revealsNum;

        uint256 minParticipants;
        uint256 minReveals;

        uint256 index_sendBounty;
        uint256 index_sendDeposit;


        uint256 mainLotteryReveal;
        uint256 operatorReveal;

        bytes32 mainLotteryCommit;
        bytes32 operatorCommit;

        bool settled;
        bool failed;

        // errorType = 1 : commit number < min participants
        // errorType = 2 : no one reveal
        // errorType = 3 : reveal number < min reveal
        // errorType = 4: lottery or operation do not reveal
        uint errorType;
    
        mapping (address => Participant) participants;
        address[] participantsList;
    }

    modifier onlyRandao() {
        if (msg.sender != radaoAddress) throw;
        _;
    } 

    modifier onlyAdmin() {
        if (msg.sender != adminAddress) throw;
        _;
    }

    modifier onlyModifyAddress() {
        if (msg.sender != configAddress
            && msg.sender != radaoAddress
            && msg.sender != adminAddress) throw;
        _;
    }  

    modifier onlyRandaoConfig(){
        if(msg.sender != configAddress) throw;
        _;
    }

    function RandaoDB(address _configAddress)
    {
        configAddress = _configAddress;
    }

    /*
    * @dev change randao address and randaoAdmin address
    * @param _radaoAddress randao address
    * @param _adminAddress randao admin address
    */
    function setModifyAddress(address _radaoAddress, address _adminAddress)
        onlyRandaoConfig
    {
        radaoAddress = _radaoAddress;
        adminAddress = _adminAddress;
    } 

    /*
    * @dev when lottery start, store data to DB
    * @param _lotteryRoundID lottery round ID
    * @param _mainLotteryCommit value of hashed secret of lottery
    * @param _operatorCommit value of hashed secret of operator
    * @param _bounty bounty of this round
    * @param _deposit deposit of this round
    */
    function start(uint256 _lotteryRoundID, bytes32 _mainLotteryCommit, bytes32 _operatorCommit, uint256 _bounty, uint256 _deposit) 
        onlyAdmin
    {
        Campaign memory c;
        c.bStart = block.number;        
        c.deposit = _deposit;        
        c.operatorCommit = _operatorCommit;
        c.mainLotteryCommit = _mainLotteryCommit;        

        mapCampaign[_lotteryRoundID].push(c);              
    }

    /*
    * @dev when participant commits their hash, store in DB
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @param _hs value of hashed secret
    * @param msg address of participant sent hashed value
    */
    function commit(uint256 _lotteryRoundID, uint256 _campaignID, bytes32 _hs, address msg)
        onlyRandao
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        c.participants[msg] = Participant(0, _hs, 0, false, false);
        c.participantsList.push(msg);
    }

    /*
    * @dev when participant reveals their hash, store in DB if not yet reveal
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @param _s value of secret
    * @param msg address of participant sent secret
    */
    function reveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s, address msg) 
        onlyRandao
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        c.participants[msg].secret = _s;
        c.revealsNum++;
        c.random ^= c.participants[msg].secret;
    }

    /*
    * @dev check participant whether reveals or not
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @param msg address of participant sent secret
    */
    function isRevealed(uint256 _lotteryRoundID, uint256 _campaignID, address msg)         
        constant
        returns(bool)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        if(c.participants[msg].secret != 0)
            return true;
    }

    /*
    * @dev when campaign is failed, change status of campaign in DB
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @param _error type of error
    */
    function failCampaign(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _error) 
        onlyModifyAddress
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        c.failed = true; 
        c.errorType = _error;
        LogCampaignFailed(_lotteryRoundID, _campaignID, _error);
    }

    /*
    * @dev when lottery reveals its secret, store in DB
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @param _s value of secret
    */
    function mainLotteryReveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s)
        onlyAdmin
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        c.mainLotteryReveal = _s;
        c.random ^= c.mainLotteryReveal;
    }

    /*
    * @dev when operatorManager Reveals its secret, store in DB
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @param _s value of secret
    */
    function operatorManagerReveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s) 
        onlyAdmin
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];        
        c.operatorReveal = _s;
        c.random ^= c.operatorReveal;
    }

    /*
    * @dev when lottery is finished of reveal phase, change status of lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    */
    function revealFinish(uint256 _lotteryRoundID, uint256 _campaignID) 
        onlyAdmin
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        c.settled = true;

        LogRandom(_lotteryRoundID, _campaignID, c.random);      
    }

    /*
    * @dev when campaign is failed, change status of campaign
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    */
    function stop(uint256 _lotteryRoundID, uint256 _campaignID) 
        onlyAdmin
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        c.failed = true;
        c.random = 0;                
    }
    
    /*
    * @dev get random number
    * @param _lotteryRoundID lottery round ID
    * @return settled status, start block, finalised block and random number
    */
    function getRandom(uint256 _lotteryRoundID) 
        onlyRandao 
        returns (bool, uint256, uint256, uint256) 
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        return (c.settled, c.bStart, c.bFinalised, c.random);
    }

    /*
    * @dev when refund all deposit to participant, update status in DB
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @param pAddr participant address
    * @param ok true if refund successfully and vice versa
    */
    function refundAllDeposits(uint256 _lotteryRoundID, uint256 _campaignID, address pAddr, bool ok) 
        onlyAdmin
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        Participant p = c.participants[pAddr];
        
        p.depositReturned = ok;
        // if send ok => increase index_sendDeposit
        // else send fail => decrease index_sendDeposit
        ok == true ? c.index_sendDeposit ++ : c.index_sendDeposit --;        
    }

    /*
    * @dev when send reward to  all participants, update status in DB
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * param _share value of shared reward    
    * @param ok true if refund successfully and vice versa
    * @param _to participant address
    */
    function returnReward(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _share, bool ok, address _to) 
        onlyAdmin       
    {
        Campaign _c = mapCampaign[_lotteryRoundID][_campaignID];
        Participant _p = _c.participants[_to];

        _p.reward = _share;
        _p.rewarded = true;
        _p.depositReturned = true;
        if (!ok) 
        {
            _p.reward = 0;
            _p.rewarded = false;
            _p.depositReturned = false;
        }
    }     

    /*
    * @dev get latest campaign ID of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @return value of latest campaign
    */
    function getCampaignID(uint256 _lotteryRoundID) returns (uint256)
    {        
        // return mapCampaign[_lotteryRoundID].length - 1;
        return mapCampaign[_lotteryRoundID].length <= 1 ? 0 : mapCampaign[_lotteryRoundID].length - 1;
    }

    /*
    * @dev get failed status of campaign ID of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @return true: failed, false : not failed
    */
    function getFailedStatus(uint256 _lotteryRoundID) 
        constant
        returns (bool)
    {
        if(mapCampaign[_lotteryRoundID].length >= 1){
            uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;
            Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        
            return c.failed;
        }        
    }

    /*
    * @dev get campaign info for user who commits
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result deposit, started block, revealed block, committed value
    */
    function getCampaignInfoForCommit(uint256 _lotteryRoundID, uint256 _campaignID, address msg)
        onlyRandao 
        returns(uint256, uint256, uint256, bytes32)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        return (c.deposit, c.bStart, c.bRevealsStart, c.participants[msg].commitment) ;
    }

    /*
    * @dev get campaign info for user who reveals
    * @param _lotteryRoundID lottery round ID
    * @return 
    */
    function getCampaignInfoForReveal(uint256 _lotteryRoundID)
        onlyRandao
        returns(bool, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        
        return (c.failed, c.bStart, c.bRevealsStart, c.bFinaliseStart, c.participantsList.length, c.minParticipants, _campaignID);
    }    

    /*
    * @dev get hash of secret of a participant
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result hashed value
    */
    function getParticipantCommitHash(uint _lotteryRoundID, uint256 _campaignID, address msg) 
        returns (bytes32)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        return (c.participants[msg].commitment);
    }

    /*
    * @dev get hashed secret of a lottery and operator
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result committed values of lottery and operator
    */
    function getLotteryAndOperatorCommit(uint256 _lotteryRoundID, uint256 _campaignID) 
        onlyRandao
        returns(bytes32, bytes32)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        return (c.mainLotteryCommit, c.operatorCommit);
    }

    /*
    * @dev get revealed info of a campaign
    * @param _lotteryRoundID lottery round ID
    * @result campaignID, started block, Finalise Start block, finalised value
    */
    function getInfoForAdminReveal(uint256 _lotteryRoundID) 
        returns(uint256, uint256, uint256, uint256)
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;        
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        return (_campaignID, c.bStart, c.bFinaliseStart, c.bFinalised);
    }

    /*
    * @dev count revealed number of lottery and operator
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result 2 if both lottery and operator reveal, 0 if only one of them reveals
    */
    function countQuantaReveals(uint256 _lotteryRoundID, uint256 _campaignID) 
        constant
        returns(uint256)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        if(c.mainLotteryReveal != 0 && c.operatorReveal != 0)
        {
            return 2;
        }

        return 0;
    } 

    /*
    * @dev get number of participants committed
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result comitted number and status of lottery (settled or not settled)
    */
    function getCommitNumber(uint256 _lotteryRoundID, uint256 _campaignID)
        constant
        returns(uint256, bool)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        return (c.participantsList.length, c.settled);
    }

    /*
    * @dev get reveal info after finishing
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result status of lottery (failed or not failed), number of reveal, minimum Reveal
    */
    function getInfoAfterRevealFinish(uint256 _lotteryRoundID, uint256 _campaignID) 
        returns(bool, uint256, uint256)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        return (c.failed, c.revealsNum, c.minReveals);
    }

    /*
    * @dev get minimum reveal for this round 
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result minimum Reveal
    */
    function getMinimumReveal(uint256 _lotteryRoundID, uint256 _campaignID) 
        returns(uint256)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        return c.minReveals;
    }

    /*
    * @dev get minimum participants for this round 
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result minimum participants
    */
    function getMinimumParticiapnt(uint256 _lotteryRoundID, uint256 _campaignID) 
        returns(uint256)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        return c.minParticipants;
    }

    /*
    * @dev get status of latest campaign 
    * @result info of campaign
    */
    function getLatestStatusOfCampaign()
        constant
        returns (uint256, uint256, bool, uint256, uint256, bool)
    {
        uint256 _campaignID = mapCampaign[lotteryID].length - 1;
        Campaign c = mapCampaign[lotteryID][_campaignID];

        return (lotteryID, _campaignID, c.failed, c.bStart, c.bFinalised, c.settled);
    }    

    
    function getInfoForRefundBounty(uint256 _lotteryRoundID) 
        onlyAdmin 
        returns(uint256, uint256, uint256, bool)
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;        
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        
        return (_campaignID, c.bStart, c.bFinalised, c.failed);
    }
    
    /*
    * @dev get deposit info
    * @param _lotteryRoundID lottery round ID
    * @result status of refund deposit
    */
    function getInfoForRefundAllDeposits(uint256 _lotteryRoundID) 
        onlyAdmin 
        returns(uint256, uint256, uint256, uint256, uint256, uint256)
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;        
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        return (_campaignID, c.bStart, c.bFinalised, c.deposit, c.index_sendDeposit, c.participantsList.length);
    }

    /*
    * @dev get address and refunded deposit status of current indexd deposit
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result address of current indexd deposit
    */
    function getCurrentIndexedDeposit(uint256 _lotteryRoundID, uint256 _campaignID) 
        onlyAdmin 
        returns (address, bool)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        address pAddr = c.participantsList[c.index_sendDeposit];
        Participant p = c.participants[pAddr];

        return (pAddr, p.depositReturned);
    }

    function getInfoForSendBounties(uint256 _lotteryRoundID) 
        onlyAdmin 
        returns(uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;        
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];                

        return (_campaignID, c.bStart, c.bFinalised, c.deposit, c.revealsNum, c.index_sendBounty,  c.participantsList.length);
    }    

    function getInfoForSendBountiesCampaign(uint256 _lotteryRoundID, uint256 _campaignID) 
        onlyAdmin 
        returns (address, uint256, bool)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];

        address pAddr = c.participantsList[c.index_sendBounty];
        Participant p = c.participants[pAddr];

        c.index_sendBounty ++;

        return (pAddr, p.secret, p.rewarded);
    }

    function getConfig(uint256 _lotteryRoundID) 
        returns(uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1;        
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];      

        return (c.deposit, c.bStart, c.bRevealsStart, c.bFinaliseStart, c.bFinalised, c.minParticipants, c.minReveals);
    }
    
    /*
    * @dev set new lottery ID
    * @param _lotteryRoundID lottery round ID
    * @param _campaignID campaign ID
    * @result address of current indexd deposit
    */
    function setLotteryID(uint256 _lotteryRoundID) 
        onlyAdmin
    {
        lotteryID = _lotteryRoundID;
    }

    /*
    * @dev set config for a lottery round
    */
    function setConfig(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _deposit, uint256 _bRevealsStart, uint256 _bFinaliseStart, uint256 _bFinalised, uint256 _minParticipants, uint256 _minReveals)
        onlyModifyAddress
    {
        if(mapCampaign[_lotteryRoundID].length != 0){
            Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        
            c.bRevealsStart =  _bRevealsStart;
            c.bFinaliseStart = _bFinaliseStart;
            c.bFinalised = _bFinalised; 
            c.minParticipants = _minParticipants;
            c.minReveals = _minReveals;     

            c.deposit = _deposit;
        }        
    }

    /*
    * @dev check a user is in participantsList or not
    * @params _lotteryRoundID lottery round lotteryID
    * @params _campaignID campaign ID
    * @params _sender address of participant
    * @result bool true if in participantsList or vice versa
    */
    function isInParticipantsList(uint _lotteryRoundID, uint _campaignID, address _sender)
        constant
        returns(bool)
    {
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        for(uint i = 0; i < c.participantsList.length; i++){
            if(c.participantsList[i] == _sender){
                return true;
            }
        }
    }

    /*
    * @dev check if participant is returned deposit and rewarded
    * @params _lotteryRoundID lottery round lotteryID
    * @params _campaignID campaign ID
    * @params _sender paticipant address
    * @return true if participant do not receive deposit and reward. And vice versa
    */
    function isNotReceiveDepositOrRewarded(uint256 _lotteryRoundID, uint256 _campaignID, address _sender) 
        constant
        returns(bool)
    {
        Campaign _c = mapCampaign[_lotteryRoundID][_campaignID];

        Participant _p = _c.participants[_sender];

        if(!_p.depositReturned && !_p.rewarded){
            return true;
        }
    }

    /*
    * @dev get status of a campaign in a lottery round
    * @params _lotteryRoundID lottery round lotteryID
    * @params _campaignID campaign ID
    * @return started block, finalised block, deposit, number of reveals, status (fail or success)
    */
    function getCampaignStatus(uint _lotteryRoundID, uint _campaignID)
        constant
        returns(uint, uint, uint, uint, uint, bool)
    {        
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];        
        return (c.bStart, c.bFinalised, c.deposit, c.revealsNum, c.participantsList.length, c.failed);
    }  

    /*
    * @dev get error type of lottery round
    * @params _lotteryRoundID lottery round lotteryID
    * @return error type
    */
    function getErrorType(uint _lotteryRoundID)  
        constant
        returns(uint)
    {
        uint256 _campaignID = mapCampaign[_lotteryRoundID].length - 1; 
        Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
        return c.errorType;
    }

}