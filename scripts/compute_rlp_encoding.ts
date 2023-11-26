// This js script helps in creating unsigned and signed RLP data for tests

import { ethers } from "ethers";
import dotevn from "dotenv";
import readline from "readline";

dotevn.config();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const question = (query: string): Promise<string> => {
  return new Promise((resolve, reject) => {
    rl.question(query, (answer) => {
      resolve(answer);
    });
  });
};

const main = async () => {
  const { Transaction, Wallet } = ethers;
  const { decodeRlp, getBytes } = ethers;

  if (!process.env.PRIVATE_KEY) {
    console.log(
      "missing private key in environment, please provide PRIVATE_KEY environment variable",
    );
    process.exit(1);
  }

  const wallet = new Wallet(process.env.PRIVATE_KEY);
  console.log("address of the wallet is", wallet.address);

  console.log("\nenter transaction details\n");

  const to = await question("enter `to` address: ");
  const value = await question("enter `value` in wei: ");
  const gasLimit = await question("enter `gasLimit` in wei: ");
  const gasPrice = await question("enter `gasPrice`, in wei: ");
  const nonce = await question("enter `nonce`, hex: ");
  const chainId = await question("enter `chainId`, in hex: ");
  const data = await question("enter `data`, i.e calldata, in hex: ");

  const tx_type = parseInt(
    await question("enter `tx_type`, 0: legacy, 1: 2930, 2:1559 : "),
  );

  // for type 0 and type 1
  let tx;

  if (tx_type === 0 || tx_type === 1) {
    tx = {
      to,
      value,
      gasLimit,
      gasPrice,
      nonce,
      chainId,
      data,
    };
  } else {
    if (tx_type == 2) {
      tx = {
        to,
        value,
        gasLimit,
        maxFeePerGas: gasPrice,
        nonce,
        chainId,
        data,
      };
    } else {
      console.log("tx_type not supported");
      process.exit(1);
    }
  }

  const transaction = Transaction.from(tx);
  transaction.type = tx_type;

  let signed_tx = await wallet.signTransaction(transaction);

  console.log("unsigned serialized tx ----->", transaction.unsignedSerialized);
  console.log("unsigned transaction hash", transaction.hash);

  // const bytes = getBytes(signedTX);
  const bytes = getBytes(transaction.unsignedSerialized);

  console.log("unsigned RLP encoded bytes for the transaction: ");

  // this prints unsigned RLP encoded bytes of the transaction
  bytes.forEach((v) => {
    console.log(v, ",");
  });
  console.log("\n");

  let bytes2 = Uint8Array.from(transaction.type == 0 ? bytes : bytes.slice(1));

  let decodedRlp = decodeRlp(bytes2);
  console.log("decoded RLP is for unsigned transaction ....\n", decodedRlp);

  let bytes3 = getBytes(signed_tx);
  bytes3 = Uint8Array.from(transaction.type == 0 ? bytes3 : bytes3.slice(1));

  console.log("signed RLP encoded bytes for the transaction: ");

  // this prints unsigned RLP encoded bytes of the transaction
  bytes3.forEach((v) => {
    console.log(v, ",");
  });
  console.log("\n");

  decodedRlp = decodeRlp(bytes3);
  console.log("signed decoded RLP for signed transaction ....\n", decodedRlp);

  const hash = ethers.keccak256(bytes);
  console.log("the hash over which the signature was made:", hash);

  console.log("signature details: ");
  const v = decodedRlp[decodedRlp.length - 3];
  const r = decodedRlp[decodedRlp.length - 2];
  const s = decodedRlp[decodedRlp.length - 1];

  const y_parity =
    tx_type == 0
      ? get_y_parity(BigInt(v), BigInt(chainId))
      : parseInt(v, 16) == 1;
  console.log("r: ", r);
  console.log("s: ", s);
  console.log("y parity: ", y_parity);

  process.exit(0);
};

const get_y_parity = (v: bigint, chain_id: bigint): boolean => {
  let y_parity = v - (chain_id * BigInt(2) + BigInt(35));
  if (y_parity == BigInt(0) || y_parity == BigInt(1)) {
    return y_parity == BigInt(1);
  }

  y_parity = v - (chain_id * BigInt(2) + BigInt(36));
  if (y_parity == BigInt(0) || y_parity == BigInt(1)) {
    return y_parity == BigInt(1);
  }

  throw new Error("invalid v value");
};

main();
