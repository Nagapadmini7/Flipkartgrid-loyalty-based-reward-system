// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LoyaltyToken is ERC20, ReentrancyGuard {
    address public platform;
    uint public tokenValue;

    mapping(address => bool) public isAuthorizedBrand;
    mapping(address => uint) public lastActiveTimestamp;
    mapping(address => bool) public isApprovedUser;
    mapping(bytes32 => address) public referralLinks;
    mapping(address => bytes32) public recentReferralCode;

    event TokenAwardedUponPurchase(address indexed user, uint amount);
    event BrandAuthorized(address indexed brand);
    event BrandRevoked(address indexed brand);
    event UserApproved(address indexed user);
    event UserRevoked(address indexed user);
    event ReferralCodeGenerated(
        address indexed referrer,
        address indexed brand,
        bytes32 referralCode
    );
    event TokensDecayed(address indexed user, uint256 amount);

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

    modifier onlyApprovedUsers() {
        require(isApprovedUser[msg.sender], "You are not an approved user");
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

    function approveUser(address user) external onlyPlatform {
        isApprovedUser[user] = true;
        emit UserApproved(user);
    }

    function revokeUser(address user) external onlyPlatform {
        isApprovedUser[user] = false;
        emit UserRevoked(user);
    }

    function awardTokensUponPurchase(
        address user,
        uint amount
    ) external onlyAuthorizedBrands {
        _mint(user, amount);
        emit TokenAwardedUponPurchase(user, amount);
    }

    function generateReferralCode(
        address brand
    ) external onlyApprovedUsers returns (bytes32) {
        bytes32 code = keccak256(
            abi.encodePacked(msg.sender, block.timestamp, brand)
        );
        referralLinks[code] = msg.sender;
        recentReferralCode[msg.sender] = code;
        emit ReferralCodeGenerated(msg.sender, brand, code);
        return code;
    }

    function getRecentReferralCode(
        address user
    ) external view returns (bytes32) {
        return recentReferralCode[user];
    }

    function awardForReferralPurchase(
        bytes32 referralCode
    ) external onlyAuthorizedBrands {
        address referrer = referralLinks[referralCode];
        require(referrer != address(0), "Invalid referral code");
        _mint(referrer, 1 * (10 ** uint256(decimals()))); // Awarding 1 token for now, can be adjusted
    }

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
            emit TokensDecayed(user, decayAmount);
        }
    }
}
