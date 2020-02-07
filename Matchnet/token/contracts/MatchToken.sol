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

contract MatchToken is TRC20 {
    using SafeMath for uint256;
    string public name="Match Token";
    string public symbol="MATCH";

    uint public decimals=6;
    bool public locked;
    address public owner;

    // addresses for token dividends playerdiv, luxe, gamedev, channelpartner
    // prizespromotion
    address public diceAddress;
    address public divContract;
    address public luxeTokenAddress;
    address public prizePool;
    // mapping (address => uint256) public balances;
    uint256 public _minedSupply;


    constructor(address _diceAddress, address _prizePool) public {
        _totalSupply = 500000000e6;
        _minedSupply = 0;
        locked = true;
        owner = msg.sender;
        diceAddress = _diceAddress;
        _balances[diceAddress] = 0;
        prizePool = _prizePool;
    }
    
    function unlockFunds() external payable {
        require(owner == msg.sender, "Only owner can unlock funds");
        locked = false;
    }
  
    function setDivContract(address _divContract) external payable {
        require(owner == msg.sender, "Only owner can set div contract");
        // require(divContract == address(0), "Crowdsale can be set only once");
        divContract = _divContract;
    }
    function setLuxeAddress(address _luxeAddress) external payable {
        require(owner == msg.sender, "Only owner can set Luxe Token Address");
        require(luxeTokenAddress == address(0), "Luxe Token Address can be set only once");
        luxeTokenAddress = _luxeAddress;
    }

    //mine tokens, that only can be done from rollcontract, or owner for offchain games
    // 50% player, 15% luxe, 10% gamedev, 20% channel partner, 5% prizes
    function mine(address _player, address _gameDevs, address _channelPartner, uint256 value) public {
        require(msg.sender == diceAddress || msg.sender == owner);
        uint256 toBeMined = value.mul(2);
        balances[_player] = balances[_player].add(value);
        balances[luxeTokenAddress] = balances[luxeTokenAddress].add(toBeMined.mul(15).div(100));
        balances[_gameDevs] = balances[_gameDevs].add(toBeMined.mul(10).div(100));
        balances[_channelPartner] = balances[_channelPartner].add(toBeMined.mul(20).div(100));
        balances[prizePool] = balances[private].add(toBeMined.mul(5).div(100));
        _minedSupply = _minedSupply.add(toBeMined);
    }
    
    
    function transfer( address to, uint256 value) external returns(bool){
        require( !locked || owner == msg.sender );
        
        if((msg.sender == advisor1 || msg.sender == advisor2 || msg.sender == advisor3) && now < time2021) {
            require(to == divContract, "locked funds");
            _transfer(msg.sender, divContract, value);
            return true;
        } else {
            _transfer(msg.sender, to, value);
        }
        return true;
    }
    
    
}