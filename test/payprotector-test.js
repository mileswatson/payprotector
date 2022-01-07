const { assert, expect } = require("chai");
const { ethers, network } = require("hardhat");

let buyer, seller, insurer, buyerAddr, sellerAddr, insurerAddr;

function now() {
    return Math.floor(Date.now() / 1000);
}

async function time_jump(seconds) {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}

async function deploy() {
    const PayProtector = await ethers.getContractFactory("PayProtector");
    const payProtector = await PayProtector.deploy(10);
    await payProtector.deployed();
    return payProtector;
}

async function run(transaction) {
    return await (await transaction).wait();
}

async function events(transaction) {
    return (await run(transaction)).events;
}

async function createOrder(contract) {
    const [order, auction] = await events(contract.connect(buyer).create(sellerAddr, 300, { value: 400 }));
    assert(order.event == "OrderCreated");
    assert(auction.event == "DutchAuctionCreated");
    return { order: order.args, auction: auction.args };
}


describe("PayProtector", function () {
    beforeEach(async function () {
        await hre.network.provider.send("hardhat_reset");
        [buyer, seller, insurer] = Array.from({ length: 3 }, (_, i) => i).map(ethers.provider.getSigner);
        [buyerAddr, sellerAddr, insurerAddr] = await Promise.all([buyer, seller, insurer].map(x => x.getAddress()));
    });

    it("Should create an order successfully", async function () {
        const contract = await deploy();

        const { order, auction } = await createOrder(contract);

        assert(order.id == 0);
        assert(order.buyer == buyerAddr);
        assert(order.seller == sellerAddr);
        assert(order.amount == 300);

        assert(auction.id == 0);
        expect(auction.start_timestamp).to.be.within(now() - 1, now() + 1);
        assert(auction.timespan == 10);
        assert(auction.lowest_amount == 200)
    });

    it("Should calculate the minimum bidding price correctly", async function () {
        const contract = await deploy();

        const { order: { id } } = await createOrder(contract);

        expect(await contract.min_bid(id)).to.equal(300);

        await time_jump(2);
        expect(await contract.min_bid(id)).to.equal(280);

        await time_jump(7);
        expect(await contract.min_bid(id)).to.equal(210);

        await time_jump(1);
        expect(await contract.min_bid(id)).to.equal(200);

        await time_jump(100);
        expect(await contract.min_bid(id)).to.equal(200);
    });
});
