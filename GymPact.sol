// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title GymPact - gym accountability escrow for USDC on Base
/// @notice Deploy it, then send USDC to the contract address.
///         - If you skip the gym, your friend calls `fail()` and gets all the USDC.
///         - If you stay consistent for 90 days, you call `withdraw()` and get it back.
contract GymPact {
    /// @dev Native USDC on Base mainnet.
    IERC20 public constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    uint256 public constant DURATION = 90 days; // the 3-month commitment
    uint256 public constant GRACE = 3 days; // extra time for the friend to judge the last week

    address public immutable me; // the gym-goer (deployer)
    address public immutable friend; // the accountability partner
    uint256 public immutable endsAt; // when the 3 months are over

    event Failed(address indexed friend, uint256 amount);
    event Succeeded(address indexed me, uint256 amount);

    constructor(address _friend) {
        require(_friend != address(0), "friend is zero address");
        require(_friend != msg.sender, "friend cannot be you");
        me = msg.sender;
        friend = _friend;
        endsAt = block.timestamp + DURATION;
    }

    /// @notice Friend presses this if you missed your 3 sessions in a week.
    ///         Sends the whole USDC balance to the friend.
    function fail() external {
        require(msg.sender == friend, "only friend");
        require(block.timestamp <= endsAt + GRACE, "too late, pact completed");
        uint256 amount = USDC.balanceOf(address(this));
        require(amount > 0, "nothing to claim");
        require(USDC.transfer(friend, amount), "transfer failed");
        emit Failed(friend, amount);
    }

    /// @notice You press this after 3 months (+ grace) to get your USDC back.
    function withdraw() external {
        require(msg.sender == me, "only me");
        require(block.timestamp > endsAt + GRACE, "pact still running");
        uint256 amount = USDC.balanceOf(address(this));
        require(amount > 0, "nothing to withdraw");
        require(USDC.transfer(me, amount), "transfer failed");
        emit Succeeded(me, amount);
    }

    /// @notice USDC currently locked (6 decimals: 100 USDC = 100000000).
    function locked() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    /// @notice Seconds left until you can withdraw (0 = you can withdraw now).
    function timeLeft() external view returns (uint256) {
        uint256 unlock = endsAt + GRACE;
        return block.timestamp > unlock ? 0 : unlock - block.timestamp + 1;
    }
}
