// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LoyaltyToken is ERC20, ReentrancyGuard {
    address public platform;
    uint public tokenValue;

    mapping(address => bool) public isAuthorizedBrand;
    mapping(address => uint) public lastActiveTimestamp;
    mapping(address => address) public referrals; // A map of user => referrer

    event TokenAwardedUponPurchase(address indexed user, uint amount);
    event BrandAuthorized(address indexed brand);
    event BrandRevoked(address indexed brand);

    modifier onlyPlatform() {
        require(
            msg.sender == platform,
            "Only the platform can perform this action"
        );
        _;
    }

    modifier onlyAuthorizedBrands() {
        require(
            isAuthorizedBrand[msg.sender],
            "Only authorized brands can perform this action"
        );
        _;
    }

    constructor(address _platform) ERC20("Flipkart Loyalty Token", "FLT") {
        platform = _platform;
        isAuthorizedBrand[platform] = true;
    }

    function setTokenValue(uint _newValue) external onlyPlatform {
        tokenValue = _newValue;
    }

    function authorizeBrand(address brand) external onlyPlatform {
        isAuthorizedBrand[brand] = true;
        emit BrandAuthorized(brand);
    }

    function revokeBrand(address brand) external onlyPlatform {
        isAuthorizedBrand[brand] = false;
        emit BrandRevoked(brand);
    }

    function awardTokensUponPurchase(
        address user,
        uint amount
    ) external onlyAuthorizedBrands {
        _mint(user, amount);
        emit TokenAwardedUponPurchase(user, amount);
    }

    function setReferrer(address referrer) external {
        // A user can set a referrer only if they haven't set one before
        require(referrals[msg.sender] == address(0), "Referrer already set");
        referrals[msg.sender] = referrer;
    }

    function rewardReferral(
        address user,
        uint amount
    ) external onlyAuthorizedBrands {
        address referrer = referrals[user];
        if (referrer != address(0)) {
            _mint(referrer, amount);
        }
    }

    // A decay function to reduce token balance over time, similar to the previous mechanism
    function applyDecay(address user) public {
        uint256 timeElapsed = block.timestamp - lastActiveTimestamp[user];
        uint256 decayAmount = 0;

        if (timeElapsed > 120 days) {
            decayAmount = balanceOf(user);
        } else if (timeElapsed > 60 days) {
            decayAmount = balanceOf(user) / 4; // Lose 25% after 2 months
        } else if (timeElapsed > 30 days) {
            decayAmount = balanceOf(user) / 2; // Lose 50% after 1 month
        }

        if (decayAmount > 0) {
            _burn(user, decayAmount);
        }
    }

    function redeemTokens(uint amount) external nonReentrant {
        require(balanceOf(msg.sender) >= amount, "Insufficient tokens");
        _burn(msg.sender, amount);
    }
}
