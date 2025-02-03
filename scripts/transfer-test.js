const hre = require("hardhat");

async function main() {
    const mintiumAddress = "0xb8F36458A5E8FD2fa9868De995752DAdd1d5293a";
    const solythisAddress = "0x344B3eEeE292506B1a2b141d52b61012A4962673";
    const recipient = "0x384F150324358b4C34928469603Fb62CDbD067fE"; // Replace with your test wallet

    const [deployer] = await hre.ethers.getSigners();
    
    const mintium = await hre.ethers.getContractAt("Mintium", mintiumAddress);
    const solythis = await hre.ethers.getContractAt("Solythis", solythisAddress);

    console.log(`💸 Sending 10 MNTM to ${recipient}...`);
    await mintium.transfer(recipient, hre.ethers.parseUnits("10", 18));
    
    console.log(`💸 Sending 10 LYTH to ${recipient}...`);
    await solythis.transfer(recipient, hre.ethers.parseUnits("10", 18));

    console.log("✅ Transfers Completed!");
}

main().catch((error) => {
    console.error("❌ Error:", error);
    process.exit(1);
});


