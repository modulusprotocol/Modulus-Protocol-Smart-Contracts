pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0
interface IRewardReserve{
    function transferReward(address token, uint256 amount, address to) external;
}