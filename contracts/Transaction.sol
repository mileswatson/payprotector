//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DutchAuction.sol";

enum TransactionState {
    Insuring,
    Insured,
    Claimed,
    Unclaimed,
    Cancelled
}

struct Transaction {
    uint256 id;
    address buyer;
    address seller;
    address insurer;
    uint256 amount;
    uint256 insurance;
    DutchAuction auction;
    TransactionState state;
}

library TransactionLib {
    using DutchAuctionLib for DutchAuction;

    function create(
        uint256 id,
        address seller,
        uint256 timespan,
        uint256 amount
    ) public returns (Transaction memory) {
        require(
            msg.value >= amount,
            "Transaction amount larger than amount paid!"
        );
        uint256 prepaid_insurance = msg.value - amount;
        DutchAuction memory auction = DutchAuctionLib.create(
            timespan,
            amount,
            amount - prepaid_insurance
        );
        return
            Transaction(
                id,
                msg.sender,
                seller,
                address(0),
                amount,
                prepaid_insurance,
                auction,
                TransactionState.Insuring
            );
    }

    function cancel(Transaction storage transaction) public {
        require(transaction.state == TransactionState.Insuring);
        require(msg.sender == transaction.buyer);
        transaction.state == TransactionState.Cancelled;
        payable(transaction.buyer).transfer(
            transaction.amount + transaction.insurance
        );
    }

    function insure(Transaction storage transaction) public {
        require(transaction.state == TransactionState.Insuring);
        transaction.state == TransactionState.Insured;
        transaction.auction.place_bid();
        uint256 refund = transaction.insurance -
            (transaction.amount - msg.value);
        payable(transaction.buyer).transfer(refund);
        transaction.insurance = transaction.amount;
        transaction.insurer = msg.sender;
        payable(transaction.seller).transfer(transaction.amount);
    }

    function resolve(Transaction storage transaction, bool claim) public {
        require(msg.sender == transaction.buyer);
        require(transaction.state == TransactionState.Insured);
        if (claim) {
            transaction.state = TransactionState.Claimed;
            payable(transaction.buyer).transfer(transaction.insurance);
        } else {
            transaction.state = TransactionState.Unclaimed;
            payable(transaction.insurer).transfer(transaction.insurance);
        }
    }
}
