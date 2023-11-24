// This js script helps in creating unsigned and signed RLP data for tests

const ethers = require("ethers");

const { Transaction, Wallet } = ethers;
const { decodeRlp, getBytes } = ethers;

const main = async () => {
  const wallet = new Wallet(process.env.PRIVATE_KEY);
  console.log("address of the wallet is", wallet.address);

  // for type 0 and type 1
  const tx = {
    to: "0x0000006f746865725f65766d5f61646472657373", // Replace with the recipient's address
    value: ethers.parseEther("0"), // Sending 0.1 Ether
    gasLimit: 2_000_000,
    gasPrice: ethers.parseUnits("1.0", "gwei"), // Gas price set to 1 Gwei
    nonce: 0, // You might want to retrieve and set the nonce if the account has other transactions
    chainId: 1,
    data: "0x371303c0", // replace with require calldata
  };

  // uncomment and use this for type 2 transaction
  // const tx = {
  //     // uniswap token address
  //     to: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",   // Replace with the recipient's address
  //     value: ethers.parseEther("0.1"),   // Sending 0.1 Ether
  //     gasLimit: 2_000_000,
  //     maxFeePerGas: ethers.parseUnits("1.0", "gwei"),  // Gas price set to 1 Gwei
  //     nonce: 0,  // You might want to retrieve and set the nonce if the account has other transactions
  //     chainId: 1,
  //     data: '0xabcdef'
  // };

  const tox = Transaction.from(tx);
  // choose the transaction type for which you want to RLP encode
  tox.type = 1;

  let signed_tx = await wallet.signTransaction(tox);

  console.log("unsigned serialized tx -----> ", tox.unsignedSerialized);
  console.log("unsigned transaction hash", tox.hash);

  // const bytes = getBytes(signedTX);
  const bytes = getBytes(tox.unsignedSerialized);

  console.log("unsigned RLP encoded bytes for the transaction: ");

  // this prints unsigned RLP encoded bytes of the transaction
  bytes.forEach((v) => {
    console.log(v, ",");
  });

  let bytes2 = Uint8Array.from(tox.type == 0 ? bytes : bytes.slice(1));

  let decodedRlp = decodeRlp(bytes2);
  console.log("decoded RLP is for unsigned transaction ....\n", decodedRlp);

  let bytes3 = getBytes(signed_tx);
  bytes3 = Uint8Array.from(tox.type == 0 ? bytes3 : bytes3.slice(1));

  console.log("signed RLP encoded bytes for the transaction: ");

  // this prints unsigned RLP encoded bytes of the transaction
  bytes3.forEach((v) => {
    console.log(v, ",");
  });

  decodedRlp = decodeRlp(bytes3);
  console.log("signed decoded RLP for signed transaction ....\n", decodedRlp);

  const hash = ethers.keccak256(bytes);
  console.log("the hash over which the signature was made:", hash);
};

main();
