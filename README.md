# RNG

RNG (Random Number Generator) is a core part of any lottery system. Creating a secure and truly unpredictable RNG on the Ethereum blockchain was one of Quanta’s largest technical challenges. After researching, the project selected the decentralized, immutable and Ethereum-based Randao Algorithm whose process is outlined below.

# Randao

Quanta’s RNG relies upon the Randao process (detailed in diagrams below) to produce the random number required for selectding lottery prize winners. Randao accomplishes this by requiring outside participants (who have achieved the appropriate KYC 3 verification level by submitting a passport photo, photo with passport and proof of address) to commit a random hashing number to the automated API and socket server using their Randao Wallets. An Ether deposit is required to join the Randao process. Upon successful completion of Randao (i.e. the player did not turn off his/her computer, lose internet connection or try and manipulate the process) the Ether is returned to each participant’s Randao Wallet with an additional bounty as incentive to participate in Randao. Once enough hashing numbers have been committed by outside players, the reveal process begins. During the reveal process all hashing numbers are collected to generate the essential Randao Final Number by using XOR: ‘bitwise exclusive or’ operator ^.

<b>References:</b>
<br>https://solidity.readthedocs.io/en/develop/types.html
<br>https://github.com/randao/randao

<br>

![Alt text](https://www.quanta.im/wp-content/uploads/2017/06/11702.png "Optional title")

# Important Functions

### reveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s, address msg)

Participants call this function to reveal their secret number.

```js
function reveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s, address msg) 
    onlyRandao
{
    Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
    c.participants[msg].secret = _s;
    c.revealsNum++;
    c.random ^= c.participants[msg].secret;
}
```

### mainLotteryReveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s)

Lottery manager reveals secret number

```js
function mainLotteryReveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s)
    onlyAdmin
{
    Campaign c = mapCampaign[_lotteryRoundID][_campaignID];
    c.mainLotteryReveal = _s;
    c.random ^= c.mainLotteryReveal;
}
```

### operatorManagerReveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s)

Randao operator reveal secret number

```js
function operatorManagerReveal(uint256 _lotteryRoundID, uint256 _campaignID, uint256 _s) 
    onlyAdmin
{
    Campaign c = mapCampaign[_lotteryRoundID][_campaignID];        
    c.operatorReveal = _s;
    c.random ^= c.operatorReveal;
}
```
