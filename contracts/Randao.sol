pragma solidity ^0.4.11;

import "./RandaoConfig.sol";
import "./RandaoDB.sol";
import "./RandaoEvent.sol";
import "./Owned.sol";

contract Randao is Owned, RandaoEvent{
    address public adminAddress;
    RandaoConfig public Config;
    RandaoDB public DB;

    modifier onlyQuanta() {
        if (msg.sender != Config.quantaAddress()) 
            throw;
        _;
    }

    modifier onlyMultiSigManager()   {
        if(msg.sender != Config.multiSigManager()) 
            throw;
        _;
    }

    modifier notBlank(bytes32 _s) { 
        if (_s == "")
            throw;
        _;
    }

    modifier isLevel3(address _addr) {
        if (!Config.isLevel3(_addr))
            throw;
        _;
    }

    modifier isNotBlacklisted(address _participant) {
        if (Config.getNonRevealCount(_participant) >= Config.BLACKLIST_THRESHOLD())
            throw;
        _;
    }

    /*
    * @dev constructor 
    * @param _configAddress randao config address
    * @param _dbAddress randaodb address
    */    
    function Randao(address _configAddress, address _dbAddress)
    {
        Config = RandaoConfig(_configAddress);
        DB = RandaoDB(_dbAddress);
    }

    /*
    * @dev set config for RandaoConfig, RandaoDB and randaoadmin
    * @param _configAddress randao config address
    * @param _dbAddress randaodb address
    * @param _adminAddress randao admin address
    */
    function setConfig(address _configAddress, address _dbAddress, address _adminAddress)
        onlyMultiSigManager
    {
        Config = RandaoConfig(_configAddress);
        DB = RandaoDB(_dbAddress);
        adminAddress = _adminAddress;
    }          

    /*
    * @dev users commits their hashs
    * @param _lotteryRoundID lottery round id
    * @param _hashNumber hash of secret
    */
    function commit(uint256 _lotteryRoundID, bytes32 _hashNumber)
        payable
        isLevel3(msg.sender)
        isNotBlacklisted(msg.sender)
        notBlank(_hashNumber)
    {        
        uint256 _campaignID = DB.getCampaignID(_lotteryRoundID);

        var (_mainLotteryCommit, _operatorCommit) = DB.getLotteryAndOperatorCommit(_lotteryRoundID, _campaignID);

        // check if lottery or operator does not commit => throw
        if(_mainLotteryCommit == 0 || _operatorCommit == 0)
            throw;

        var (_deposit, _bStart, _bRevealsStart, _commitNumber) = DB.getCampaignInfoForCommit(_lotteryRoundID, _campaignID, msg.sender);

        // if user deposit matches with config value => throw
        if (msg.value != _deposit)
            throw;
        
        // if not in commit phase => throw
        if (block.number < _bStart)
            throw;
        if (block.number >= _bStart + _bRevealsStart)
            throw;
        if(_bStart == 0 || _bRevealsStart == 0)
            throw;

        // if commit number is blank => throw
         if (_commitNumber != "")
            throw;
        
        if(adminAddress.send(_deposit))
        {
            DB.commit(_lotteryRoundID, _campaignID, _hashNumber, msg.sender);

            LogCommit(_lotteryRoundID, _campaignID, _hashNumber);
        }
        else
        {
            LogCommit(_lotteryRoundID, _campaignID, 0);
        }
    }
    
     /*
    * @dev users reveal their secrets
    * @param _lotteryRoundID lottery round id
    * @param _secret hash of secret
    */
    function reveal(uint256 _lotteryRoundID, uint256 _secret)
    {
        var (_failed, _bStart, _bRevealsStart, _bFinaliseStart, _commitNum, _minParticipants, _campaignID) = DB.getCampaignInfoForReveal(_lotteryRoundID);

        // if campaign is failed => return
        if (_failed)
        {
            return;
        }

        // if not in reveal phase => return
        if (block.number < _bStart + _bRevealsStart)
            return;
        if (block.number >= _bStart + _bFinaliseStart)
            return;
        if(_bStart == 0 || _bRevealsStart == 0 || _bFinaliseStart == 0)
            return;

        // if secret doea not match commit value => return
        var _commitment = DB.getParticipantCommitHash(_lotteryRoundID, _campaignID, msg.sender);
        if (sha3(_secret) != _commitment)
            return;
        
        // if number of commit < minimum participant => return
        if (_commitNum < _minParticipants)
        {
            DB.failCampaign(_lotteryRoundID, _campaignID, 1);
            return;
        }

        // already revealed => throw
        if(DB.isRevealed(_lotteryRoundID, _campaignID, msg.sender))
        {
            return;
        }        

        DB.reveal(_lotteryRoundID, _campaignID, _secret, msg.sender);
        LogReveal(_lotteryRoundID, _campaignID, _secret);
    }

    /*
    * @dev get random number
    * @param _lotteryRoundID lottery round ID
    * @return random number in DB if randao finish successfully. If not settled, return 0
    */
    function getRandom(uint256 _lotteryRoundID)
        external
        returns (uint256)
    {
        var (_settled, _bStart, _bFinalised, _randomNumber) = DB.getRandom(_lotteryRoundID);

        // if randao is not finished => throw
        if (block.number < _bStart + _bFinalised)
            throw;
        if(_bStart == 0 || _bFinalised == 0) 
            throw;
        
        if (_settled == true) {
            return _randomNumber;
        }

        return 0;
    }
}
