const { ethers, network } = require("hardhat");
const { assert, expect, use } = require("chai");
const chaiAsPromised = require("chai-as-promised");
use(chaiAsPromised);

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
    const [order, auction] = await events(contract.connect(buyer).create(sellerAddr, ethers.utils.parseEther("3"), { value: ethers.utils.parseEther("4") }));
    assert(order.event == "OrderCreated");
    assert(auction.event == "DutchAuctionCreated");
    return { order: order.args, auction: auction.args };
}


describe("PayProtector", function () {
    beforeEach(async function () {
        await hre.network.provider.send("hardhat_reset");
        [buyer, insurer] = Array.from({ length: 2 }, (_, i) => i).map(ethers.provider.getSigner);
        seller = ethers.Wallet.createRandom();
        [buyerAddr, sellerAddr, insurerAddr] = await Promise.all([buyer, seller, insurer].map(x => x.getAddress()));
    });

    it("Should create an order successfully", async function () {
        const contract = await deploy();

        const { order, auction } = await createOrder(contract);

        assert(order.id == 0);
        assert(order.buyer == buyerAddr);
        assert(order.seller == sellerAddr);
        expect(order.amount).to.equal(ethers.utils.parseEther("3"));

        assert(auction.id == 0);
        expect(auction.start_timestamp).to.be.within(now() - 1, now() + 1);
        assert(auction.timespan == 10);
        expect(auction.lowest_amount).to.equal(ethers.utils.parseEther("2"));
    });

    it("Should calculate the minimum bidding price correctly", async function () {
        const contract = await deploy();

        const { order: { id } } = await createOrder(contract);

        expect(await contract.min_bid(id)).to.equal(ethers.utils.parseEther("3"));

        await time_jump(2);
        expect(await contract.min_bid(id)).to.equal(ethers.utils.parseEther("2.8"));

        await time_jump(7);
        expect(await contract.min_bid(id)).to.equal(ethers.utils.parseEther("2.1"));

        await time_jump(1);
        expect(await contract.min_bid(id)).to.equal(ethers.utils.parseEther("2"));

        await time_jump(100);
        expect(await contract.min_bid(id)).to.equal(ethers.utils.parseEther("2"));
    });

    it("Should allow the buyer to cancel", async function () {
        const contract = await deploy();

        const { order: { id } } = await createOrder(contract);

        const [cancelled] = await events(contract.connect(buyer).cancel(id));

        assert(cancelled.event == "OrderCancelled");
        expect(cancelled.args.id).to.equal(id);
    });

    it("Should not allow an valid bid", async function () {
        const contract = await deploy();

        const { order: { id } } = await createOrder(contract);

        await time_jump(1);
        await expect(run(contract.connect(insurer).insure(id, { value: ethers.utils.parseEther("2.79") }))).to.eventually.rejected;
    });

    it("Should allow a valid bid", async function () {
        const contract = await deploy();

        const { order: { id } } = await createOrder(contract);

        expect(await ethers.provider.getBalance(sellerAddr)).to.equal(0);

        await time_jump(1);
        const [{ args: finished }] = await events(contract.connect(insurer).insure(id, { value: ethers.utils.parseEther("2.8") }));

        expect(finished.id).to.equal(id);
        expect(finished.insurer).to.equal(insurerAddr);
        expect(finished.amount).to.equal(ethers.utils.parseEther("2.8"));

        expect(await ethers.provider.getBalance(sellerAddr)).to.equal(ethers.utils.parseEther("3"));
    });

    it("Should allow the buyer to make a claim", async function () {
        const contract = await deploy();

        const { order: { id } } = await createOrder(contract);

        await time_jump(1);
        await events(contract.connect(insurer).insure(id, { value: ethers.utils.parseEther("2.8") }));

        const before = await ethers.provider.getBalance(buyerAddr);

        const [{ event, args }] = await events(contract.connect(buyer).resolve(id, true));

        expect(event).to.equal("OrderResolved");
        expect(args.id).to.equal(id);
        expect(args.claimed).to.equal(true);

        const after = await ethers.provider.getBalance(buyerAddr);

        assert(after - before > ethers.utils.parseEther("2.9"));
        assert(after - before < ethers.utils.parseEther("3.1"));

        expect(await ethers.provider.getBalance(contract.address)).to.equal(0);
    });

    it("Should allow the buyer to resolve without claiming", async function () {
        const contract = await deploy();

        const { order: { id } } = await createOrder(contract);

        await time_jump(1);
        await events(contract.connect(insurer).insure(id, { value: ethers.utils.parseEther("2.8") }));

        const before = await ethers.provider.getBalance(insurerAddr);

        const [{ event, args }] = await events(contract.connect(buyer).resolve(id, false));

        expect(event).to.equal("OrderResolved");
        expect(args.id).to.equal(id);
        expect(args.claimed).to.equal(false);

        const after = await ethers.provider.getBalance(insurerAddr);

        assert(after - before > ethers.utils.parseEther("2.9"));
        assert(after - before < ethers.utils.parseEther("3.1"));

        expect(await ethers.provider.getBalance(contract.address)).to.equal(0);
    });
});
