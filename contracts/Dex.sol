//SPDX-License-Identifier: MIT

pragma solidity >0.6.0 >=0.8.19;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract dex {
    //Struct field
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    struct Order {
        uint256 id;
        Side side;
        bytes32 ticker;
        uint256 amount;
        uint256 filled;
        uint256 price;
        uint256 date;
    }
    enum Side {
        BUY,
        SELL
    }
    //Error Message
    error ONLY_ADMIN();
    error TOKEN_DOESNTEXIST();

    mapping(bytes32 => Token) public tokens;
    mapping(address => mapping(bytes32 => uint256)) public traderBalances;
    mapping(bytes32 => mapping(uint => Order[])) public orderBook;

    bytes32[] public tokenList;
    address public admin;
    uint256 nextOrderId;
    bytes32 constant DAI = bytes32("DAI");

    constructor() public {
        admin = msg.sender;
    }

    function addToken(bytes32 ticker, address tokenAddress) external onlyAdmin {
        tokens[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);
    }

    function deposit(
        bytes32 ticker,
        uint256 amount
    ) external tokenExist(ticker) {
        IERC20(tokens[ticker].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        traderBalances[msg.sender][ticker] += amount;
    }

    function withdraw(
        bytes32 ticker,
        uint256 amount
    ) external tokenExist(ticker) {
        require(
            traderBalances[msg.sender][ticker] >= amount,
            "Insufficient balance"
        );
        traderBalances[msg.sender][ticker] -= amount;
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, amount);
    }

    function createlimitOrder(
        bytes32 ticker,
        uint256 amount,
        uint256 price,
        Side side
    ) external tokenExist(ticker) {
        require(ticker != DAI, "Cant trade DAI");
        if (side == Side.SELL) {
            require(
                traderBalances[msg.sender][ticker] >= amount,
                " token balance too low"
            );
        } else {
            require(
                traderBalances[msg.sender][DAI] >= amount * price,
                "DAI balance is too low"
            );
        }
        //we create a pointer to hold the orders
        Order[] storage orders = orderBook[ticker][uint(side)];
        orders.push(
            Order(nextOrderId, side, ticker, amount, 0, price, block.timestamp)
        );
        //we need to keep the order array with the best prices at the begin using bubble sort algorithm
        uint256 i = orders.length - 1;
        while (i > 0) {
            if (side == Side.BUY && orders[i - 1].price > orders[i].price) {
                break;
            }
            if (side == Side.SELL && orders[i - 1].price < orders[i].price) {
                break;
            }
            //if only of the condition is trigger we need to swap
            Order memory order = orders[i - 1];
            orders[i - 1] = orders[i];
            orders[i] = order;
            i--;
        }
        nextOrderId++;
    }

    modifier tokenExist(bytes32 ticker) {
        //require(msg.sender == admin,"You are the Admin");
        if (tokens[ticker].tokenAddress == address(0)) {
            revert TOKEN_DOESNTEXIST();
        }
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert ONLY_ADMIN();
        }
        _;
    }
}
