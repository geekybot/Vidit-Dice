import React from 'react';
import TronLinkGuide from 'components/TronLinkGuide';
import TronWeb from 'tronweb';
import Utils from 'utils';
import Swal from 'sweetalert2';
// import banner from 'assets/banner.png';

import './App.scss';

const FOUNDATION_ADDRESS = 'TKfB91Xodm5rijBqUsXND5fz5M1Cu8tt9V';

class App extends React.Component {
    state = {
        tronWeb: {
            installed: false,
            loggedIn: false
        },
        currentMessage: {
            message: '',
            loading: false
        },
        messages: {
            recent: {},
            featured: []
        },
        investAmount: 5,
        
        payout: 1.97,
        winpercentage: 50,
        userRoll: 50,
        rollUnder: true,
        address: 0x0,
        balance: 0,
        unfrozenToken: 0,
        frozenToken: 0,
        withdrawnToken: 0,
        availableDividends: 0,
        totalFrozenToken: 0,
        minedSupply: 0,
        totalSupply: 0,
        reward: 0
    }

    constructor(props) {
        super(props);

        
        this.onInvest = this.onInvest.bind(this);
        
        this.onInvestEdit = this.onInvestEdit.bind(this);
        this.onUserRollEdit = this.onUserRollEdit.bind(this);
        this.onRollUnder = this.onRollUnder.bind(this);
        
        this.onGetInfo = this.onGetInfo.bind(this);
        this.getTokenInfo = this.getTokenInfo.bind(this);

        this.onFreezeToken = this.onFreezeToken.bind(this);
        this.onUnfreezeToken = this.onUnfreezeToken.bind(this);
        this.onWithdrawToken = this.onWithdrawToken.bind(this);
    }

    async componentDidMount() {
        await new Promise(resolve => {
            const tronWebState = {
                installed: !!window.tronWeb,
                loggedIn: window.tronWeb && window.tronWeb.ready
            };

            if(tronWebState.installed) {
                this.setState({
                    tronWeb:
                    tronWebState
                });

                return resolve();
            }

            let tries = 0;

            const timer = setInterval(() => {
                if(tries >= 10) {
                    const TRONGRID_API = 'https://api.trongrid.io';

                    window.tronWeb = new TronWeb(
                        TRONGRID_API,
                        TRONGRID_API,
                        TRONGRID_API
                    );

                    this.setState({
                        tronWeb: {
                            installed: false,
                            loggedIn: false
                        }
                    });

                    clearInterval(timer);
                    return resolve();
                }

                tronWebState.installed = !!window.tronWeb;
                tronWebState.loggedIn = window.tronWeb && window.tronWeb.ready;

                if(!tronWebState.installed)
                    return tries++;

                this.setState({
                    tronWeb: tronWebState
                });

                resolve();
            }, 100);
        });

        if(!this.state.tronWeb.loggedIn) {
            // Set default address (foundation address) used for contract calls
            // Directly overwrites the address object as TronLink disabled the
            // function call
            window.tronWeb.defaultAddress = {
                hex: window.tronWeb.address.toHex(FOUNDATION_ADDRESS),
                base58: FOUNDATION_ADDRESS
            };

            window.tronWeb.on('addressChanged', (result) => {
                if(this.state.tronWeb.loggedIn)
                    return;

                this.getAccountInfo(result.base58);
                

                this.setState({
                    tronWeb: {
                        installed: true,
                        loggedIn: true
                    }
                });

            });
        }



        await Utils.setTronWeb(window.tronWeb);
        this.startEventListener();

    }

    // Polls blockchain for smart contract events
    startEventListener() {

    }

    async onGetInfo() {
        let historyLength = await Utils.contract.checkHistoryLength().call();
        console.log(historyLength);
        let contractBalance = await Utils.contract.checkContractBalance().call();

        console.log(contractBalance);
        this.setState({
            availableDividends: (parseInt(contractBalance, 10) / 1000000 * 60 / 100).toFixed(2)
        });

        console.log(await Utils.contract.test().call());

        this.getTokenInfo();

        for(let i = 0; i < historyLength; i++ ) {
            console.log(await Utils.contract.checkHistory(i).call());
        }
    }

