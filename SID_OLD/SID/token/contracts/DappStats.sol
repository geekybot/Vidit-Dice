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

contract TRC20 is ITRC20 {
    using SafeMath for uint256;
    mapping (address => uint256)  _balances;
    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 _totalSupply;
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }
    function allowance(
        address owner,
        address spender
    )
    public
    view
    returns (uint256)
    {
        return _allowed[owner][spender];
    }
    
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    function transferFrom(
        address from,
        address to,
        uint256 value
    )
    public
    returns (bool)
    {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }
    function increaseAllowance(
        address spender,
        uint256 addedValue
    )
    public
    returns (bool)
    {
        require(spender != address(0));

        _allowed[msg.sender][spender] = (
        _allowed[msg.sender][spender].add(addedValue));
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    )
    public
    returns (bool)
    {
        require(spender != address(0));

        _allowed[msg.sender][spender] = (
        _allowed[msg.sender][spender].sub(subtractedValue));
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }
}

contract DappStats is TRC20 {

    string public name="DappStats";
    string public symbol="DST";
    uint public decimals=1;
    bool public locked;
    address public owner;
    address public crowdsale;
    address public divContract;
    address public advisor1;
    address public advisor2;
    address public advisor3;
    uint public vestingState;
    uint256 public time2020;
    uint256 public time2021;
    
    constructor(address _advisor1, address _advisor2, address _advisor3) public {
        _totalSupply = 1000000000;
        uint256 initialSupply = 850000000;
        _balances[msg.sender]=initialSupply;
        locked = true;
        owner = msg.sender;
        crowdsale = address(0);
        vestingState = 0;
        advisor1 = _advisor1;
        advisor2 = _advisor2;
        advisor3 = _advisor3;
        // real time
        time2020 = 1577836801;
        time2021 = 1609459201;
        
        // advisor1 = address(TDkV2yu5nkBLEWUrLNt5ySqNNXMHVd8HnX);
        // advisor2 = address(TLdYCXYRyKTWVU3jqmgWFo3hXcysxEtwVX);
        // advisor3 = address(TDgkF4Lb7NdNNY3XE7hxGsSHqKTQaSbZti);

        // fake advisors
        // advisor1 = address(TTadSKtZ67Mw7jxDRz43ctnr1rdvYmez91);
        // advisor2 = address(TSnjxMrK7D4RbwEruMAVvkRJy1i8M4vapw);
        // advisor3 = address(TSnjxMrK7D4RbwEruMAVvkRJy1i8M4vapw);
        
    }
    
    function unlockFunds() external payable {
        require(owner == msg.sender, "Only owner can lock funds");
        locked = false;
    }
    
    function setCrowdsale(address _crowdsale) external payable {
        require(owner == msg.sender, "Only owner can set crowdsale");
        require(crowdsale == address(0), "Crowdsale can be set only once");
        crowdsale = _crowdsale;
    }

    function setDivContract(address _divContract) external payable {
        require(owner == msg.sender, "Only owner can set div contract");
        require(divContract == address(0), "Crowdsale can be set only once");
        divContract = _divContract;
    }
    
    function transfer( address to, uint256 value) external returns(bool){
        require( !locked || owner == msg.sender || msg.sender == crowdsale, "tokens locked" );
        
        if((msg.sender == advisor1 || msg.sender == advisor2 || msg.sender == advisor3) && now < time2021) {
            require(to == divContract, "locked funds");
            _transfer(msg.sender, divContract, value);
            return true;
        } else {
            _transfer(msg.sender, to, value);
        }
        return true;
    }
    
    function withdrawTeamTokens() external returns(bool) {
        require(owner == msg.sender, "Only owner can allocate funds");
        require(vestingState == 0 || vestingState == 1, "tokens already allocated");
        uint256 value;
        if(vestingState == 0) {
            require(now > time2020, "vesting period");
            value = 40000000;
            _balances[advisor1] += value;
            _balances[advisor2] += value;
            _balances[advisor3] += value;
            vestingState = 1;
            return true;
        } else {
            require(now > time2021, "second vesting period");
            value = 30000000;
            _balances[advisor1] += value;
            vestingState = 2;
            return true;
        }
    }
}