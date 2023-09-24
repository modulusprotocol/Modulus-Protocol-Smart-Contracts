pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0

interface IRoleRegistry{
    function getRouter() external view returns(address);
    function getOwner() external view returns(address);
    function getController() external view returns(address);
    function getRewardDistributor() external view returns(address);
    function getOperator() external view returns(address);
    function getVRF() external view returns(address);
    function getReserveAddress() external view returns(address);
}