    async checkContractBalance() {
        let balance = await Utils.checkContractBalance();

        console.log("Contract Balance");
        console.log(balance);

        this.setState({
            contractBalance: balance
        });
        return balance;
    }


    onInvestEdit({ target: { value } }) {
        this.setState({
            investAmount: value,
        });
    }

    onUserRollEdit({target: { value } }) {
        let winpercentage = 100 - value -1;
        let payout = 0;
        if (this.state.rollUnder)
            winpercentage = value;
        payout = 98.52 / winpercentage;
        this.setState({
            userRoll: value,
            payout: payout,
            winpercentage: winpercentage
        });
    }
    
    async getTokenInfo() {
        let frozenToken = await Utils.contract.checkFrozenBalance().call();
        let unfrozenToken = await Utils.contract.checkUnfrozenBalance().call();
        let withdrawnToken = await Utils.token.balanceOf(this.state.address).call();
        let totalFrozenToken = await Utils.contract.checkTotalFrozenTokens().call();
        let totalSupply = await Utils.token.totalSupply().call();
        let minedSupply = await Utils.token.minedSupply().call();
        let reward = 0;
        if (totalFrozenToken != 0) {
            reward = this.state.availableDividends / totalFrozenToken * frozenToken
        }
        this.setState({
            frozenToken: frozenToken / 1000000,
            unfrozenToken: unfrozenToken / 1000000,
            withdrawnToken: withdrawnToken / 1000000,
            totalFrozenToken: totalFrozenToken / 1000000,
            totalSupply: totalSupply / 1000000,
            minedSupply: minedSupply / 1000000,
            reward: reward
        });
    }

    async onWithdrawToken() {
        await Utils.contract.withdrawToken(500).send({
            shouldPollResponse: true,
            callValue: 0
        });  
        console.log("Withdraw OK");    
        this.getTokenInfo();
    }

    async onFreezeToken() {
        await Utils.contract.freezeToken(0).send({
            shouldPollResponse: true,
            callValue: 0
        });  
        console.log("Freeze OK");

        this.getTokenInfo();
    }

    async onUnfreezeToken() {
        await Utils.contract.unFreezeToken(1000).send({
            shouldPollResponse: true,
            callValue: 0
        });  
        console.log("Unfreeze OK");   
        this.getTokenInfo();
    }
    
    async getAccountInfo(address) {
        console.log(address);

        let balance = await window.tronWeb.trx.getBalance(address);
        balance = window.tronWeb.fromSun(balance)
        console.log(balance);
        this.setState ({
            address: address,
            balance: balance
        });
        return balance;
        
    }

    async onSendTestTRX() {
        await Utils.contract.sendTestTRX().send({
            shouldPollResponse: true,
            callValue: 1000 * 1000000
        });
    }

    async onInvest() {
        let amountToInvest = this.state.investAmount;
        console.log(Utils.tronWeb.trx);
        let under = this.state.rollUnder;
        let player = "Player1";
        let userRoll = this.state.userRoll;
        let betAmount = this.state.investAmount;
        let payout = parseInt(this.state.payout * 100, 10);
        console.log(payout);

        await Utils.contract.rollDice(under, player, userRoll, amountToInvest * 1000000, payout).send({
            shouldPollResponse: true,
            callValue: amountToInvest * 1000000
        });        

        this.getAccountInfo(this.state.address);
        this.getTokenInfo();
        let historyLength = await Utils.contract.checkHistoryLength().call();
        console.log(historyLength);
        let contractBalance = await Utils.contract.checkContractBalance().call();
        console.log(contractBalance);
        this.setState({
            availableDividends: (parseInt(contractBalance, 10) / 1000000 * 60 / 100).toFixed(2)
        });
        
        console.log(await Utils.contract.test().call());

        for(let i = 0; i < historyLength; i++ ) {
            console.log(await Utils.contract.checkHistory(i).call());
        }

        let hisInfo = await Utils.contract.checkHistory(historyLength-1).call();
        Swal({
            title: 'Bet: ' + betAmount + ' TRX Payout: ' + parseInt(hisInfo.payoutAmount._hex, 16) / 1000000 + " TRX",
            type: 'success'
        })
    }

