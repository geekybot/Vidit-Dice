pragma solidity ^0.4.23;
import "./AnteToken.Sol";

contract Dice
{
    struct History {
        address             playerAddress;
        string              player;
        uint256             userRoll;
        uint256             betAmount;
        uint256             time;
        uint256             roll;
        uint256             payoutAmount;
    }

    using SafeMath for uint256;

    History[]                           histories;
    address[]                           players;

    uint256 public diceRange = 100;
    uint256 public minimum = 1 trx;
    address public owner;

    address public          tokenAddress;
    AnteToken public        tokenContract;

    uint    constant private         STAGE_SETP_TOKEN = 1000000e8;
    uint    constant private         STAGE_STEP_TRX = 20;
    uint    constant private         BASE_TRX_TOKEN_RATIO = 1000;  

    mapping (address => uint256) frozenBalances;
    mapping (address => uint256) unfrozenBalances;

    uint256 public totalFrozenTokens;
    constructor() public
    {
        owner = msg.sender;
    }

    function setTokenContract(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(0x0));
        tokenAddress =  _tokenAddress;
        tokenContract = AnteToken(tokenAddress);
    }

    modifier onlyOwner()
    {
        require(msg.sender == owner);
        _;
    }

    function changeOwner(address _owner) onlyOwner public
    {
        owner = _owner;
    }

    /**
     * @dev Allows current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;

    }

    function sendTestTRX() public payable {

    }

    function rollDice(bool under, string player, uint256 userRoll, uint256 betAmount, uint256 payoutX) public payable {
        require(msg.value >= minimum);
        require(betAmount == msg.value);

        uint rand = uint(keccak256(block.timestamp));
        uint payout = 0;
        uint roll = rand % diceRange;

        if((under == true) && (roll < userRoll)) {
            payout = betAmount * payoutX / 100;
        }

        if((under == false) && (roll > userRoll)) {
            payout = betAmount * payoutX / 100;
        }

        if (tokenContract.balanceOf(msg.sender) == 0) {
            players.push(msg.sender);
        }
        _mineToken(msg.value, msg.sender);
        histories.push(History(msg.sender, player, userRoll, betAmount, block.timestamp, roll, payout));

        if (payout != 0) {
            if (address(this).balance > payout) {
                address(msg.sender).transfer(payout);
            }
            
        }
    }

    function _mineToken(uint256 trxValue, address sender) private {
        uint _minedSupply = tokenContract.minedSupply();
        uint trxTokenRatio = 1000 + _minedSupply / STAGE_SETP_TOKEN * 20;
        uint tokenToBeMined = trxValue / trxTokenRatio;

        tokenContract.mine(tokenToBeMined);
        unfrozenBalances[sender] = unfrozenBalances[sender].add(tokenToBeMined);
    }

    function withdrawToken(uint256 value) public {
        require(unfrozenBalances[msg.sender] >= value);
        require(tokenContract.balanceOf(address(this)) > value);

        // tokenContract.transfer(msg.sender, value);
        // unfrozenBalances[msg.sender] = unfrozenBalances[msg.sender].sub(value);

        tokenContract.transfer(msg.sender, unfrozenBalances[msg.sender]);
        unfrozenBalances[msg.sender] = 0;
    }

    function freezeToken(uint256 value) public {
        // require(unfrozenBalances[msg.sender] > value);
        // require(tokenContract.balanceOf(address(this)) > value);
        uint256 tokenFromWallet = tokenContract.balanceOf(msg.sender);
        tokenContract.freeze(msg.sender, tokenFromWallet);
        
        frozenBalances[msg.sender] = frozenBalances[msg.sender].add(tokenFromWallet);

        totalFrozenTokens = totalFrozenTokens.add(tokenFromWallet);
        // unfrozenBalances[msg.sender] = 0;
    }

    function unFreezeToken(uint256 value) public {
        require(frozenBalances[msg.sender] >= value);
        
        // frozenBalances[msg.sender] = frozenBalances[msg.sender].sub(value);
        // unfrozenBalances[msg.sender] = unfrozenBalances[msg.sender].add(value);
        unfrozenBalances[msg.sender] = unfrozenBalances[msg.sender].add(frozenBalances[msg.sender]);
        totalFrozenTokens = totalFrozenTokens.sub(frozenBalances[msg.sender]);
        frozenBalances[msg.sender] = 0;
        
    }

    function dailyReward() public {
        uint256 index = 0;
        uint256 reward = 0;
        uint256 contractTRXBalance = address(this).balance;

        uint256 rewardOwner = contractTRXBalance * 4 / 10;
        uint256 rewardPool = contractTRXBalance - rewardOwner;

        owner.transfer(rewardOwner);
        for(index = 0; index < players.length; index ++) {
            reward = rewardPool / totalFrozenTokens * frozenBalances[players[index]];
            if (address(this).balance >= reward) {
                players[index].transfer(reward);
            } else {
                players[index].transfer(address(this).balance);
            }
            
        }
    }

	/**
    * @dev Gets balance of the sender address.
    * @return An uint256 representing the amount owned by the msg.sender.
    */
    function checkContractBalance() public view returns (uint256) {
        return address(this).balance;

    }

    function checkHistoryLength() public view returns(uint256) {
        return histories.length;
    }

    function checkFrozenBalance() public view returns(uint256) {
        return frozenBalances[msg.sender];
    }

    function checkUnfrozenBalance() public view returns(uint256) {
        return unfrozenBalances[msg.sender];
    }

    function checkTotalFrozenTokens() public view returns(uint256) {
        return totalFrozenTokens;
    }

    function checkHistory(uint _id) public view returns(address playerAddress, string player, uint256 userRoll, uint256 betAmount, uint256 time, uint256 roll, uint256 payoutAmount) {
        History memory _history = histories[_id];
        return (_history.playerAddress, _history.player, _history.userRoll, _history.betAmount, _history.time, _history.roll, _history.payoutAmount);
    }

    function test() public view returns(address) {
        return tokenAddress;
    }
}
