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
        "Enter the deployer address (default: 0x3c7f668c6512d955348ecbd0e63ea0f64f54257f08e586794fa3932ebd91e54): ",
        (deployerInput) => {
          rl.close();

          const classHash = BigInt(classHashInput);
          const salt = saltInput.trim()
            ? BigInt(saltInput)
            : 0x65766d5f61646472657373n;
          const deployerAddress = deployerInput.trim()
            ? BigInt(deployerInput)
            : 0x3c7f668c6512d955348ecbd0e63ea0f64f54257f08e586794fa3932ebd91e54n;

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