    onRollUnder() {
        let winpercentage = 100 - 50 - 1;
        let payout = 0;
        if (this.state.rollUnder)
            winpercentage = 50;
        payout = 98.52 / winpercentage;
        this.setState({
            userRoll: 50,
            payout: payout,
            winpercentage: winpercentage,
            rollUnder: !this.state.rollUnder
        });


    }

    renderMessageInput() {
        if(!this.state.tronWeb.installed)
            return <TronLinkGuide />;

        if(!this.state.tronWeb.loggedIn)
            return <TronLinkGuide installed />;

        return (
            
            <div className={ 'messageInput' + (this.state.currentMessage.loading ? ' loading' : '') }>
                <div> {this.state.address} </div>
                <div> {this.state.balance} TRX </div>
                <input
                    readOnly
                    value="YOU BET:"></input>
                <input
                    placeholder='Enter your amount to invest'
                    type='number'
                    value={ this.state.investAmount }
                    onChange={ this.onInvestEdit }></input>

                <br/>
                <br/>
                <input
                    readOnly
                    value="ROLL:"></input>
                <input
                    placeholder='Enter your Roll'
                    type='number'
                    value={ this.state.userRoll }
                    onChange={ this.onUserRollEdit }></input>


                <br/>
                <br/>
                <input
                    readOnly
                    value="PAYOUT:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.payout }></input>

                <br/>
                <br/>
                <input
                    readOnly
                    value="WIN PERCENTAGE:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.winpercentage }></input>

                <br/>
                <br/>
                <div className='footer'>
                    <div
                        className={ 'rollUnderButton' }
                        onClick={ this.onRollUnder }
                    >
                        {this.state.rollUnder ? 'ROLL UNDER' : 'ROLL OVER'}
                    </div>
                </div>
                <div className='footer'>
                    <div
                        className={ 'investButton' + (!!this.state.investAmount > 0 ? '' : ' disabled') }
                        onClick={ this.onInvest }
                    >
                        Roll Dice
                    </div>
                </div>

                <br/>
                <br/>
                <input
                    readOnly
                    value="Total Supply:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.totalSupply }></input>

                <br/>
                <br/>
                <input
                    readOnly
                    value="Mined Tokens:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.minedSupply }></input>

                <br/>
                <br/>
                <input
                    readOnly
                    value="Available Dividends:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.availableDividends }></input>

                <br/>
                <br/>
                <input
                    readOnly
                    value="Available Token:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.unfrozenToken }></input>

                <div className='footer'>
                    <div
                        className={ 'withdrawToken' }
                        onClick={ this.onWithdrawToken }
                    >
                        Withdraw Token
                    </div>
                </div>

                <br/>
                <br/>
                <input
                    readOnly
                    value="Withdrawn Token:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.withdrawnToken }></input>

                <div className='footer'>
                    <div
                        className={ 'freezeToken' }
                        onClick={ this.onFreezeToken }
                    >
                        Freeze Token
                    </div>
                </div>

                <br/>
                <br/>
                <input
                    readOnly
                    value="Frozen Token:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.frozenToken }></input>

                <div className='footer'>
                    <div
                        className={ 'unfreezeToken' }
                        onClick={ this.onUnfreezeToken }
                    >
                        Unfreeze Token
                    </div>
                </div>
    
                <br/>
                <br/>
                <input
                    readOnly
                    value="Total Frozen Token:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.totalFrozenToken }></input>

                <br/>
                <br/>
                <input
                    readOnly
                    value="You Will Receive:"></input>
                <input
                
                    type='number'
                    readOnly
                    value={ this.state.reward }></input>

                <div className='footer'>
                    <div
                        className={ 'getInfoButton' }
                        onClick={ this.onGetInfo }
                    >
                        Get Info
                    </div>
                </div>

                <div className='footer'>
                    <div
                        className={ 'sendTRXButton' }
                        onClick={ this.onSendTestTRX }
                    >
                        Send TRX
                    </div>
                </div>
                
            </div>
        );
    }

    render() {
        return (
            <div className='kontainer'>

                { this.renderMessageInput() }

            </div>
        );
    }
}

export default App;
