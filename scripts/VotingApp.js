import { useState, useEffect } from "react";
import { ethers } from "ethers";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export default function VotingApp() {
  const [walletAddress, setWalletAddress] = useState("");
  const [vote, setVote] = useState(null);
  const [message, setMessage] = useState("");

  async function connectWallet() {
    if (window.ethereum) {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const accounts = await provider.send("eth_requestAccounts", []);
      setWalletAddress(accounts[0]);
    } else {
      alert("Please install MetaMask to use this feature.");
    }
  }

  async function submitVote(choice) {
    if (!walletAddress) {
      alert("Please connect your wallet first.");
      return;
    }
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();
    const signature = await signer.signMessage(`Voting for: ${choice}`);
    setVote(choice);
    setMessage(`Vote submitted! Signed message: ${signature}`);
    // Store vote off-chain (Google Sheets, Database, Notion API, etc.)
  }

  return (
    <div className="flex flex-col items-center p-6">
      <Card className="w-full max-w-md">
        <CardContent>
          <h2 className="text-xl font-bold mb-4">Solythra Governance Voting</h2>
          <Button onClick={connectWallet} className="mb-4">
            {walletAddress ? `Connected: ${walletAddress.substring(0, 6)}...` : "Connect Wallet"}
          </Button>
          <div className="flex space-x-4">
            <Button onClick={() => submitVote("Option A")} disabled={!walletAddress}>Vote Option A</Button>
            <Button onClick={() => submitVote("Option B")} disabled={!walletAddress}>Vote Option B</Button>
          </div>
          {vote && <p className="mt-4">Your vote: <strong>{vote}</strong></p>}
          {message && <p className="text-sm text-gray-600 mt-2">{message}</p>}
        </CardContent>
      </Card>
    </div>
  );
}
