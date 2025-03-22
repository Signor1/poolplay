// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

contract PoolPlayRouter is Ownable {
    IPoolManager public immutable manager;
    address public immutable hook;

    constructor(address _manager, address _hook) Ownable(msg.sender) {
        manager = IPoolManager(_manager);
        hook = _hook;
    }
}
