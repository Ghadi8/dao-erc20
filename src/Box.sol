// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_number;

    constructor() Ownable(msg.sender) {}

    event NumberChanged(uint256 number);

    function store(uint256 number) public onlyOwner {
        s_number = number;
        emit NumberChanged(number);
    }

    function getNumber() public view returns (uint256) {
        return s_number;
    }
}
