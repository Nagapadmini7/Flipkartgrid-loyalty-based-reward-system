// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LoyaltyToken {
    string public name = "Loyalty Token";
    string public symbol = "LT";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public platform;
    uint256 public tokenValue;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public lastTransactionTimestamp;
    mapping(address => Transaction[]) public transactionHistory;
    mapping(address => bool) public authorizedBrands;

    struct Transaction {
        uint256 amount;
        uint256 timestamp;
        string description;
    }

    event TokenAwarded(
        address indexed user,
        uint256 amount,
        string description
    );
    event TokenRedeemed(
        address indexed user,
        uint256 amount,
        string description
    );
    event TokenValueUpdated(uint256 newValue);
    event TokenDecayed(address indexed user, uint256 decayedAmount);

    modifier onlyPlatform() {
        require(
            msg.sender == platform,
            "Only platform can call this function."
        );
        _;
    }

    modifier onlyAuthorizedBrands() {
        require(
            authorizedBrands[msg.sender],
            "Only authorized brands can call this function."
        );
        _;
    }

    constructor(uint256 _initialSupply) {
        platform = msg.sender;
        totalSupply = _initialSupply;
        balanceOf[platform] = _initialSupply;
    }

    function setTokenValue(uint256 _newValue) external onlyPlatform {
        tokenValue = _newValue;
        emit TokenValueUpdated(_newValue);
    }

    function authorizeBrand(address brandAddress) external onlyPlatform {
        authorizedBrands[brandAddress] = true;
    }

    function revokeBrandAuthorization(
        address brandAddress
    ) external onlyPlatform {
        authorizedBrands[brandAddress] = false;
    }

    function awardTokens(
        address user,
        uint256 amount,
        string memory description
    ) external onlyAuthorizedBrands {
        require(amount <= balanceOf[msg.sender], "Not enough tokens to award.");

        applyDecay(user);

        balanceOf[msg.sender] -= amount;
        balanceOf[user] += amount;
        lastTransactionTimestamp[user] = block.timestamp;

        transactionHistory[user].push(
            Transaction({
                amount: amount,
                timestamp: block.timestamp,
                description: description
            })
        );

        emit TokenAwarded(user, amount, description);
    }

    function redeemTokens(uint256 amount, string memory description) external {
        applyDecay(msg.sender);

        require(
            balanceOf[msg.sender] >= amount,
            "Not enough tokens to redeem."
        );

        balanceOf[msg.sender] -= amount;
        balanceOf[platform] += amount; // Tokens are returned to the platform.

        transactionHistory[msg.sender].push(
            Transaction({
                amount: amount,
                timestamp: block.timestamp,
                description: description
            })
        );

        emit TokenRedeemed(msg.sender, amount, description);
    }

    function applyDecay(address user) public {
        uint256 timeElapsed = block.timestamp - lastTransactionTimestamp[user];
        uint256 decayAmount = 0;

        if (timeElapsed > 120 days) {
            decayAmount = balanceOf[user]; // All tokens decay after 4 months.
        } else if (timeElapsed > 60 days) {
            decayAmount = (balanceOf[user] * 75) / 100; // 75% decay after 2 months.
        } else if (timeElapsed > 30 days) {
            decayAmount = (balanceOf[user] * 50) / 100; // 50% decay after 1 month.
        }

        balanceOf[user] -= decayAmount;
        totalSupply -= decayAmount; // The decayed amount is effectively burnt.

        emit TokenDecayed(user, decayAmount);
    }
}
