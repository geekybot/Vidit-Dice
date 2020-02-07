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

contract TokenSale {
    //  using ITRC20 for ITRC20;
    uint256 tokenPrice = 1 trx;
    uint256 tokenFactor = 10;
    address owner;
    ITRC20 private token;
    event Purchased(address buyer, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this function");
        _;
    }
    
    constructor(ITRC20 _token)  public {
        owner = msg.sender;
        token = _token;
    }
    
    function getPrice() public view returns (uint) {
        return tokenPrice;
    }
    
    function updatePrice(uint newPrice) public onlyOwner {
        tokenPrice = newPrice;
    }
    
    function _buy() internal {
        uint tokenAmount = (msg.value / tokenPrice) * tokenFactor;
        require(token.balanceOf(address(this)) > tokenAmount );
        token.transfer(msg.sender, tokenAmount);
        address(owner).transfer(msg.value);
        emit Purchased(msg.sender, tokenAmount);   
    }
    
    function () external payable {
        _buy();
    }
    
    function buy() public payable {
        _buy();
    }
}