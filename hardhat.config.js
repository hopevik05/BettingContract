/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.8.9",
  networks: {
    polygonTestnet: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/xOgHYlzhaxkYwc3BUv_ut5J4JoOsldhN",
      accounts: [
        `0x${"d1c04dd3367f4243c32a1f4370298a5c58620579a2643dd18489a7c411acc724"}`,
      ],
    },
  },
};
