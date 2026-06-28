// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";
import {MockEntryPoint} from "../src/mock/MockEntryPoint.sol";
import {SimpleAccountFactory} from "../src/SimpleAccountFactory.sol";
import {MockPaymaster} from "../src/mock/MockPaymaster.sol";

contract DeployStep is Script {
    address sponsorSigner = vm.envAddress("SPONSOR_SIGNER_ADDRESS");

    function run() external {
        vm.startBroadcast();

        MockEntryPoint mockEntryPoint = new MockEntryPoint();
        SimpleAccountFactory factory = new SimpleAccountFactory(address(mockEntryPoint));
        MockPaymaster paymaster = new MockPaymaster(address(mockEntryPoint), sponsorSigner);

        Counter counter1 = new Counter();
        Counter counter2 = new Counter();

        vm.stopBroadcast();

        console2.log("MockEntryPoint:", address(mockEntryPoint));
        console2.log("Factory:", address(factory));
        console2.log("Counter1:", address(counter1));
        console2.log("Counter2:", address(counter2));
    }
}
