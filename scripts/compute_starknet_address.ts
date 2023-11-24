import { hash } from "starknet";
import readline from "readline";

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// The default salt is the hexadecimal representation of 'evm_address'
// The default kakarot address is 0x01
rl.question("Enter the class hash: ", (classHashInput) => {
  rl.question(
    "Enter the salt (default: 0x65766d5f61646472657373): ",
    (saltInput) => {
      rl.question(
        "Enter the deployer address (default: 0x7753aaa1814b9f978fd93b66453ae87419b66d764fbf9313847edeb0283ef63): ",
        (deployerInput) => {
          rl.close();

          const classHash = BigInt(classHashInput);
          const salt = saltInput.trim()
            ? BigInt(saltInput)
            : 0x65766d5f61646472657373n;
          const deployerAddress = deployerInput.trim()
            ? BigInt(deployerInput)
            : 0x7753aaa1814b9f978fd93b66453ae87419b66d764fbf9313847edeb0283ef63n;

          const CONSTRUCTOR_CALLDATA = [deployerAddress, salt];

          function compute_starknet_address() {
            return hash.calculateContractAddressFromHash(
              salt,
              classHash,
              CONSTRUCTOR_CALLDATA,
              deployerAddress,
            );
          }
          console.log(
            "Pre-computed Starknet Address: " + compute_starknet_address(),
          );
        },
      );
    },
  );
});
