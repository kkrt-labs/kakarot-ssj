import { hash } from 'starknet';
import readline from 'readline';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

rl.question('Enter the class hash: ', (classHashInput) => {
    rl.question('Enter the salt: ', (saltInput) => {
        rl.question('Enter the deployer address: ', (deployerInput) => {
            rl.close();

            const classHash = BigInt(classHashInput);
            const salt = BigInt(saltInput);
            const deployerAddress = BigInt(deployerInput);

            const CONSTRUCTOR_CALLDATA = [deployerAddress, salt];

            function guessAddress() {
                return hash.calculateContractAddressFromHash(
                    salt,
                    classHash,
                    CONSTRUCTOR_CALLDATA,
                    deployerAddress
                );
            }

            console.log(guessAddress());
        })
    });
});
