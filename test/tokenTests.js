const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Mintium & Solythis Token Tests", function () {
  let mintium, solythis;
  let owner;
  const initialSupply = ethers.parseUnits("1000000000", 18); // 1B LYTH

  before(async function () {
    [owner] = await ethers.getSigners();

    // Deploy Mintium
    const Mintium = await ethers.getContractFactory("Mintium");
    mintium = await Mintium.deploy(owner.address);
    await mintium.waitForDeployment();

    // Deploy Solythis with initialSupply
    const Solythis = await ethers.getContractFactory("Solythis");
    solythis = await Solythis.deploy(owner.address, initialSupply); // ✅ Corrected constructor argument
    await solythis.waitForDeployment();
  });

  it("Should verify correct total supply for Mintium & Solythis", async function () {
    const mintiumSupply = await mintium.totalSupply();
    const solythisSupply = await solythis.totalSupply();

    expect(mintiumSupply).to.equal(ethers.parseUnits("100000000", 18)); // ✅ Correct total supply check
    expect(solythisSupply).to.equal(initialSupply); // ✅ Check correct total supply
  });
});
