//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DutchAuction.sol";

enum OrderState {
    Insuring,
    Insured,
    Claimed,
    Unclaimed,
    Cancelled
}

struct Order {
    uint256 id;
    address buyer;
    address seller;
    address insurer;
    uint256 amount;
    uint256 insurance;
    DutchAuction auction;
    OrderState state;
}

library OrderLib {
    using DutchAuctionLib for DutchAuction;

    modifier only(address addr) {
        require(msg.sender == addr);
        _;
    }

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

    function create(
        uint256 id,
        address seller,
        uint256 timespan,
        uint256 amount
    ) public returns (Order memory) {
        require(msg.value >= amount, "Order amount larger than amount paid!");
        uint256 prepaid_insurance = msg.value - amount;
        emit OrderCreated(id, msg.sender, seller, amount);
        DutchAuction memory auction = DutchAuctionLib.create(
            id,
            timespan,
            amount,
            amount - prepaid_insurance
        );
        return
            Order(
                id,
                msg.sender,
                seller,
                address(0),
                amount,
                prepaid_insurance,
                auction,
                OrderState.Insuring
            );
    }

    function cancel(Order storage order) public only(order.buyer) {
        require(order.state == OrderState.Insuring);
        order.state == OrderState.Cancelled;
        payable(order.buyer).transfer(order.amount + order.insurance);
        emit OrderCancelled(order.id);
    }

    function insure(Order storage order) public {
        require(order.state == OrderState.Insuring);
        order.state == OrderState.Insured;
        order.auction.place_bid();
        uint256 refund = order.insurance - (order.amount - msg.value);
        payable(order.buyer).transfer(refund);
        order.insurance = order.amount;
        order.insurer = msg.sender;
        payable(order.seller).transfer(order.amount);
        emit OrderInsured(order.id, msg.sender, msg.value);
    }

    function resolve(Order storage order, bool claim) public only(order.buyer) {
        require(msg.sender == order.buyer);
        require(order.state == OrderState.Insured);
        if (claim) {
            order.state = OrderState.Claimed;
            payable(order.buyer).transfer(order.insurance);
        } else {
            order.state = OrderState.Unclaimed;
            payable(order.insurer).transfer(order.insurance);
        }
        emit OrderResolved(order.id, claim);
    }
}
