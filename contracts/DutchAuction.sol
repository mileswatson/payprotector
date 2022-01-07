//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct HighestBid {
    address bidder;
    uint256 amount;
}

struct DutchAuction {
    uint256 id;
    uint256 start_timestamp;
    uint256 timespan;
    uint256 highest_amount;
    uint256 lowest_amount;
    bool finished;
}

library DutchAuctionLib {
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

    function create(
        uint256 id,
        uint256 timespan,
        uint256 highest_amount,
        uint256 lowest_amount
    ) public returns (DutchAuction memory) {
        emit DutchAuctionCreated(id, block.timestamp, timespan, lowest_amount);
        return
            DutchAuction(
                id,
                block.timestamp,
                timespan,
                highest_amount,
                lowest_amount,
                false
            );
    }

    function auto_accept_limit(DutchAuction storage auction)
        internal
        view
        returns (uint256)
    {
        if (block.timestamp < auction.start_timestamp) {
            return auction.highest_amount;
        } else if (
            block.timestamp <= auction.start_timestamp + auction.timespan
        ) {
            uint256 current_progress = block.timestamp -
                auction.start_timestamp;
            return
                auction.highest_amount -
                (((auction.highest_amount - auction.lowest_amount) *
                    current_progress) / auction.timespan);
        } else {
            return auction.lowest_amount;
        }
    }

    function place_bid(DutchAuction storage auction) public {
        require(!auction.finished, "Auction finished!");
        require(msg.value >= auto_accept_limit(auction), "Bid too low!");
        auction.finished = true;
        emit AuctionFinished(auction.id, msg.sender, msg.value);
    }
}
