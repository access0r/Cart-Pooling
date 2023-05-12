// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PoolBase.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PoolOperations is PoolBase, ReentrancyGuard {

    function contribute(bytes32 id) public payable nonReentrant {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(!pool.paused, "Pool is paused");
        require(block.timestamp < pool.deadline, "Pool has expired");
        require(msg.value > 0, "Invalid amount");

        pool.contributors[msg.sender] += msg.value;
        pool.balance += msg.value;

        emit Contributed(id, msg.sender, msg.value);
    }

    function closePool(bytes32 id) public nonReentrant {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(msg.sender == pool.creator, "Unauthorized");

        uint256 amount = pool.balance;
        pool.balance = 0;

        emit PoolClosed(id);

        if (amount > 0) {
            payable(msg.sender).transfer(amount);
        }

        delete pools[id];
        emit PoolDeleted(id);
    }

    function refundPool(bytes32 id) public nonReentrant {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(pool.contributors[msg.sender] > 0, "Not a contributor");
        require(!pool.refunded[msg.sender], "Already refunded");

        uint256 amount = pool.contributors[msg.sender];
        pool.refunded[msg.sender] = true;

        emit PoolRefunded(id, msg.sender, amount);

        if (amount > 0) {
            payable(msg.sender).transfer(amount);
        }
    }

    function pausePool(bytes32 id, bool paused) public nonReentrant {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(msg.sender == pool.creator, "Unauthorized");

        pool.paused = paused;

        emit PoolPaused(id, paused);
    }

    function deletePool(bytes32 id) public nonReentrant {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(msg.sender == pool.creator, "Unauthorized");
        uint256 amount = pool.balance;
        pool.balance = 0;
        emit PoolClosed(id);

        if (amount > 0) {
            payable(msg.sender).transfer(amount);
        }
        delete pools[id];
        emit PoolDeleted(id);
    }

    function execute(bytes32 id, address to, uint256 value, bytes memory data) public nonReentrant {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(msg.sender == pool.creator, "Unauthorized");
        require(pool.balance >= pool.goal, "Goal not reached");
        require(block.timestamp < pool.deadline, "Pool has expired");
        require(to.isContract(), "Invalid contract address");

        (bool success,) = to.call{value: value}(data);
        require(success, "Transaction execution failed");

        uint256 amount = pool.balance;
        pool.balance = 0;

        emit PoolExecuted(id, to, amount, data);

        if (amount > 0) {
            payable(pool.recipient).transfer(amount);
        }

        delete pools[id];
        emit PoolDeleted(id);
    }

    // Events
    event Contributed(bytes32 indexed id, address indexed contributor, uint256 amount);
    event PoolClosed(bytes32 indexed id);
    event PoolDeleted(bytes32 indexed id);
    event PoolRefunded(bytes32 indexed id, address indexed contributor, uint256 amount);
    event PoolPaused(bytes32 indexed id, bool paused);
    event PoolExecuted(bytes32 indexed id, address to, uint256 amount, bytes data);
}

