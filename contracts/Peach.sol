// contracts/Peach.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract Peach is ERC20, Pausable, Ownable {
    uint256 public constant RESERVE = 6727500 ether;
    uint256 public constant MAX_SUPPLY = 250000000 ether;
    uint256 public constant WUKONG_DAILY_REWARD = 20 ether;
    uint256 public constant BAEPE_DAILY_REWARD = 10 ether;

    uint256 public constant NUM_WUKONGS = 2222;
    uint256 public constant NUM_BAEPES = 2221;

    address public authSigner;
    uint256 public t0;

    mapping(uint256 => uint256) public stakedTime;
    mapping(uint256 => address) public staker;

    constructor(address _authSigner) ERC20("PEACH", "PEACH") {
        _mint(msg.sender, RESERVE);
        t0 = block.timestamp;
        authSigner = _authSigner;
        stakedTime[0] = block.timestamp + 365 * 50 days;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setAuthSigner(address _authSigner) public onlyOwner {
        authSigner = _authSigner;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "Token paused");
    }

    function _mint(address account, uint256 amount) internal virtual override {
        require(ERC20.totalSupply() + amount <= MAX_SUPPLY, "MAX_SUPPLY");
        super._mint(account, amount);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65, "invalid sig");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    function sendPrevEarnings(uint256 tokenId) private {
        super._mint(staker[tokenId], claimable(tokenId));
    }

    function claim(uint256[] calldata tokenIds) public {
		for (uint i=0; i<tokenIds.length; i++) {
            require(staker[tokenIds[i]] == msg.sender, "Access denied.");
            super._mint(msg.sender, claimable(tokenIds[i]));
            stakedTime[tokenIds[i]] = block.timestamp;
        }
    }

    function claimable(uint256 tokenId) public view returns (uint256 sum) {
        if (stakedTime[tokenId] == 0) return 0;
        uint256 daysStaked = (block.timestamp - stakedTime[tokenId]) / 1 days;
        uint256 dailyReward = isBaepe(tokenId) ? BAEPE_DAILY_REWARD : WUKONG_DAILY_REWARD;
        sum = daysStaked * dailyReward;
    }

    function isBaepe(uint256 tokenId) internal pure returns (bool) {
        return tokenId > NUM_WUKONGS ? true : false;
    }

    function stake(
        uint256[] calldata tokenIds,
        uint256 ts,
        bytes memory sig
    ) public {
        bytes memory b = abi.encodePacked(tokenIds, msg.sender, ts);
        require(recoverSigner(keccak256(b), sig) == authSigner, "Invalid sig");
        require(ts <= block.timestamp, "Invalid ts");

		for (uint i=0; i<tokenIds.length; i++) {
            require(staker[tokenIds[i]] != msg.sender, "Staked");
            require(tokenIds[i] <= NUM_BAEPES + NUM_WUKONGS, "Invalid token id");
            require(stakedTime[tokenIds[i]] < ts, "Time is a river");
            if (stakedTime[tokenIds[i]] > 0) sendPrevEarnings(tokenIds[i]);
            stakedTime[tokenIds[i]] = ts;
            staker[tokenIds[i]] = msg.sender;
        }
    }

    function listStakedTokens(address wallet) public view returns (uint256[] memory, uint256[] memory) {
        uint256 count = countStakedTokens(wallet);
        uint256[] memory staked = new uint256[](count);
        uint256[] memory stakeTimes = new uint256[](count);
        uint256 j;
        for (uint256 i=0; i<= NUM_BAEPES + NUM_WUKONGS; i++) {
            if (staker[i] == wallet) {
                staked[j] = i;
                stakeTimes[j++] = stakedTime[i];
            }
        }
        return (staked, stakeTimes);
    }

    function countStakedTokens(address wallet) public view returns (uint256 count) {
        count = 0;
        for (uint256 i=0; i<= NUM_BAEPES + NUM_WUKONGS; i++) {
            if (staker[i] == wallet) count++;
        }
    }
}
