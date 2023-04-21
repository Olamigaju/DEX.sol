//SPDX-License-Identifier: MIT

pragma solidity >0.6.0 >=0.8.19;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract dex {
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    //Error Message
    error ONLY_ADMIN();
    error TOKEN_DOESNTEXIST();
    mapping(bytes32 => Token) public tokens;
    mapping(address => mapping(bytes32 => uint256)) public traderBalances;
    bytes32[] public tokenList;
    address public admin;

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
