// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

interface ISignals {
  /**
   * @notice Struct to store lock information for each lockup
   *
   * @param initiativeId ID of the initiative
   * @param tokenAmount Amount of tokens locked
   * @param lockDuration Total duration of the lock in intervals
   * @param created Timestamp of when the lock was created
   * @param withdrawn Flag indicating whether the locked tokens have been withdrawn
   */
  struct LockInfo {
    uint256 initiativeId;
    uint256 tokenAmount;
    uint256 lockDuration;
    uint256 created;
    bool withdrawn;
  }
}
