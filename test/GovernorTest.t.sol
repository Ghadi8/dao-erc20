// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/Governor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovernorToken} from "../src/GovToken.sol";

contract GovernorTest is Test {
    MyGovernor governor;
    GovernorToken token;
    TimeLock timelock;
    Box box;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public {
        token = new GovernorToken();
        token.mint(USER, AMOUNT);

        vm.startPrank(USER);
        token.delegate(USER);

        timelock = new TimeLock(MIN_DELAY, proposers, executors); // allow anyone to propose and execute when array is empty
        governor = new MyGovernor(token, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        console.log("Box Number", box.getNumber());
        uint256 valueToStore = 888;
        string memory description = "Store 1 in box";
        bytes memory funcCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        calldatas.push(funcCall);
        values.push(0);
        targets.push(address(box));

        // 1. Propose to the DAO

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        console.log("Proposal State", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State", uint256(governor.state(proposalId)));

        // 2. Vote

        string memory reason = "I like this proposal";

        uint8 voteFor = 1;

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteFor, reason);

        vm.warp(block.timestamp + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        console.log("Proposal State", uint256(governor.state(proposalId)));

        // 3. Queue the tx

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + 1);

        console.log("Proposal State", uint256(governor.state(proposalId)));

        // 4. Execute the tx

        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("Proposal State", uint256(governor.state(proposalId)));
        console.log("Box Number", box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
}
