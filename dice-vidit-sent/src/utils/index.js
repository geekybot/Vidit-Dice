const contractAddress = 'TLRVZe8mpHuY3Lby3BEVRNYkRa78cs9jDT';
const tokenAddress = 'TCJPxoJKFYcuqtgeDH7gGjAzteqY5pc1fR';

const utils = {
    tronWeb: false,
    contract: false,

    async setTronWeb(tronWeb) {
        this.tronWeb = tronWeb;
        this.contract = await tronWeb.contract().at(contractAddress);
        this.token = await tronWeb.contract().at(tokenAddress);
    },

    transformMessage(message) {
        return {
            tips: {
                amount: message.tips,
                count: message.tippers.toNumber()
            },
            owner: this.tronWeb.address.fromHex(message.creator),
            timestamp: message.time.toNumber(),
            message: message.message
        }
    },

    async checkHistory(id) {
        return await this.contract.checkHistory(id).call();
    }
};

export default utils;