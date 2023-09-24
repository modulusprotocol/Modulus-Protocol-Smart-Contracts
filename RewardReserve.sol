pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "Library/IMutualPool.sol";
import "Library/IRoleRegistry.sol";
import "Library/IRouter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract RewardReserve{
    address registryContract;
    bool initialized;
    using SafeERC20 for IERC20;
    modifier onlyOwner(){
        address role = IRoleRegistry(registryContract).getOwner();
        require(msg.sender == role, "Invalid caller");
        _;
    }
    modifier onlyValidPool{
        address router = IRoleRegistry(registryContract).getRouter();
        require(IRouter(router).isPoolAllowed(msg.sender),"Invalid caller");
        //require(IRouter(router).isPoolAllowed(msg.sender));
        _;
    }

    function initialize(address registryAddress) external{
        require(initialized == false, "Contract is initialized already");
        _transferRegistryAddr(registryAddress);
        initialized = true;
    }

    function _transferRegistryAddr(address registryAddress) internal{
        registryContract = registryAddress;
    }

    function changeRegistryContractAddr(address registryAddress) external onlyOwner{
        _transferRegistryAddr(registryAddress);
    }


    function transferReward(address token, uint256 amount, address to) external onlyValidPool{
        IERC20(token).safeTransfer(to,amount);
    }
}