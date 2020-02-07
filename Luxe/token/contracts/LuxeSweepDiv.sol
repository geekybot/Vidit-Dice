pragma solidity ^0.4.25;

library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); 
        uint256 c = a / b;
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

interface ITRC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
    external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value)
    external returns (bool);

    function transferFrom(address from, address to, uint256 value)
    external returns (bool);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract LuxeSweepDiv {
    
    using SafeMath for uint256;

    // ///////////////////////////////////

    // luxe
    ITRC20 private luxe;
    ITRC20 private match;

    // owner address
    address public owner;
    address public admin;
    address public ownerCandidate;

    // total tokens shares & divs
    uint256 public totalToken; // total luxesweep locked
    uint256 public totalMatch; // total match stored in contract  ( yet to be distributed + already distibuted but not withdrawn yet, not direct trx transfer )
    uint256 public divBalanceMatch; // div balance left 
    uint256 public grandSumMatchStored; // total trx divs stored by owner till date
    uint256 public dailyPercent;

    // user props
    struct user {
        uint256 divBalance;
        uint256 share;
        bool unfreezeInProcess;
        uint256 unfreezeAmount;
        uint256 unfreezeTime; 
    }
    address[] public userbase; 
    mapping(address => bool) userExist;
    mapping(address => user) users;

    // ///////////////////////////////////

    event Frozen(address user, uint256 value);
    event UnfrozenRequest(address user, uint256 value, uint256 unfreezeTime);
    event Unfrozen(address user, uint256 value);
    event DivDeposited(uint256 value);
    event Withdrawal(address user, uint256 value);
    event Distributed(uint256 indexer, uint256 value);
    
    // ///////////////////////////////////
    // Owner functions

    constructor(ITRC20 _luxe, ITRC20 _match) public {
        owner = msg.sender;
        luxe = _luxe;
        match = _match;
        dailyPercent = 10;
    }

    modifier onlyOwner() {
        require( msg.sender == owner, "only owner can call this function");
        _;
    }

    modifier onlyAdmin() {
        require( msg.sender == admin, "only admin can call this function");
        _;
    }

    function changeOwner(address newOwner) onlyOwner public {
        ownerCandidate = newOwner;
    }

    function takeOwnership() public {
        require(msg.sender == ownerCandidate, "only candidates can call");
        owner = ownerCandidate;
    }

    function changeAdmin(address newAdmin) onlyOwner public {
        admin = newAdmin;
    }

    function changeDistributionPercent(uint256 percent) onlyOwner public {
        dailyPercent = percent;
    }



    // withdraw direct trx tranfered to contracts
    function withdrawAllExtraTrx() onlyOwner public {
        address(owner).transfer(address(this).balance - totalTrx);
    }

    // deposit trx divs
    function depositDiv() onlyOwner public payable {
        // transfer to luxe with users reciever
        totalTrx = totalTrx.add(msg.value);
        divBalanceTrx = divBalanceTrx.add(msg.value);
        grandSumTrxStored = grandSumTrxStored.add(msg.value);
        emit DivDeposited(msg.value);
    }

    // daily triggered function
    function divDistribution(uint256 indexer) onlyAdmin public {
        uint256 amtToDist = divBalanceTrx.mul(dailyPercent).div(100);
        uint256 i = indexer * 100;
        require(i < userbase.length, "invalid params");
        uint256 ii = i;
        uint256 dis = 0;
        for(i ; i < userbase.length && i < ii + 100; i ++ ) {
            users[userbase[i]].divBalance = users[userbase[i]].divBalance.add(users[userbase[i]].share.mul(amtToDist).div(totalToken));
            dis = dis.add(users[userbase[i]].share.mul(amtToDist).div(totalToken));
        }
        
        divBalanceTrx = divBalanceTrx.sub(dis);
        emit Distributed(indexer, dis);
    }

    // all triggered function
    function CompleteDivDistribution(uint256 indexer) onlyOwner public {
        uint256 amtToDist = divBalanceTrx;
        uint256 i = indexer * 100;
        require(i < userbase.length, "invalid params");
        uint256 ii = i;
        uint256 dis = 0;
        for(i ; i < userbase.length && i < ii + 100; i ++ ) {
            users[userbase[i]].divBalance = users[userbase[i]].divBalance.add(users[userbase[i]].share.mul(amtToDist).div(totalToken));
            dis = dis.add(users[userbase[i]].share.mul(amtToDist).div(totalToken));
        }
        divBalanceTrx = divBalanceTrx.sub(dis);
        emit Distributed(indexer, dis);
    }

    // ///////////////////////////////////
    // User functions

    // freeze dst tokens transfer
    function freeze(uint256 value) public {
        require(luxe.allowance(msg.sender, address(this)) >= value, "invalid request");
        require(luxe.balanceOf(msg.sender) >= value, "insufficient balance");
        if(!userExist[msg.sender]) {
            userExist[msg.sender] = true;
            userbase.push(msg.sender);
        }
        luxe.transferFrom(msg.sender, address(this), value);
        users[msg.sender].share = users[msg.sender].share.add(value);
        totalToken = totalToken.add(value);
        emit Frozen(msg.sender, value);
    }

    // unfreeze request dst tokens
    function unfreezeRequest(uint256 value) public {
        require(users[msg.sender].share >= value);
        require(!users[msg.sender].unfreezeInProcess, "another unfreeze already in progress");
        users[msg.sender].share = users[msg.sender].share.sub(value);
        users[msg.sender].unfreezeAmount = value;
        users[msg.sender].unfreezeInProcess = true;
        // users[msg.sender].unfreezeTime = now + 172800; // 48 hours
        users[msg.sender].unfreezeTime = now + 120; // 2 mins for testing
        totalToken = totalToken.sub(value);
        emit UnfrozenRequest(msg.sender, value, users[msg.sender].unfreezeTime);
    }

    // unfreeze dst tokens
    function unfreeze() public {
        require(now > users[msg.sender].unfreezeTime, "wait for unlock timer" );
        require(users[msg.sender].unfreezeInProcess, "no live unfreeze request");
        users[msg.sender].unfreezeInProcess = false;
        uint256 value = users[msg.sender].unfreezeAmount;
        luxe.transfer(msg.sender, value);
        users[msg.sender].unfreezeAmount = 0;
        emit Unfrozen(msg.sender, value);
    }

    // withdraw div Match
    function withdraw(uint256 value) public {
        // transfer to luxe with users reciever
        require(users[msg.sender].divBalance >= value);
        users[msg.sender].divBalance = users[msg.sender].divBalance.sub(value);
        totalMatch = totalMatch.sub(value);
        // address(msg.sender).transfer(value);
        match.transfer(msg.sender, value);
        emit Withdrawal(msg.sender, value);
    }


    ////////////////////////////////////////// 
    // get functions

    function getUser(address u) public view returns( bool userExists, uint256 divBalance, uint256 share, bool unfreezeInProcess, uint256 unfreezeAmount, uint256 unfreezeTime ) {
        return(userExist[u], users[u].divBalance, users[u].share, users[u].unfreezeInProcess, users[u].unfreezeAmount, users[u].unfreezeTime);
    }

    function getUserLen() public view returns(uint256 userlength) {
        return userbase.length;
    }

}


