pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0

interface IApeStakePool{
    function depositSelfApeCoin(uint256 _amount) external;
    function claimSelfApeCoin() external;
    function withdrawSelfApeCoin(uint256 _amount) external;
    function pendingRewards(uint256 _poolId, address _address, uint256 _tokenId) external view returns (uint256);
}