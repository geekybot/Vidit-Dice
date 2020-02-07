var DappStats = artifacts.require("./DappStats.sol");
// var TokenSale = artifacts.require("./TokenSale.sol");

module.exports = function (deployer) {
   deployer.deploy(DappStats, "TDkV2yu5nkBLEWUrLNt5ySqNNXMHVd8HnX", "TLdYCXYRyKTWVU3jqmgWFo3hXcysxEtwVX", "TDgkF4Lb7NdNNY3XE7hxGsSHqKTQaSbZti");
    // deployer.deploy(TokenSale, "put token contract address here");
};
