
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
pragma solidity ^0.8.21;
// SPDX-License-Identifier: GPL-3.0

contract ContractDeploymentFactory{
    event Deployed(address addressContract, uint salt);

    constructor(address owner) public{
        _transferOwnerShip(owner);
    }

    address owner;

    modifier onlyOwner(){
        require(msg.sender == owner, "Invalid caller");
        _;
    }
    
    function deploy(bytes memory bytecode, uint _salt, bytes calldata initData) public onlyOwner payable {
        address addr;
        //Rmb to add param for Constructor
        assembly {
            addr := create2(
                callvalue(),
                add(bytecode, 0x20),
                mload(bytecode), 
                _salt
            )

            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit Deployed(addr, _salt);
        (bool success, ) = addr.call(initData);
        require(success);
    }

    function _transferOwnerShip(address newOwner) internal{
        owner = newOwner;
    }

    function getOwner() external view returns(address){
        return owner;
    }

    function getBytecode(address _logic, address _admin, bytes memory optionalData) external view returns(bytes memory){
        bytes memory bytecode = type(TransparentUpgradeableProxy).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_logic, _admin,optionalData));
    }
}