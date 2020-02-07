var Dice = artifacts.require("./Dice.sol");
var AnteToken = artifacts.require("./AnteToken.sol");

module.exports = function(deployer) {
  deployer.deploy(Dice).then(() => {
    return deployer.deploy(AnteToken, Dice.address).then(() => {
      return Dice.deployed().then((instance) => {
        instance.setTokenContract(AnteToken.address);
        console.log(Dice.address);
        console.log(AnteToken.address);
      });
    });
  });
};
``