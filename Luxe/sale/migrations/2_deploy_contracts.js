// var DappStats = artifacts.require("./DappStats.sol");
var TokenSale = artifacts.require("./TokenSale.sol");

module.exports = function (deployer) {
   // deployer.deploy(DappStats, "TTadSKtZ67Mw7jxDRz43ctnr1rdvYmez91", "TSnjxMrK7D4RbwEruMAVvkRJy1i8M4vapw", "TFXQVY64xPrPHKZeaPR3HNpHQJ3jJ9rF1h");
    deployer.deploy(TokenSale, "put token contract address here");
};
