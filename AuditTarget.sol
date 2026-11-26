// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// NT547 - Lab 06 - Hop dong rieng cua MSSV 23521493. KHONG deploy len mainnet.

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract CrowdFund_1493 {
    address public owner;
    mapping(address => uint256) public deposits;
    IERC20Like public usdt;
    mapping(address => uint256) public points;
    bool private busy;
    mapping(address => uint256) public safeBalances;

    event Deposited(address indexed who, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier serial() {
        require(!busy, "reentrant");
        busy = true;
        _;
        busy = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function stake() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function ownerWithdraw(uint256 amount) external onlyOwner {
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "withdraw failed");
    }

    function configureToken(address t) external onlyOwner {
        require(t != address(0), "zero");
        usdt = IERC20Like(t);
    }

    function redeemPoints(uint256 amount) external {
        require(address(usdt) != address(0), "zero token");
        require(points[msg.sender] >= amount, "not enough");
        points[msg.sender] -= amount;
        bool ok = usdt.transfer(msg.sender, amount);
        require(ok, "transfer failed");
    }

    function setAdmin(address newOwner) external {
        require(msg.sender == owner, "not owner");
        require(newOwner != address(0), "zero");
        owner = newOwner;
    }

    // slither-disable-next-line weak-prng
    function dayOfWeek() external view returns (uint256) {
        return (block.timestamp / 1 days + 4) % 7;
    }

    function saveSafe() external payable serial {
        safeBalances[msg.sender] += msg.value;
    }

    function withdrawSafe() external serial {
        uint256 a = safeBalances[msg.sender];
        require(a > 0, "no balance");
        safeBalances[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: a}("");
        require(ok, "send failed");
    }

    function closeVault() external onlyOwner {
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "close failed");
    }

    function rescueEth(address payable to) external onlyOwner {
        require(to != address(0), "zero");
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "rescue failed");
    }
}
