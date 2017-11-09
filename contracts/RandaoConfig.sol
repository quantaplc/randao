pragma solidity ^0.4.11;

import "./Owned.sol";
import "./../KYCInterface.sol";
import "./RandaoConfigEvent.sol";
import "./RandaoDB.sol";


contract RandaoConfig is Owned, RandaoConfigEvent{
    uint256 public DEPOSIT = 1000000000000000000; // wei  
    
    // integrate test with mainLottery contract
    uint256 public BREVEAL_START = 10;       
    uint256 public BFINAL_START = 20;       
    uint256 public BFINAL_STOP = 30;

    // uint256 public BREVEAL_START = 6;       
    // uint256 public BFINAL_START = 11;       
    // uint256 public BFINAL_STOP = 13;

    uint256 public MIN_PARTICIPANTS = 3;
    uint256 public MIN_REVEALS = 3;
    uint256 public BLACKLIST_THRESHOLD = 3;


	KYCInterface public kycContract;
    RandaoDB public DB;

    // integrate test with mainLottery contract
    // address public quantaAddress = address(0x9ae1c561dd6f452670d1fd4da98068872fc8ef90);
    // address public operatorManagerAddress = address(0xffc080dbf67feeb9030210db72633a87dc064c0b);
    // address public lotteryAddress = address(0x2f4ab098319a8447503c7089d0ae50bdcf3c71d1);	

    address public quantaAddress;
    address public operatorManagerAddress;
    address public lotteryAddress;
    address public radaoAddress;
    address public adminAddress;// randaoAdmin address

    address public multiSigManager;

    mapping (address => uint256) nonRevealCount;  
    mapping (uint256 => bool) mapLotteryStart;


    modifier moreThanZero(uint256 _deposit) { if (_deposit <= 0) throw; _; }

    modifier validateBlacklistThreshold(uint256 _blacklistThreshold) {
        if (_blacklistThreshold <= 0) throw;
        _;
    }

    modifier validateThresholds(uint256 _minParticipants, uint256 _minReveals) {
        if (_minParticipants <= 0 || _minReveals <= 0 || _minReveals > _minParticipants) throw;
        _;
    }    

    modifier check_bRevealStart(uint256 bStart, uint256 bRevealsStart, uint256 _bRevealsStart)
    {
        if(block.number >= bStart + bRevealsStart) throw;
        if(_bRevealsStart <= 0 || _bRevealsStart <= bRevealsStart)throw;    
        _;
    }       

    modifier check_bFinaliseStart(uint256 bStart, uint256 bFinaliseStart, uint256 _bFinaliseStart)
    {
        if(block.number >= bStart + bFinaliseStart)throw;
        if(_bFinaliseStart <= 0 || _bFinaliseStart <= bFinaliseStart)throw;     
        _;
    }    

    modifier check_bFinalised(uint256 bStart, uint256 bFinalised, uint256 _bFinalised)
    {
        if(block.number >= bStart + bFinalised)throw;
        if(_bFinalised <= 0 || _bFinalised <= bFinalised)throw;   

        _;     
    }    

    modifier checkCommitPhase(uint256 _bStart, uint256 _bRevealsStart) {
        if (block.number < _bStart) throw;
        if (block.number >= _bStart + _bRevealsStart) throw;
        if(_bStart == 0 || _bRevealsStart == 0)throw;
        _;
    }    

    modifier onlyQuanta() {
        if (msg.sender != quantaAddress) throw;
        _;
    }           

    modifier onlyAdmin() {
        if (msg.sender != adminAddress) throw;
        _;
    }  

    modifier onlyMultiSigManager()   {
        if(msg.sender != multiSigManager) throw;
        _;
    }

	function RandaoConfig(address _kycContract,address _multiSigManager, address _quantaAddress, address _operatorManagerAddress)
	{
        kycContract = KYCInterface(_kycContract);   	
        multiSigManager = _multiSigManager;
        quantaAddress = _quantaAddress;
        operatorManagerAddress = _operatorManagerAddress;
	}

    /*
    * @dev randao admin will call this function to set config params to randaoDB contract
    * @param _lotteryRoundID lottery ID
    */

    function start(uint256 _lotteryRoundID)
        onlyAdmin
    {       
        mapLotteryStart[_lotteryRoundID] = true;

        setConfig(_lotteryRoundID);
    }

    /*
    * @dev change multiSig Manager address
    * @param _multiSigManager new multiSig manager address
    */
    function setMultiSigManagerAddress(address _multiSigManager)
        public
        onlyMultiSigManager
    {
        multiSigManager = _multiSigManager;
    }

    /*
    * @dev change quanta account address
    * @param _qntAcc new quanta account address
    */
    function setQuantaAddress(address _qntAcc)
        onlyMultiSigManager
    {
        LogSetQuantaAddress(quantaAddress, _qntAcc);

        quantaAddress = _qntAcc;        
    }    

    /*
    * @dev change new operatorManager address
    * @param _operatorAcc new operatorManager address
    */
    function setOperatorManagerAddress(address _operatorAcc)
        onlyMultiSigManager
    {
        LogSetOperatorManagerAddress( operatorManagerAddress, _operatorAcc);

        operatorManagerAddress = _operatorAcc;        
    }

    /*
    * @dev change new lottery address
    * @param _lotteryAcc new lottery address
    */
    function setLotteryAddress(address _lotteryAcc)
        onlyMultiSigManager
    {
        LogSetLotteryAddress(lotteryAddress, _lotteryAcc);

        lotteryAddress = _lotteryAcc;        
    }    

    /*
    * @dev change new KYC address
    * @param _kycContract new KYC address
    */
    function setKycContract(address _kycContract)
        onlyMultiSigManager
    {
        LogSetKycContract(address(kycContract) , _kycContract);

        kycContract = KYCInterface(_kycContract);        
    }	

    /*
    * @dev change new randaoDB/randao/randaoAdmin address
    * @param _dbAddress new randaoDB address
    * @param _randaoAddress new randao address
    * @param _adminAddress new randaoAdmin address
    */
    function setModifyAddress(address _dbAddress, address _randaoAddress, address _adminAddress)
        onlyMultiSigManager
    {
        radaoAddress = _randaoAddress;
        adminAddress = _adminAddress;     

        DB = RandaoDB(_dbAddress);
        DB.setModifyAddress(_randaoAddress, _adminAddress); 
    }    

    /*
    * @dev verify address having KYC level3 or not
    * @param _addr address need to verify
    * @return true if having KYC level3 and vice versa
    */
    function isLevel3(address _addr)
        returns(bool)
    {
        if (!kycContract.hasKYC3(_addr)) return false;
        
        return true;
    }    

    /*
    * @dev increase non reveal number if there is a participant who do not reveal
    * @param _lotteryAcc lotteryID
    * @param _campaignID campaignID
    * @param _pAddr participant address    
    */
    function incrementNonRevealCount(uint256 _lotteryRoundID, uint256 _campaignID, address _pAddr)
        onlyAdmin
    {        
        nonRevealCount[_pAddr] = nonRevealCount[_pAddr] +1;
        if (getNonRevealCount(_pAddr) == BLACKLIST_THRESHOLD)
        { 
            LogBlacklisted(_lotteryRoundID, _campaignID, _pAddr);
        }
    }    

    /*
    * @dev get non reveal number of a participant
    * @param _participant address of participant
    * @return non revealed number of participant
    */
    function getNonRevealCount(address _participant) 
        returns (uint256) 
    {
        return nonRevealCount[_participant];
    }

    /*
    * @dev reset non reveal number of a participant
    * @param _participant address of participant
    */
    function resetNonRevealCount(address _participant)
        onlyQuanta
    {
        nonRevealCount[_participant] = 0;
        LogNonRevealCount(_participant, 0);
    }    

    /*
    * @dev when Campaign is started, config params will be stored in randaoDB
    * @param _lotteryRoundID lotteryID
    * @return _campaignID last campaign ID of lottery round 
    */
    function setConfig(uint256 _lotteryRoundID)
        internal
        returns(uint256)
    {
        uint256 _campaignID = DB.getCampaignID(_lotteryRoundID);
        DB.setConfig(_lotteryRoundID, _campaignID, DEPOSIT, BREVEAL_START, BFINAL_START, BFINAL_STOP, MIN_PARTICIPANTS, MIN_REVEALS);     

        return _campaignID;
    }

    /*
    * @dev set deposit value for each lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _deposit value of new deposit
    */
    function setDeposit(uint256 _lotteryRoundID, uint256 _deposit)
        onlyQuanta
        moreThanZero(_deposit)
    {    

        // if lottery has already started, do not allow to set new deposit
        var failed = DB.getFailedStatus(_lotteryRoundID);
        if(mapLotteryStart[_lotteryRoundID] && failed == false)
        {
            throw;
        }
        DEPOSIT = _deposit;
        // uint256 _campaignID = setConfig(_lotteryRoundID);
        LogSetDeposit(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _deposit);
    }

    /*
    * @dev set blacklist threshold value for each lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _blacklistThreshold value of new threshold
    */
    function setBlacklistThreshold(uint256 _lotteryRoundID, uint256 _blacklistThreshold)
        onlyQuanta
        validateBlacklistThreshold(_blacklistThreshold)
    {
        BLACKLIST_THRESHOLD = _blacklistThreshold;

        LogSetBlacklistThreshold(_blacklistThreshold);
    }     

    /*
    * @dev set threshold for mininum participants and minimum revealed number
    * @param _lotteryRoundID lottery round ID
    * @param _minParticipants new value of minimum participants
    * @param _minReveals new value of minimum revealed number
    */
    function setThresholds(uint256 _lotteryRoundID, uint256 _minParticipants, uint256 _minReveals)
        onlyQuanta
        validateThresholds(_minParticipants, _minReveals)
    {
        // if lottery has already started, do not allow to change
        var failed = DB.getFailedStatus(_lotteryRoundID);
        if(mapLotteryStart[_lotteryRoundID] && failed == false)
        {
            throw;
        }
        MIN_PARTICIPANTS = _minParticipants;
        MIN_REVEALS = _minReveals;
        
        LogSetThresholds(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _minParticipants, _minReveals);

        // var (deposit, bStart, bRevealsStart, bFinaliseStart, bFinalised, minParticipants, minReveals) = DB.getConfig(_lotteryRoundID);

        // setThresholdsCampaign(_lotteryRoundID, _minParticipants, _minReveals, bStart, bRevealsStart);
    }      

    /*
    * @dev set threshold for mininum participants, minimum revealed number, number of started block, number of revealed block
    * @param _lotteryRoundID lottery round ID
    * @param _minParticipants new value of minimum participants
    * @param _minReveals new value of minimum revealed number
    * @param _bStart new value of started block
    * @param _bRevealsStart new value of revealed block
    */
    function setThresholdsCampaign(uint256 _lotteryRoundID, uint256 _minParticipants, uint256 _minReveals, uint256 _bStart, uint256 _bRevealsStart)
        internal
        checkCommitPhase(_bStart, _bRevealsStart)
    {
        uint256 _campaignID = setConfig(_lotteryRoundID);

        LogSetThresholds(_lotteryRoundID, _campaignID, _minParticipants, _minReveals);        
    }

    /*
    * @dev set config for periods of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _bRevealsStart new value of revealed period
    * @param _bFinaliseStart new value of started finalised period
    * @param _bFinalised new value of stopped finalised period
    */
    function SetBlockConfiguration (uint256 _lotteryRoundID, uint256 _bRevealsStart, uint256 _bFinaliseStart, uint256 _bFinalised)
        onlyQuanta
    {
        // if lottery has already start, do not allow to change
        var failed = DB.getFailedStatus(_lotteryRoundID);
        if(mapLotteryStart[_lotteryRoundID] && failed == false)
        {
            throw;
        }
        BREVEAL_START = _bRevealsStart;       
        BFINAL_START = _bFinaliseStart;       
        BFINAL_STOP = _bFinalised;

        LogSetBRevealsStart(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bRevealsStart);
        LogSetBFinaliseStart(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bFinaliseStart);
        LogSetBFinaliseStop(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bFinalised);

        // var (deposit, bStart, bRevealsStart, bFinaliseStart, bFinalised, minParticipants, minReveals) = DB.getConfig(_lotteryRoundID);   
        // setBRevealsStartCampaign(_lotteryRoundID, bStart, bRevealsStart, _bRevealsStart);
        // setBFinaliseStartCampaign(_lotteryRoundID, bStart, bFinaliseStart, _bFinaliseStart);
        // setBFinalisedCampaign(_lotteryRoundID, bStart, bFinalised, _bFinalised);
        // LogSetRandaoBlockConfiguration(_lotteryRoundID,  DB.getCampaignID(_lotteryRoundID), bStart, _bRevealsStart, _bFinaliseStart, _bFinalised);        
    }

    /*
    * @dev set value for started revealed periods of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _bRevealsStart new value of revealed period
    */
    function setBRevealsStart(uint256 _lotteryRoundID, uint256 _bRevealsStart)
        onlyQuanta
    {     
        // if lottery has already start, do not allow to change
        var failed = DB.getFailedStatus(_lotteryRoundID);
        if(mapLotteryStart[_lotteryRoundID] && failed == false)
        {
            throw;
        }
        BREVEAL_START = _bRevealsStart;
        LogSetBRevealsStart(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bRevealsStart);

        // var (deposit, bStart, bRevealsStart, bFinaliseStart, bFinalised, minParticipants, minReveals) = DB.getConfig(_lotteryRoundID);
        // setBRevealsStartCampaign(_lotteryRoundID, bStart, bRevealsStart, _bRevealsStart);
    }

    /*
    * @dev set config for started revealed periods of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _bStart new value of started period
    * @param bRevealsStart current value of started revealed period
    * @param _bRevealsStart new value of started revealed period
    */
   function setBRevealsStartCampaign(uint256 _lotteryRoundID, uint256 bStart, uint256 bRevealsStart, uint256 _bRevealsStart) 
        internal
        check_bRevealStart(bStart, bRevealsStart, _bRevealsStart)
    {                    
        // uint256 _campaignID = setConfig(_lotteryRoundID);
        LogSetBRevealsStart(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bRevealsStart);  
    }  

    /*
    * @dev set config for started revealed periods of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _bRevealsStart new value of started revealed period
    */
    function setBFinaliseStart(uint256 _lotteryRoundID, uint256 _bFinaliseStart)
        onlyQuanta
    {
        // if lottery has already started, do not allow to change
        var failed = DB.getFailedStatus(_lotteryRoundID);
        if(mapLotteryStart[_lotteryRoundID] && failed == false)
        {
            throw;
        }
        BFINAL_START = _bFinaliseStart;
        LogSetBFinaliseStart(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bFinaliseStart);
        // var (deposit, bStart, bRevealsStart, bFinaliseStart, bFinalised, minParticipants, minReveals) = DB.getConfig(_lotteryRoundID);
        // setBFinaliseStartCampaign(_lotteryRoundID, bStart, bFinaliseStart, _bFinaliseStart);
    }    

    /*
    * @dev set config for started finalised periods of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _bStart new value of started period
    * @param bFinaliseStart current value of started finalised period
    * @param _bFinaliseStart new value of started finalised period
    */
    function setBFinaliseStartCampaign(uint256 _lotteryRoundID, uint256 bStart, uint256 bFinaliseStart, uint256 _bFinaliseStart)
        internal
        check_bFinaliseStart(bStart, bFinaliseStart, _bFinaliseStart)
    {        
        // uint256 _campaignID = setConfig(_lotteryRoundID);
        LogSetBFinaliseStart(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bFinaliseStart);
    }

    /*
    * @dev set config for finalised periods of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _bFinalised new value of finalised period
    */
    function setBFinalised(uint256 _lotteryRoundID, uint256 _bFinalised)
        onlyQuanta
    {
        // if lottery has already started, do not allow to change
        var failed = DB.getFailedStatus(_lotteryRoundID);
        if(mapLotteryStart[_lotteryRoundID] && failed == false)
        {
            throw;
        }
        BFINAL_STOP = _bFinalised;
        LogSetBFinaliseStop(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bFinalised);

        // var (deposit, bStart, bRevealsStart, bFinaliseStart, bFinalised, minParticipants, minReveals) = DB.getConfig(_lotteryRoundID);
        // setBFinalisedCampaign(_lotteryRoundID, bStart, bFinalised, _bFinalised);
    }

    /*
    * @dev set config for finalised periods of a lottery round
    * @param _lotteryRoundID lottery round ID
    * @param _bStart new value of started period
    * @param bFinalised current value of finalised period
    * @param _bFinalised new value of finalised period
    */
    function setBFinalisedCampaign(uint256 _lotteryRoundID, uint256 bStart, uint256 bFinalised, uint256 _bFinalised)
        internal
        check_bFinalised(bStart, bFinalised, _bFinalised)
    {                    
        uint256 _campaignID = setConfig(_lotteryRoundID);
        LogSetBFinaliseStop(_lotteryRoundID, DB.getCampaignID(_lotteryRoundID), _bFinalised);
    }     

}