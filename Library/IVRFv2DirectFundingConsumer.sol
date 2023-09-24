// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;
interface IVRFv2DirectFundingConsumer{
        function getRequestStatus(uint256 _requestId) external view returns (uint256 paid, bool fulfilled, uint256[] memory randomWords);
        function requestRandomWords(uint32 numWords) external returns (uint256 requestId);
}