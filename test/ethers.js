const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Mintium Token Tests", function () {
  let mintium;
  let owner;

  before(async function () {
    [owner] = await ethers.getSigners();
    const Mintium = await ethers.getContractFactory("Mintium");
    mintium = await Mintium.deploy(owner.address);
    await mintium.waitForDeployment();
  });

  it("Should return the correct total supply", async function () {
    const totalSupply = await mintium.totalSupply();
    expect(totalSupply).to.equal(ethers.parseUnits("100000000", 18)); // ✅ Fixed `parseUnits`
  });
});
