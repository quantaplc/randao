pragma solidity ^0.4.11;

import "./RandaoConfig.sol";
import "./RandaoDB.sol";
import "./RandaoAdminEvent.sol";

contract RandaoAdmin is RandaoAdminEvent{

    modifier isTrue(bool _t) { if (!_t) throw; _; }

    modifier isFalse(bool _t) { if (_t) throw; _; }
    
    modifier checkSecret(uint256 _s, bytes32 _commitment) {
        if (sha3(_s) != _commitment) throw;
        _;
    }

    modifier finalisePhase(uint256 _bStart, uint256 _bFinaliseStart, uint256 _bFinalised) {
        if (block.number < _bStart + _bFinaliseStart) throw;
        if (block.number > _bStart + _bFinalised) throw;
        if(_bStart == 0|| _bFinaliseStart == 0 || _bFinalised == 0)throw;
        _;
    }        

    modifier finished(uint256 _bStart, uint256 _bFinalised) {
        if (block.number < _bStart + _bFinalised) throw;
        if(_bStart == 0 || _bFinalised == 0) throw;
        _;
    }

    modifier onlyManagerMultiSig() {
        if (msg.sender != Config.multiSigManager()) throw;
        _;
    }     

    modifier onlyQuanta() {
        if (msg.sender != Config.quantaAddress()) throw;
        _;
    }       

    modifier onlyOperatorManager() {
        if (msg.sender != Config.operatorManagerAddress()) throw;
        _;
    }       

    modifier onlyLottery() {
        if (msg.sender != Config.lotteryAddress()) throw;
        _;
    }     

    modifier onlyAllowClaim(){
        if(!isAllowClaim)
            throw;
        _;
    }

    modifier onlyUnlocked(){
        if(locked)
            throw;
        _;
    }

    RandaoConfig public Config;
    RandaoDB public DB;       
    

    struct InitStruct{
        bytes32 mainLotteryCommit;
        bytes32 operatorCommit;
        uint256 mainLotteryReveal;
        uint256 operatorReveal;
        uint256 bountypot;
    }
    mapping(uint256 => InitStruct) mapInit;    
    bool public isAllowClaim; // true: user can claim and vice versa

    address public fundKeeper;
    bool public locked; // true: Quanta withdraw all funds. The other transaction will be stopped

    function ()payable{

    }

	function RandaoAdmin(address _configAddress, address _dbAddress)
    {
        Config = RandaoConfig(_configAddress);
        DB = RandaoDB(_dbAddress);
        isAllowClaim = true;
    }
    
    /*
    * @dev change status which allows users claim their money
    */
    function changeClaimStatus()
        onlyManagerMultiSig
    {
        isAllowClaim = !isAllowClaim;
    }

    /*
    * @dev set value of randao config and randaodb contract
    * @param _configAddress randao config address
    * @param _dbAddress randao db address
    */
    function setConfig(address _configAddress, address _dbAddress)        
        onlyManagerMultiSig
    {
        Config = RandaoConfig(_configAddress);
        DB = RandaoDB(_dbAddress);
    }  

    /*
    * @dev lottery commit hash of secret
    * @param _lotteryRoundID lottery ID
    * @param _mainLotteryCommit hash of secret
    */
    function init(uint256 _lotteryRoundID, bytes32 _mainLotteryCommit) 
        external
        payable
        onlyLottery
    {
        if(msg.value <= 0)
        {
            LogCampaignInitFailed(_lotteryRoundID, 1);
            return;
        }

        if(_mainLotteryCommit == 0 || _mainLotteryCommit == sha3(uint(0)))
        {
            LogCampaignInitFailed(_lotteryRoundID, 2);
            return;
        }        
        
        if(mapInit[_lotteryRoundID].mainLotteryCommit != 0)
        {
            LogCampaignInitFailed(_lotteryRoundID, 3);
            return;
        }

        DB.setLotteryID(_lotteryRoundID);

        mapInit[_lotteryRoundID].mainLotteryCommit =_mainLotteryCommit;
        mapInit[_lotteryRoundID].bountypot = msg.value;            

        LogCampaignInit(_lotteryRoundID, 0, _mainLotteryCommit, msg.value);
    }

    /*
    * @dev operator manager commit hash of secret
    * @param _lotteryRoundID lottery ID
    * @param _operatorCommit hash of secret
    */
    function start(uint256 _lotteryRoundID, bytes32 _operatorCommit)       
        payable 
        onlyOperatorManager
    {        
        if(_operatorCommit == 0 || _operatorCommit == sha3(uint(0)))
        {
             LogCampaignStartFailed(_lotteryRoundID, 0, 1);
            return;           
        }

        if(mapInit[_lotteryRoundID].mainLotteryCommit == 0)
        {
            LogCampaignStartFailed(_lotteryRoundID, 0, 2);
            return;
        }

        uint256 _campaignID = 0;
        if(mapInit[_lotteryRoundID].mainLotteryCommit != 0 && mapInit[_lotteryRoundID].operatorCommit != 0)
        {
            _campaignID = DB.getCampaignID(_lotteryRoundID);

            var (_num, _settled) = DB.getCommitNumber(_lotteryRoundID, _campaignID);
            var _isFailed = DB.getFailedStatus(_lotteryRoundID);
            // if campaign is not failed, then check whether there is at least one user commit or not
            if(_isFailed == false){
                if(_num > 0 || _settled == true)
                {
                    LogCampaignStartFailed(_lotteryRoundID, 0, 3);
                    return;
                }
            }
                                
            _campaignID += 1;
        }
          
        // uint256 _bounty = msg.value + mapInit[_lotteryRoundID].bountypot;        
        if(msg.value + this.balance < mapInit[_lotteryRoundID].bountypot )
        {
            LogCampaignStartFailed(_lotteryRoundID, _campaignID, 4);
            return;
        }

        mapInit[_lotteryRoundID].operatorCommit = _operatorCommit;

        DB.start(_lotteryRoundID, mapInit[_lotteryRoundID].mainLotteryCommit, _operatorCommit, mapInit[_lotteryRoundID].bountypot, Config.DEPOSIT());        

        Config.start(_lotteryRoundID);

        LogCampaignStart(_lotteryRoundID, _campaignID, block.number, Config.BREVEAL_START(), Config.BFINAL_START(),
                          Config.BFINAL_STOP(), Config.DEPOSIT(), mapInit[_lotteryRoundID].bountypot, _operatorCommit, Config.MIN_PARTICIPANTS(), Config.MIN_REVEALS());                      
    }        

    /*
    * @dev lottery reveals secret. This secret will be XOR with current random number in campaign
    * @param _lotteryRoundID lottery ID
    * @param _secret secret
    */
    function mainLotteryReveal(uint256 _lotteryRoundID, uint256 _secret)
        onlyLottery
    {
        var (_campaignID, _bStart, _bFinaliseStart, _bFinalised) = DB.getInfoForAdminReveal(_lotteryRoundID);

        mainLotteryRevealCampaign(_lotteryRoundID, _campaignID, _bStart, _bFinaliseStart, _bFinalised, _secret);
    }

    /*
    * @dev lottery reveals secret. This secret will be XOR with current random number in campaign
    * @param _lotteryRoundID lottery ID
    * @param _campaignID campaign ID
    * @param _bStart started block
    * @param _bFinaliseStart started finalised block
    * @param _bFinalised bFinalised block
    * @param _secret secret
    */
    function mainLotteryRevealCampaign (uint256 _lotteryRoundID, uint256 _campaignID, uint256 _bStart, uint256 _bFinaliseStart,
    							 uint256 _bFinalised, uint256 _secret)
        internal
        checkSecret(_secret, mapInit[_lotteryRoundID].mainLotteryCommit)
        finalisePhase(_bStart, _bFinaliseStart, _bFinalised)
        // isFalse(mapInit[_lotteryRoundID].mainLotteryReveal == _secret)
    {
        mapInit[_lotteryRoundID].mainLotteryReveal = _secret;

    	DB.mainLotteryReveal(_lotteryRoundID, _campaignID, _secret);

        LogMainLotteryReveal(_lotteryRoundID, _campaignID, _secret, block.number);                 
    }   

    /*
    * @dev operator manager reveals secret
    * @param _lotteryRoundID lottery ID
    * @param _secret secret
    */
    function operatorManagerReveal(uint256 _lotteryRoundID, uint256 _secret)        
        onlyOperatorManager
    {
        var (_campaignID, _bStart, _bFinaliseStart, _bFinalised) = DB.getInfoForAdminReveal(_lotteryRoundID);

        operatorManagerRevealCampaign(_lotteryRoundID, _campaignID, _bStart, _bFinaliseStart, _bFinalised, _secret);
    }

    /*
    * @dev process revealed campaign
    * @param _lotteryRoundID lottery ID
    * @param _campaignID campaign ID
    * @param _bStart started block
    * @param _bFinaliseStart started finalised block
    * @param _bFinalised bFinalised block
    * @param _secret secret
    */
    function operatorManagerRevealCampaign (uint256 _lotteryRoundID, uint256 _campaignID, uint256 _bStart, uint256 _bFinaliseStart,
                                 uint256 _bFinalised, uint256 _secret)
        internal
        checkSecret(_secret, mapInit[_lotteryRoundID].operatorCommit)
        finalisePhase(_bStart, _bFinaliseStart, _bFinalised)
        // isFalse(mapInit[_lotteryRoundID].operatorReveal == _secret)
    {
        mapInit[_lotteryRoundID].operatorReveal = _secret;

        DB.operatorManagerReveal(_lotteryRoundID, _campaignID, _secret);

        LogOperatorManagerReveal(_lotteryRoundID, _campaignID, _secret, block.number);

        setRandom(_lotteryRoundID, _campaignID);
        
    }

    function setRandom(uint256 _lotteryRoundID, uint256 _campaignID)
        internal
    {
        // both lottery and operator manager reveal
        if(DB.countQuantaReveals(_lotteryRoundID, _campaignID) == 2)
        {            
            var (_failed, _revealsNum, _minReveals) = DB.getInfoAfterRevealFinish(_lotteryRoundID, _campaignID);

            if(_failed){
                return;
            }

            // revealFinish(_lotteryRoundID, _campaignID, _failed, _revealsNum, _minReveals);
            revealFinish(_lotteryRoundID, _campaignID, _revealsNum, _minReveals);
        }   
    }
    
    /*
    * @dev after revealed phase finish, store status (fail or success) to RandaoDB based on real data
    * @param _lotteryRoundID lottery ID
    * @param _campaignID campaign ID
    * @param _revealsNum number of reveal
    * @param _minReveals minimum reveal
    */
    function revealFinish(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _revealsNum, uint256 _minReveals)
        internal
    {           
        // if no one reveal => return
        if (_revealsNum == 0)
        {                        
            // failCampaign(_lotteryRoundID, _campaignID, 2);
            DB.failCampaign(_lotteryRoundID, _campaignID, 2);
            return;
        }

        // if revealed number <= minimum reveal => return
        if (_revealsNum < _minReveals) 
        {                        
            // failCampaign(_lotteryRoundID, _campaignID, 3);
            DB.failCampaign(_lotteryRoundID, _campaignID, 3);
            return;
        }

        DB.revealFinish(_lotteryRoundID, _campaignID); 
    } 

    /*
    * @dev stop campaign when operator or lottery do not reveal and campaign is not failed
    */
    function stop()
        onlyQuanta
    {
        var (_lotteryRoundID, _campaignID, _failed, _bStart, _bFinalised, _isSettled) = DB.getLatestStatusOfCampaign();
        // if not finished
        if (block.number < _bStart + _bFinalised)
            throw;
        if(_bStart == 0 || _bFinalised == 0)
            throw;
        
        // if failed => throw;
        if(_failed)
            throw;
        
        // if settled => throw
        if(_isSettled)
            throw;

        // if operator or lottery do not reveal => stop campaign        
        // if (mapInit[_lotteryRoundID].mainLotteryReveal == 0 || mapInit[_lotteryRoundID].operatorReveal == 0)
        // {           
            DB.stop(_lotteryRoundID, _campaignID);
            // failCampaign(_lotteryRoundID, _campaignID, 4);   
            DB.failCampaign(_lotteryRoundID, _campaignID, 4);
        // }
        // stopCampaign(_lotteryRoundID, _campaignID, _failed, bStart, bFinalised, _isSettled);
    }

   /*
    * @dev manager withdraws deposit
    * @param _lotteryRoundID lottery ID
    */
    function withdrawBounty(uint256 _lotteryRoundID)
        onlyManagerMultiSig
        onlyUnlocked
    {
        var (_campaignID, _bStart, _bFinalised, _failed) = DB.getInfoForRefundBounty(_lotteryRoundID);

        // if not fail => throw
        if(!_failed)
            throw;

        // if not finished
        if (block.number < _bStart + _bFinalised)
            throw;
        if(_bStart == 0 || _bFinalised == 0)
            throw;
        // processWithdrawBounty(_lotteryRoundID, _campaignID, _bStart, _bFinalised, _failed, msg.sender);
        uint256 _bounty = mapInit[_lotteryRoundID].bountypot;
        
        if (_bounty == 0)
        {
            return;
        }

        if (msg.sender.send(_bounty))
        {
            LogRefundBounty(_lotteryRoundID, _campaignID, _bounty);
        }
        else
        {
            mapInit[_lotteryRoundID].bountypot = _bounty;
        }
    }    

    /*
    * @dev refund deposit to all participants
    * @param _lotteryRoundID lottery ID
    */
    function refundAllDeposits(uint256 _lotteryRoundID)
        private
    {
        var (_campaignID, _bStart, _bFinalised, _deposit, _index_sendDeposit, _participantsLength) = DB.getInfoForRefundAllDeposits(_lotteryRoundID);

        // if not finished
        if (block.number < _bStart + _bFinalised)
            throw;
        if(_bStart == 0 || _bFinalised == 0)
            throw;

        // refundDepositsCampaign(_lotteryRoundID, _campaignID, _bStart, _bFinalised, _deposit, _index_sendDeposit, _participantsLength);
        if(_participantsLength == 0){
            return;
        }
        uint256 max = _participantsLength > _index_sendDeposit ? _participantsLength - _index_sendDeposit : 0;
        if(max > 5)
        {
            max = 5;
        }

        for (uint8 i = 0; i < max; i++)
        {
            var (pAddr, isRefunded) = DB.getCurrentIndexedDeposit(_lotteryRoundID, _campaignID);
            //if participant do not receive deposit
            if(!isRefunded){
                DB.refundAllDeposits(_lotteryRoundID, _campaignID, pAddr, true);
                if (!pAddr.send(_deposit))
                {
                    DB.refundAllDeposits(_lotteryRoundID, _campaignID, pAddr, false);
                }
                else
                {
                    LogDepositReturned(_lotteryRoundID, _campaignID, pAddr, _deposit);
                }
            }
        }
        LogRefundDepositIndex(_lotteryRoundID, _campaignID, _index_sendDeposit + max, _participantsLength);
    }    

    /*
    * @dev send shared and deposit to participants in a lottery round
    * @param _lotteryRoundID lottery ID
    */
    function sendBounties(uint256 _lotteryRoundID)
        private
    {
        var (_campaignID, _bStart, _bFinalised, _deposit, _revealsNum, _index_sendBounty, _participantsLength) = DB.getInfoForSendBounties(_lotteryRoundID);
        // if not finished
        if (block.number < _bStart + _bFinalised)
            throw;
        if(_bStart == 0 || _bFinalised == 0)
            throw;

        // sendBountiesCampaign(_lotteryRoundID, _campaignID, _bStart, _bFinalised, _deposit, _revealsNum, _index_sendBounty, _participantsLength);
        if (_participantsLength == 0) 
        {
            return;
        }
 
        uint256 max = _participantsLength > _index_sendBounty ? _participantsLength - _index_sendBounty : 0; 
        if(max > 5) 
        {    
            max = 5; 
        }           

        uint256 share = calculateShare(_lotteryRoundID, _campaignID, _deposit, _revealsNum);

        processSendBounty(_lotteryRoundID, _campaignID, share, _deposit,  _revealsNum, max);

        LogSendBountyIndex(_lotteryRoundID, _campaignID, _index_sendBounty + max, _participantsLength);
    }

    /*
    * @dev send shared and deposit to list of participant (max = 5)
    * @param _lotteryRoundID lottery ID
    * @param _campaignID campaign ID
    * @param _share shared bounty
    * @param _deposit deposit each campaign
    * @param _revealsNum number of reveal
    * @param max maximum number for send bounty
    */ 
    function processSendBounty(uint256 _lotteryRoundID, uint256 _campaignID, uint256 share, uint256 _deposit, uint256 _revealsNum, uint256 max)
        internal
    {
        for (uint8 i = 0; i < max; i++) 
        {
            var (pAddr, secret, rewarded) = DB.getInfoForSendBountiesCampaign(_lotteryRoundID, _campaignID);

            if ((secret != 0 ||
                 (secret == 0 && _revealsNum == 0)) && // nobody revealed
                 rewarded == false) 
            {
                returnReward(_lotteryRoundID, _campaignID, share, _deposit, pAddr);
            } 
            else if (secret == 0) 
            {
                Config.incrementNonRevealCount(_lotteryRoundID, _campaignID, pAddr);
            }            
        }       
    }

    /*
    * @dev calculate shared based on revealed number
    * @param _lotteryRoundID lottery ID
    * @param _campaignID campaign ID
    * @param _deposit deposit each campaign
    * @param _revealsNum number of reveal
    * @return _share shared value of each participant will receive
    */ 
    function calculateShare (uint256 _lotteryRoundID, uint256 _campaignID, uint256 _deposit, uint256 _revealsNum)
        internal
        returns (uint256 _share)
    {
        var (_commitNum, _settled) = DB.getCommitNumber(_lotteryRoundID, _campaignID);

        if(_revealsNum <= 0)
        {
            return 0;
        }

        uint _s;

        // if randao run successfully
        if(_settled){
            _s =  (_commitNum - _revealsNum) * _deposit + mapInit[_lotteryRoundID].bountypot;
            _share =  _s / _revealsNum;
        }
        // randao fails
        else{
            // if fail because of quanta (lottery or operator do not reveal) => share bounty
            uint minR = DB.getMinimumReveal(_lotteryRoundID, _campaignID); // minimum reveal
            uint minC = DB.getMinimumParticiapnt(_lotteryRoundID, _campaignID); // minimum participant
            if (DB.countQuantaReveals(_lotteryRoundID, _campaignID) < 2 && _commitNum >= minC && _revealsNum >= minR) {
                _s =  (_commitNum - _revealsNum) * _deposit + mapInit[_lotteryRoundID].bountypot;
                _share =  _s / _revealsNum;
            }
            // share deposit of whom do not reveal
            else if(_revealsNum < minR){
                _s =  (_commitNum - _revealsNum) * _deposit;
                _share =  _s / _revealsNum;
            }
        }
    }  

    /*
    * @dev send shared and deposit to a participant
    * @param _lotteryRoundID lottery ID
    * @param _campaignID campaign ID
    * @param _share shared bounty
    * @param _deposit deposit each campaign
    * @param _to participant address
    */ 
    function returnReward (uint256 _lotteryRoundID, uint256 _campaignID, uint256 _share, uint256 _deposit, address _to)
        internal
    {       
        DB.returnReward(_lotteryRoundID, _campaignID, _share, true, _to); 
        if (!_to.send(_share + _deposit)) 
        {
            DB.returnReward(_lotteryRoundID, _campaignID, _share, false, _to);
        }
        else{
            if(_share != 0)
                LogBountyPayed(_lotteryRoundID, _campaignID, _to, _share, _deposit);
            else
                LogDepositReturned(_lotteryRoundID, _campaignID, _to, _deposit);
        }
    }   

    /*
    * @dev base on error type, return all deposit (type==1 or type==2) or send bounty (type==3 or type==4)
    * @param _lotteryRoundID lottery ID
    * @param _errorType type of error    
    */ 
    function refund(uint _lotteryRoundID)
        onlyQuanta
        onlyUnlocked
    {
        uint _errorType = DB.getErrorType(_lotteryRoundID);
        if(_errorType == 1 || _errorType == 2){
            refundAllDeposits(_lotteryRoundID);
            return;
        }
        if(_errorType == 0 || _errorType == 3 || _errorType == 4){
            sendBounties(_lotteryRoundID);            
        }
    }

    /*
    * @dev allow users claim their deposit and shared bouty when quanta does not complete their jobs
    * @params _lotteryRoundID lottery round ID
    * @params _campaignID campaign ID
    */
    function claimDepositBounty(uint _lotteryRoundID, uint _campaignID)   
        onlyAllowClaim 
        onlyUnlocked
    {
        var (_bStart, _bFinalised, _deposit, _revealsNum, _commitNum, _failed) = DB.getCampaignStatus(_lotteryRoundID, _campaignID);               
        processClaim(_lotteryRoundID, _campaignID, _bStart, _bFinalised, _deposit, _revealsNum, _commitNum, _failed);
    }

    /*
    * @dev process claim of user
    * if error type = 1 or 2 => send deposit
    * if error type == 3 or 4 => send deposit + shared bounty
    */
    function processClaim(uint _lotteryRoundID, uint _campaignID, uint _bStart, uint _bFinalised, uint _deposit, uint _revealsNum, uint _commitNum, bool _failed)
        internal
        finished(_bStart, _bFinalised)
    {
        // check if user is in participantsList        
        if(!DB.isInParticipantsList(_lotteryRoundID, _campaignID, msg.sender)){
            return;
        }

        // check if lottery and operator manager do not reveal
        if(DB.countQuantaReveals(_lotteryRoundID, _campaignID) == 2){
            return;
        }

        // if already send deposit or reward, do nothing
        if(DB.isNotReceiveDepositOrRewarded(_lotteryRoundID, _campaignID, msg.sender) == false){
            return;
        }

        uint _errorType;// error type of this round and this campaign

        // if campaign is not fail, then set campain is fail
        if(_failed == false){
            // if lottery oi operator manager do not reveal => error = 4            

            // if not reach minimum participant => error = 1
            // if number of commit < minimum participant => return
            if (_commitNum < DB.getMinimumParticiapnt(_lotteryRoundID, _campaignID)){
                _errorType = 1;
                DB.failCampaign(_lotteryRoundID, _campaignID, 1);
            }
            // if reveal number = 0  => error = 2
            else if(_revealsNum == 0){
                _errorType = 2;
                DB.failCampaign(_lotteryRoundID, _campaignID, 2);
            }
            else if(DB.countQuantaReveals(_lotteryRoundID, _campaignID) != 2){
                _errorType = 4;
                DB.failCampaign(_lotteryRoundID, _campaignID, 4);
            }
            // if not reach minimum reveals => error = 3
            else{
                uint _tMinReveals = DB.getMinimumReveal(_lotteryRoundID, _campaignID);
                if(_revealsNum < _tMinReveals){
                    _errorType = 3;
                    DB.failCampaign(_lotteryRoundID, _campaignID, 3);
                }
            }
        }
        else{
            _errorType = DB.getErrorType(_lotteryRoundID);
        }
        
        // if not enough participant or no one reveal => only refund deposit
        if(_errorType == 1 || _errorType == 2){
            returnDepositAndReward(_lotteryRoundID, _campaignID, 0, _deposit, msg.sender);
            return;
        }
        // if there is at least one user who revealed
        if(_errorType == 3 || _errorType == 4){
            // if user did not reveal => return
            if(DB.isRevealed(_lotteryRoundID, _campaignID, msg.sender)){
                // calculate share
                uint256 share = calculateShare(_lotteryRoundID, _campaignID, _deposit, _revealsNum);
                // return deposit + reward     
                returnDepositAndReward(_lotteryRoundID, _campaignID, share, _deposit, msg.sender);
            }
            else{
                Config.incrementNonRevealCount(_lotteryRoundID, _campaignID, msg.sender);
            }
        }
    }

    /*
    * @dev return deposit and reward when user claim in case of error of Quanta
    *  
    */
    function returnDepositAndReward (uint256 _lotteryRoundID, uint256 _campaignID, uint256 _share, uint256 _deposit, address _to)
        internal
    {       
        DB.returnReward(_lotteryRoundID, _campaignID, _share, true, _to); 
        // subtract bounty first
        if (!_to.send(_share + _deposit)) 
        {
            DB.returnReward(_lotteryRoundID, _campaignID, _share, false, _to);
        }
        else
        {
            // LogBountyPayed(_lotteryRoundID, _campaignID, _to, _share, _deposit);
            if(_share != 0)
                LogBountyPayed(_lotteryRoundID, _campaignID, _to, _share, _deposit);
            else
                LogDepositReturned(_lotteryRoundID, _campaignID, _to, _deposit);
        }
    }   

    /*
    * @dev change address of fund keeper
    * @param _fundKeeper new address of fund keeper
    */
    function changeFundKeeperAddress(address _fundKeeper)
        onlyManagerMultiSig
    {
        fundKeeper = _fundKeeper;
    }

    /*
    * @dev change locked status
    */
    function changeLockedStatus()
        // internal
        onlyManagerMultiSig
    {
        locked = !locked;
    }

    /*
    * @dev withdraw all current fund to fund keeper
    * @dev only run when campaign is not started
    */
    function withdrawAllFund(uint256 _lotteryRoundID)
        onlyManagerMultiSig        
    {
        var (_campaignID, _bStart, _bFinalised, _failed) = DB.getInfoForRefundBounty(_lotteryRoundID);        

        //lock fund if not lock
        if(!locked){
            locked = !locked;
        }

        // processwithdrawAllFund(_bStart, _bFinalised, _failed);
        if(!_failed){
            throw;
        }

        // if not finished
        if (block.number < _bStart + _bFinalised)
            throw;
        if(_bStart == 0 || _bFinalised == 0)
            throw;
        
        if(!fundKeeper.send(this.balance)){
            locked = !locked;
            return;
        }
        locked = !locked;
    }
    // function getBounty(uint _lotteryRoundID) constant returns(uint256)
    // {
    //     return mapInit[_lotteryRoundID].bountypot;                
    // }
}
