pragma solidity ^0.8.0;

contract FundPool {
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

    event PoolCreated(bytes32 indexed poolId, address indexed creator, uint256 goal, address indexed recipient, uint256 deadline);
    event Contributed(bytes32 indexed poolId, address indexed contributor, uint256 amount);
    event PoolClosed(bytes32 indexed poolId);
    event PoolRefunded(bytes32 indexed poolId, address indexed contributor, uint256 amount);
    event PoolPaused(bytes32 indexed poolId, bool paused);
    event PoolDeleted(bytes32 indexed poolId);
    event PoolExecuted(bytes32 indexed poolId, address indexed recipient, uint256 amount, bytes data);

    function createPool(bytes32 id, address recipient, uint256 duration) public payable {
        require(pools[id].id == bytes32(0), "Pool already exists");
        require(msg.value > 0, "Invalid amount");
        require(duration > 0, "Invalid duration");

        pools[id] = Pool({
            id: id,
            creator: msg.sender,
            goal: msg.value,
            balance: 0,
            recipient: recipient,
            deadline: block.timestamp + duration,
            paused: false
        });

        emit PoolCreated(id, msg.sender, msg.value, recipient, block.timestamp + duration);
    }

    function contribute(bytes32 id) public payable {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(!pool.paused, "Pool is paused");
        require(block.timestamp < pool.deadline, "Pool has expired");
        require(msg.value > 0, "Invalid amount");

        pool.contributors[msg.sender] += msg.value;
        pool.balance += msg.value;

        emit Contributed(id, msg.sender, msg.value);
    }

    function closePool(bytes32 id) public {
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

    function refundPool(bytes32 id) public {
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

    function pausePool(bytes32 id, bool paused) public {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(msg.sender == pool.creator, "Unauthorized");

        pool.paused = paused;

        emit PoolPaused(id, paused);
    }

    function deletePool(bytes32 id) public {
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

    function execute(bytes32 id, address to, uint256 value, bytes memory data) public {
        Pool storage pool = pools[id];
        require(pool.id != bytes32(0), "Pool does not exist");
        require(msg.sender == pool.creator, "Unauthorized");
        require(pool.balance >= pool.goal, "Goal not reached");
    
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
