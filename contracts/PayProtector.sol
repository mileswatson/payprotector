//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Order.sol";

contract PayProtector {
    using OrderLib for Order;

    Order[] orders;
    uint256 auction_time;

    constructor(uint256 _auction_time) {
        auction_time = _auction_time;
    }

    modifier validate(uint256 id) {
        require(id < orders.length);
        _;
    }

    function create(address seller, uint256 amount)
        external
        returns (uint256 id)
    {
        id = orders.length;
        orders.push(OrderLib.create(id, seller, auction_time, amount));
    }

    function cancel(uint256 id) external validate(id) {
        require(id < orders.length, "Invalid ID!");
        orders[id].cancel();
    }

    function insure(uint256 id) external payable validate(id) {
        require(id < orders.length, "Invalid ID!");
    }
}
