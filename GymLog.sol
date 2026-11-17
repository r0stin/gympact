// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGymPact {
    function me() external view returns (address);
    function endsAt() external view returns (uint256);
}

/// @title GymLog - gym check-in calendar for GymPact contracts on Base
/// @notice One shared log for every GymPact. It holds no money and has no owner.
///         - Only a pact's gym-goer (`me`) can check in.
///         - Only for the current day: no backdating, no removing check-ins.
///         - Once per day, while the pact's 90 days are running.
///         Anyone can read the log.
contract GymLog {
    /// @dev Days roll over at midnight Toronto standard time (UTC-5).
    uint256 public constant TZ_SHIFT = 5 hours;
    uint256 public constant DURATION = 90 days; // same as GymPact

    /// @notice pact => bitmap of checked-in days (bit i = day i of the pact, day 0 = the start day).
    mapping(address => uint256) public checkIns;

    event CheckedIn(address indexed pact, uint256 indexed day);

    /// @notice Calendar day number (Toronto time) of a timestamp.
    function dayOf(uint256 ts) public pure returns (uint256) {
        return (ts - TZ_SHIFT) / 1 days;
    }

    /// @notice Today's day index for a pact: 0 on the start day, 90 on the last day.
    function today(address pact) public view returns (uint256) {
        return dayOf(block.timestamp) - dayOf(IGymPact(pact).endsAt() - DURATION);
    }

    /// @notice The gym-goer presses this on a day they trained.
    function checkIn(address pact) external {
        require(msg.sender == IGymPact(pact).me(), "only the gym-goer");
        uint256 endsAt = IGymPact(pact).endsAt();
        require(block.timestamp <= endsAt, "pact is over");
        uint256 day = dayOf(block.timestamp) - dayOf(endsAt - DURATION);
        uint256 bit = 1 << day;
        require(checkIns[pact] & bit == 0, "already checked in today");
        checkIns[pact] |= bit;
        emit CheckedIn(pact, day);
    }
}
