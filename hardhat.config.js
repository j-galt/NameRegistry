require("@nomiclabs/hardhat-waffle");
const secret = require("./secret.json");

module.exports = {
  solidity: "0.8.4",
  networks: {
    rinkeby: {
      url: secret.rinkebyNodeUrl,
      accounts: [secret.key]
    },
    hardhat: {
      forking: {
        url: secret.rinkebyNodeUrl,
        blockNumber: 11080883
      }
    }
  }
};
