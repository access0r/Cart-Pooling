// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract PoolBase is Ownable {
    using SafeMath for uint256;
    using Address for address;

    struct Pool {
        bytes32 id;
        address creator;
        uint256 goal;
        uint256 balance;
        address recipient;
        uint256 deadline;
        bool paused;
        mapping(address => uint256) contributors;
        mapping(address => bool) refunded;
    }

    mapping(bytes32 => Pool) public pools;

    function createPool(bytes32 id, address recipient, uint256 duration) public payable {
        require(pools[id].id == bytes32(0), "Pool already exists");
        require(msg.value > 0, "Invalid amount");
        require(duration > 0, "Invalid duration");

        Pool storage newPool = pools[id];
        newPool.id = id;
        newPool.creator = msg.sender;
        newPool.goal = msg.value;
        newPool.balance = 0;
        newPool.recipient = recipient;
        newPool.deadline = block.timestamp + duration;
        newPool.paused = false;

        emit PoolCreated(id, msg.sender, msg.value, recipient, block.timestamp + duration);
    }

    event PoolCreated(bytes32 indexed id, address indexed creator, uint256 goal, address recipient, uint256 deadline);
}
