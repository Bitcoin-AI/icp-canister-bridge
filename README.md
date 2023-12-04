# ICP Canister Bridge Project

## Introduction
The ICP Canister Bridge is an innovative project that creates a bridge between the RSK Blockchain and Lightning Network using the Internet Computer Protocol (ICP) stack. It uses ECDSA API for secure and efficient transactions across Ethereum Virtual Machine (EVM) compatible chains and is designed to facilitate swapping of satoshis between the Lightning testnetwork and Rootstock testnetwork.

## Key Features
- **Integration with ECDSA API:** Ensures high security for transactions.
- **Compatibility with EVM Chains:** Enables smooth transactions across different EVM chains.
- **Potential Lightning Network Support:** Explores integration possibilities with Bitcoin's Lightning Network.

## Technologies Used
- **ICP for HTTP Requests:** Utilizes ICP for communicating with an Express.js API.
- **RSK Smart Contract:** Manages invoices and user balances on the RSK network.
- **ICP Canister:** Interacts with RSK and Lightning networks.
- **Express.js API:** Handles requests from the canister.
- **Motoko, Webln, Ethers.js:** These technologies are integral to the project's functionality.

## Getting Started
1. **Installation:**
   - Clone the repository: `git clone [repository URL]`.
   - Install DFX, the development and deployment tool for the Internet Computer.
   - Navigate to the project directory and initialize the project using `dfx init`.
   - Install necessary dependencies as outlined in the project's `package.json`.

2. **Configuration:**
   - Configure `dfx.json` for your local and network settings.
   - Set up environment variables for interacting with the ICP network and other services (e.g., API keys, network addresses).
   - If interacting with EVM chains, configure the connection settings and smart contract addresses.
   - Test the configuration by deploying a local version using `dfx deploy`.


## How to Use
- Detailed user guides are available in the repository for initiating and managing cross-chain transactions.

## Contributing
We encourage contributions to this project. Please adhere to the project's contribution guidelines for submitting code or suggestions.

## License
This project is licensed under the [MIT License](LICENSE).

## Support and Contact
For questions, support, or feedback, please open an issue in the GitHub repository.

For a comprehensive understanding, visit the [ICP Canister Bridge GitHub Repository](https://github.com/Bitcoin-AI/icp-canister-bridge) and the [Devpost page](https://devpost.com/software/icp-canister-bridge).
