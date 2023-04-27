//SPDX-License-Identifier: MIT

pragma solidity >0.6.0 >= 0.8.19;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlDefaultAdminRules.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";


contract dex is  AccessControlDefaultAdminRules{
     constructor()  AccessControlDefaultAdminRules(4 days, msg.sender){}
     using SafeMath for uint256;
    //Struct field
    struct Token{
        bytes32 ticker;
        address tokenAddress;
    }
    struct Order{
        uint256 id;
        address trader;
        Side side;
        bytes32 ticker;
        uint256 amount;
        uint256 filled;
        uint256 price;
        uint256 date;
    }
    enum Side{
        BUY,
        SELL
    }
    //Error Message
    error ONLY_ADMIN();
    error TOKEN_DOESNTEXIST();
    error CANT_TRADE_DAI();


    mapping(bytes32 => Token)public tokens;
    mapping(address => mapping(bytes32 => uint256))public traderBalances;
    mapping(bytes32 => mapping(uint => Order[]))public orderBook;

    event NewTrade(
        uint256 tradeId,
        uint256 orderId,
        bytes32 ticker,
        address trader1,
        address trader2,
        uint256 amount,
        uint256 price,
        uint256 date
    );

    bytes32[] public tokenList;
    address public admin;
    uint256 nextOrderId;
    uint256 nextTradeId;
    bytes32 constant DAI = bytes32('DAI');

   

    function addToken(bytes32  ticker, address tokenAddress)external onlyAdmin(){
        tokens[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);

    }

    function deposit(bytes32 ticker,
     uint256 amount)
     external
     tokenExist(ticker) 
     {
        
        IERC20(tokens[ticker].tokenAddress).transferFrom(msg.sender,address(this),amount);
        traderBalances[msg.sender][ticker] += amount;
    }
    function withdraw(bytes32 ticker, uint256 amount)
    external
    tokenExist(ticker)
    {
        require(traderBalances[msg.sender][ticker] >= amount,"Insufficient balance");
         traderBalances[msg.sender][ticker] -= amount;
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender,amount);
       

    }
    function createLimitOrder(
        bytes32 ticker,
        uint256 amount,
        uint256 price,
        Side side
    ) tokenExist(ticker) tokenIsNotDai(ticker) external{
        if(side == Side.SELL){
            require(traderBalances[msg.sender][ticker] >= amount,
            " token balance too low");

        }else{
            require(traderBalances[msg.sender][DAI] >= amount * price,
            "DAI balance is too low");
        }
        //we create a pointer to hold the orders
        Order[] storage orders = orderBook[ticker][uint(side)];
        orders.push(Order(
            nextOrderId,
            msg.sender,
            side,
            ticker,
            amount,
            0,
            price,
            block.timestamp
             
        ));
        //we need to keep the order array with the best prices at the begin using bubble sort algorithm
        uint256 i = orders.length - 1;
        while(i > 0){
            if(side == Side.BUY && orders[i - 1].price > orders[i].price){
                break;
            }
            if(side == Side.SELL && orders[i - 1].price < orders[i].price){
                break;
            }
            //if only of the condition is trigger we need to swap  
            Order memory order = orders[i-1];
            orders[i-1] = orders[i];
            orders[i] = order;
            i--;    
        }
          nextOrderId++;
    }
    function createMarketOrder(
        bytes32 ticker,
        uint256 amount,
        Side side
     )tokenExist(ticker) tokenIsNotDai(ticker)external{
        if(side == Side.SELL){
            require(traderBalances[msg.sender][ticker] >= amount,
            " token balance too low");
        }
        Order[] storage orders =orderBook[ticker][uint256(side == Side.BUY? Side.SELL:Side.BUY)];
        uint256 i;
        uint256 remaining = amount;
        while(i < orders.length && remaining >0){
            uint256 available = orders[i].amount - orders[i].filled;
            uint256 matched = (remaining > available)?available : remaining;
            remaining -= matched;
            orders[i].filled += matched;
            emit NewTrade(
                nextTradeId,
                orders[i].id,
                ticker,
                orders[i].trader,
                msg.sender,
                matched,
                orders[i].price,
                block.timestamp
             );
             if(side == Side.SELL){
                traderBalances[msg.sender][ticker] -= matched;
                traderBalances[msg.sender][DAI] += matched * orders[i].price;
                traderBalances[orders[i].trader][ticker] += matched;
                traderBalances[orders[i].trader][DAI] -= matched * orders[i].price;
             }
             if(side == Side.BUY){
                require(traderBalances[orders[i].trader][DAI] >= matched * orders[i].price,
                "Dai balance is low");
                traderBalances[msg.sender][ticker] += matched;
                traderBalances[msg.sender][DAI] -= matched * orders[i].price;
                traderBalances[orders[i].trader][ticker] -= matched;
                traderBalances[orders[i].trader][DAI] += matched * orders[i].price;
             }
             nextTradeId++;
             i++;               
        }
        i=0;
        while(i < orders.length && orders[i].amount == orders[i].filled){
            for(uint256 j=i; j < orders.length - j; j++){
                orders[j] = orders[j +1];
            }
            orders.pop();
            i++;
        }

    }
    modifier tokenIsNotDai(bytes32 ticker){
        if(ticker == DAI){
            revert CANT_TRADE_DAI();
        }
        _;
    }

     modifier tokenExist(bytes32 ticker){
        //require(msg.sender == admin,"You are the Admin");
        if(tokens[ticker].tokenAddress == address(0)){
            revert TOKEN_DOESNTEXIST();
        }
        _;

    }

    modifier onlyAdmin(){
        if(msg.sender != admin){
            revert ONLY_ADMIN();
        }
        _;

    }
}