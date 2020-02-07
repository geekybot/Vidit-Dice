module.exports = {
    networks: {
        development: {
            from: 'your public address',
            privateKey : 'put your private key here',
            userFeePercentage: 30,
            feeLimit: 1e9,
            originEnergyLimit: 1e7,
            fullHost: "https://api.trongrid.io",
            network_id: "*" // Match any network id
        },
        production: {}
    }
};
