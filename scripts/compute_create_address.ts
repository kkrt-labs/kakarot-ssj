import { Address, Hex, getContractAddress } from "viem";
import { createPromptModule } from "inquirer";

const prompt = createPromptModule();

prompt([
  {
    type: "list",
    name: "opcode",
    message: "Choose an opcode:",
    choices: ["CREATE", "CREATE2"],
  },
  {
    type: "input",
    name: "from",
    message: "Enter from address:",
    default: "0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266",
  },
  {
    type: "input",
    name: "nonce",
    message: "Enter nonce:",
    default: "420",
    when: (answers) => answers.opcode === "CREATE",
    filter: (value) => BigInt(value),
  },
  {
    type: "input",
    name: "bytecode",
    message: "Enter bytecode",
    default:
      "0x6080604052348015600f57600080fd5b506004361060465760003560e01c806306661abd14604b578063371303c01460655780636d4ce63c14606d578063b3bcfa82146074575b600080fd5b605360005481565b60405190815260200160405180910390f35b606b607a565b005b6000546053565b606b6091565b6001600080828254608a919060b7565b9091555050565b6001600080828254608a919060cd565b634e487b7160e01b600052601160045260246000fd5b8082018082111560c75760c760a1565b92915050565b8181038181111560c75760c760a156fea2646970667358221220f379b9089b70e8e00da8545f9a86f648441fdf27ece9ade2c71653b12fb80c7964736f6c63430008120033",
    when: (answers) => answers.opcode === "CREATE2",
  },
  {
    type: "input",
    name: "salt",
    message: "Enter salt or press Enter for default [0xbeef]:",
    default: "0xbeef",
    when: (answers) => answers.opcode === "CREATE2",
  },
]).then((answers) => {
  let address: Address;
  if (answers.opcode === "CREATE") {
    address = getContractAddress({
      opcode: "CREATE",
      from: answers.from as Address,
      nonce: answers.nonce,
    });
  } else if (answers.opcode === "CREATE2") {
    address = getContractAddress({
      opcode: "CREATE2",
      from: answers.from as Address,
      bytecode: answers.bytecode as Hex,
      salt: answers.salt as Hex,
    });
  }

  console.log(`Generated Address: ${address!}`);
});
