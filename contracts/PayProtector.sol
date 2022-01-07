//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Order.sol";

contract PayProtector {
    using OrderLib for Order;

    event OrderCreated(
        uint256 id,
        address indexed buyer,
        address indexed seller,
        uint256 amount
    );
    event OrderCancelled(uint256 indexed id);
    event OrderInsured(
        uint256 indexed id,
        address indexed insurer,
        uint256 amount
    );
    event OrderResolved(uint256 indexed id, bool claimed);
    event DutchAuctionCreated(
        uint256 indexed id,
        uint256 start_timestamp,
        uint256 timespan,
        uint256 lowest_amount
    );
    event AuctionFinished(
        uint256 indexed id,
        address indexed insurer,
        uint256 amount
    );

    Order[] public orders;
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
        payable
        returns (uint256 id)
    {
        id = orders.length;
        orders.push(OrderLib.create(id, seller, auction_time, amount));
    }

    function cancel(uint256 id) external validate(id) {
        orders[id].cancel();
    }

    function insure(uint256 id) external payable validate(id) {
        orders[id].insure();
    }

    function min_bid(uint256 id)
        external
        view
        validate(id)
        returns (uint256 amount)
    {
        return orders[id].min_bid();
    }

    function resolve(uint256 id, bool claim) external validate(id) {
        orders[id].resolve(claim);
    }
}
