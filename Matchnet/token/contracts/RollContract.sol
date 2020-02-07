pragma solidity ^0.4.24;
import './SafeMath.sol';
import './MatchToken.sol';
//TJjB6AHfHnx1tm6aTassyBA2u3g4JbRu1Y - Final Draft
//"1","1","80","200","52551074270211681893390404620283638521390084513839175158922000210619980818133"
//50000000000000000000000
contract RollContract {
    using SafeMath for uint256; 
    uint constant HOUSE_EDGE_PERCENT = 1;
    uint constant HOUSE_EDGE_MINIMUM_AMOUNT = 0.0003 trx;
    uint constant MIN_BET = 0.01 trx;
    uint constant MAX_AMOUNT = 300000 trx;
    uint constant MAX_MODULO = 100;
    uint constant MAX_MASK_MODULO = 40;
    
    uint    constant private         STAGE_SETP_TOKEN = 1000000e8;
    uint    constant private         STAGE_STEP_TRX = 20;
    uint    constant private         BASE_TRX_TOKEN_RATIO = 1000;  
    address     public          tokenAddress;
    MatchToken  public          tokenContract;

    address public gameDev;
    address public channelPartner;

    //This parameter is set for bet BET_MODULO which is 100 for each game;
    uint constant BET_MODULO =100;
    
    
    // This is a check on bet mask overflow.
    uint constant MAX_BET_MASK = 2 ** MAX_MASK_MODULO;
    uint constant BET_EXPIRATION_BLOCKS = 250;

    // address constant DUMMY_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public owner;
    address private nextOwner;

    uint public maxProfit;

    address public secretSigner;


    uint128 public lockedInBets;

    struct PlayerBet{
        uint amount;
        uint8 rollNumber;
        uint8 position;
        address gambler;
    }

    // A structure representing a single bet.
    struct Bet {
        // for multiplayer game, number of players
        uint8 noOfPlayers;
        // amount of Bet
        uint amount;
        // Block number of placeBet tx.
        uint40 placeBlockNumber;
        // Address of a gambler, used to pay out winning bets.
        PlayerBet[] players;
    }

    // Mapping from commits to all currently active & processed bets.
    mapping (uint => Bet) public bets;

    // Croupier account.
    address public croupier;

    // Events that are issued to make statistic recovery easier.
    event FailedPayment(address indexed beneficiary, uint amount);
    event Payment(address indexed beneficiary, uint amount);

    // This event is emitted in placeBet to record commit in the logs.
    event Commit(uint commit);
    event MultiplayerBet(address gambler, uint commit, uint position, uint amount);
    event Result(address gambler,uint typeRoll,uint rollNumber,uint dice,uint amount,uint diceWin );
    event ResultMultiplayer(address gambler,uint winnerPosition,uint amount,uint diceWin );
    // Constructor. Deliberately does not take any parameters.
    constructor (address _gameDev, address _channelPartner) public {
        owner = msg.sender;
        // secretSigner = DUMMY_ADDRESS;
        gameDev = _gameDev;
        channelPartner = _channelPartner;
        croupier = msg.sender;
    }
    
    // Standard modifier on methods invokable only by contract owner.
    modifier onlyOwner {
        require (msg.sender == owner, "OnlyOwner methods called by non-owner.");
        _;
    }

    // Standard modifier on methods invokable only by contract owner.
    modifier onlyCroupier {
        require (msg.sender == croupier, "OnlyCroupier methods called by non-croupier.");
        _;
    }
    function setTokenContract(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(0x0), "Token contract is already set");
        tokenAddress =  _tokenAddress;
        tokenContract = MatchToken(tokenAddress);
    }
    // Standard contract ownership transfer implementation,
    function approveNextOwner(address _nextOwner) external onlyOwner {
        require (_nextOwner != owner, "Cannot approve current owner.");
        nextOwner = _nextOwner;
    }

    function acceptNextOwner() external {
        require (msg.sender == nextOwner, "Can only accept preapproved new owner.");
        owner = nextOwner;
    }

    // Fallback function deliberately left empty. It's primary use case
    // is to top up the bank roll.
    function () public payable {
    }

    // See comment for "secretSigner" variable.
    function setSecretSigner(address newSecretSigner) external onlyOwner {
        secretSigner = newSecretSigner;
    }

    // Change the croupier address.
    function setCroupier(address newCroupier) external onlyOwner {
        croupier = newCroupier;
    }

    // Change max bet reward. Setting this to zero effectively disables betting.
    function setMaxProfit(uint _maxProfit) public onlyOwner {
        require (_maxProfit < MAX_AMOUNT, "maxProfit should be a sane number.");
        maxProfit = _maxProfit;
    }


    // Funds withdrawal to cover costs of operation.
    function withdrawFunds(address beneficiary, uint withdrawAmount) external onlyOwner {
        require (withdrawAmount <= address(this).balance, "Increase amount larger than balance.");
        require ( lockedInBets + withdrawAmount <= address(this).balance, "Not enough funds.");
        sendFunds(beneficiary, withdrawAmount, withdrawAmount);
    }

    // Contract may be destroyed only when there are no ongoing bets,
    // either settled or refunded. All funds are transferred to contract owner.
    function kill() external onlyOwner {
        require (lockedInBets == 0, "All bets should be processed (settled or refunded) before self-destruct.");
        selfdestruct(owner);
    }

    /// *** Betting logic

    // Bet states:
    //  amount == 0 && gambler == 0 - 'clean' (can place a bet)
    //  amount != 0 && gambler != 0 - 'active' (can be settled or refunded)
    //  amount == 0 && gambler != 0 - 'processed' (can clean storage)
    //
    //  NOTE: Storage cleaning is not implemented in this contract version; it will be added
    //        with the next upgrade to prevent polluting Ethereum state with expired bets.

    // Bet placing transaction - issued by the player.
    //  betMask         - bet outcomes bit mask for BET_MODULO <= MAX_MASK_MODULO,
    //                    [0, betMask) for larger BET_MODULOs.
    //  BET_MODULO          - game BET_MODULO.
    //  commitLastBlock - number of the maximum block where "commit" is still considered valid.
    //  commit          - Keccak256 hash of some secret "reveal" random number, to be supplied
    //                    by the RollContract croupier bot in the settleBet transaction. Supplying
    //                    "commit" ensures that "reveal" cannot be changed behind the scenes
    //                    after placeBet have been mined.
    //  r, s            - components of ECDSA signature of (commitLastBlock, commit). v is
    //                    guaranteed to always equal 27.
    //
    // Commit, being essentially random 256-bit number, is used as a unique bet identifier in
    // the 'bets' mapping.
    //
    // Commits are signed with a block limit to ensure that they are used at most once - otherwise
    // it would be possible for a miner to place a bet with a known commit/reveal pair and tamper
    // with the blockhash. Croupier guarantees that commitLastBlock will always be not greater than
    // placeBet block number plus BET_EXPIRATION_BLOCKS. See whitepaper for details.
    function placeBet(uint8 noOfPlayers,uint8 position, uint8 betMask, uint40 commitLastBlock, uint commit) external payable {
        // Check that the bet is in 'clean' state.
        Bet storage bet = bets[commit];
        require (bet.players.length == 0, "Bet should be in a 'clean' state.");
        // require (bet.players[0].gambler == address(0), "Bet should be in a 'clean' state.");

        // Validate input data ranges.
        uint amount = msg.value;
        // require (BET_MODULO > 1 && BET_MODULO <= MAX_MODULO, "Modulo should be within range.");
        require (amount >= MIN_BET && amount <= MAX_AMOUNT, "Amount should be within range.");
        require (betMask > 0 && betMask < MAX_BET_MASK, "Mask should be within range.");

        // Check that commit is valid - it has not expired and its signature is valid.
        require (block.number <= commitLastBlock, "Commit has expired.");
        uint8 rollNumber;
        
        // rollNumber = ((betMask * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO;
        rollNumber = betMask;
        if (noOfPlayers == 1) {
            // Winning amount and jackpot increase.
            uint possibleWinAmount;

            possibleWinAmount= getDiceWinAmount(amount,  rollNumber, position);

            // Enforce max profit limit.
            require (possibleWinAmount <= amount + maxProfit, "maxProfit limit violation.");

            // Lock funds.
            lockedInBets += uint128(possibleWinAmount);

            // Check whether contract has enough funds to process this bet.
            require ( lockedInBets <= address(this).balance, "Cannot afford to lose this bet.");
    
            // Store bet parameters on blockchain.
            bet.noOfPlayers = uint8(noOfPlayers);
            bet.amount = amount;
            bet.placeBlockNumber = uint40(block.number);
            PlayerBet memory pl;
            pl.gambler = msg.sender;
            pl.rollNumber = uint8(rollNumber);
            pl.position = uint8(position);
            bet.players.push(pl);
            uint ttm = tokenToMine(msg.value);
            tokenContract.mine(msg.sender, gameDev, channelPartner, ttm);
            emit Commit(commit);
        }
        
        else {
            possibleWinAmount = noOfPlayers * amount;
            require (possibleWinAmount <= amount + maxProfit, "maxProfit limit violation.");

            // Lock funds.
            lockedInBets += uint128(amount);
            // Check whether contract has enough funds to process this bet.
            require ( lockedInBets <= address(this).balance, "Cannot afford to lose this bet.");
            require (getLengthOfGamblers(commit)<noOfPlayers, "All bets have been placed for this bet");
            bet.noOfPlayers = uint8(noOfPlayers);
            bet.amount = possibleWinAmount;
            
            PlayerBet memory pl1;
            
            pl1.gambler = msg.sender;
            pl1.position = uint8(position);
            pl1.amount = amount;
            bet.players.push(pl1);            
            uint ttm = tokenToMine(msg.value);
            tokenContract.mine(msg.sender, gameDev, channelPartner, ttm);
            emit MultiplayerBet(msg.sender, commit, position, amount);
        }
        // Record commit in logs.
        
    }

    function getLengthOfGamblers(uint commit) internal view returns (uint){
        Bet storage bet = bets[commit];
        return bet.players.length;
    }

    //get bets placed on a commit

    function getBetsByPlayers(uint commit,uint index) external view returns (address, uint8){
        PlayerBet storage pb = bets[commit].players[index];
        return (pb.gambler, pb.position);
    }
    // join an existing bet by providing commit and position
    function joinBet(uint commit, uint position) external payable {
        Bet storage bet = bets[commit];
        uint betLength = getLengthOfGamblers(commit);
        uint amount = msg.value;
        require (betLength >= 1, "No bet placed for this commit, or bet is over");
        require (betLength < bet.noOfPlayers, "All bets have been placed for this bet");
        require (bet.players[0].amount == amount, "Amount should be equal to each bet amount");
        PlayerBet memory pl;
        
        pl.gambler = msg.sender;
        pl.position = uint8(position);
        pl.amount = amount;
        bet.players.push(pl);
        uint ttm = tokenToMine(msg.value);
        tokenContract.mine(msg.sender, gameDev, channelPartner, ttm);
        emit MultiplayerBet(msg.sender, commit, position, amount);
        if(betLength+1 == bet.noOfPlayers ){
            emit Commit(commit);
            bet.placeBlockNumber = uint40(block.number);
        }
    }
    // This is the method used to settle 99% of bets. To process a bet with a specific
    // "commit", settleBet should supply a "reveal" number that would Keccak256-hash to
    // "commit". "blockHash" is the block hash of placeBet block as seen by croupier; it
    // is additionally asserted to prevent changing the bet outcomes on Ethereum reorgs.
    function settleBet(uint reveal, bytes32 blockHash) external onlyCroupier {
        uint commit = uint(keccak256(abi.encodePacked(reveal)));

        Bet storage bet = bets[commit];
        uint placeBlockNumber = bet.placeBlockNumber;

        // Check that bet has not expired yet (see comment to BET_EXPIRATION_BLOCKS).
        require (block.number > placeBlockNumber, "settleBet in the same block as placeBet, or before.");
        require (block.number <= placeBlockNumber + BET_EXPIRATION_BLOCKS, "Blockhash can't be queried by EVM.");
        require (blockhash(placeBlockNumber) == blockHash);

        // Settle bet using reveal and blockHash as entropy sources.
        settleBetCommon(bet, reveal, blockHash);
    }

    // This method is used to settle a bet that was mined into an uncle block. At this
    // point the player was shown some bet outcome, but the blockhash at placeBet height
    // is different because of Ethereum chain reorg. We supply a full merkle proof of the
    // placeBet transaction receipt to provide untamperable evidence that uncle block hash
    // indeed was present on-chain at some point.
    function settleBetUncleMerkleProof(uint reveal, uint40 canonicalBlockNumber) external onlyCroupier {
        // "commit" for bet settlement can only be obtained by hashing a "reveal".
        uint commit = uint(keccak256(abi.encodePacked(reveal)));

        Bet storage bet = bets[commit];

        // Check that canonical block hash can still be verified.
        require (block.number <= canonicalBlockNumber + BET_EXPIRATION_BLOCKS, "Blockhash can't be queried by EVM.");

        // Verify placeBet receipt.
        requireCorrectReceipt(4 + 32 + 32 + 4);

        // Reconstruct canonical & uncle block hashes from a receipt merkle proof, verify them.
        bytes32 canonicalHash;
        bytes32 uncleHash;
        (canonicalHash, uncleHash) = verifyMerkleProof(commit, 4 + 32 + 32);
        require (blockhash(canonicalBlockNumber) == canonicalHash);

        // Settle bet using reveal and uncleHash as entropy sources.
        settleBetCommon(bet, reveal, uncleHash);
    }

    // Common settlement code for settleBet & settleBetUncleMerkleProof.
    function settleBetCommon(Bet storage bet, uint reveal, bytes32 entropyBlockHash) private {
        // Fetch bet parameters into local variables (to save gas).
        uint amount = bet.amount;
        PlayerBet storage pb = bet.players[0];
        uint rollNumber = pb.rollNumber;
        address gambler;
        
        uint diceWin = 0;
        uint individualAmount = pb.amount;
        require (amount != 0, "Bet should be in an 'active' state");
        
        bytes32 entropy = keccak256(abi.encodePacked(reveal, entropyBlockHash));
        uint dice = uint(entropy) % BET_MODULO;
        uint diceWinAmount;
        if(bet.noOfPlayers == 1){
            bet.amount = 0;
            gambler = pb.gambler;
            diceWinAmount = getDiceWinAmount(amount, rollNumber, pb.position);
            if (pb.position == 0 && dice < rollNumber) {
                diceWin = diceWinAmount;
            }
            else if(pb.position == 1 && dice > rollNumber){
                diceWin = diceWinAmount;
            }
            emit Result(gambler, pb.position, rollNumber, dice, amount, diceWin );
        }
        else{
            diceWinAmount = bet.amount * 95/100;
            bet.amount = 0;
            uint winnerPosition = uint(entropy) % bet.noOfPlayers;
            for(uint i=0; i< bet.noOfPlayers; i++){
                if(winnerPosition == bet.players[i].position){
                    gambler = bet.players[i].gambler;
                }
            }
            diceWin = diceWinAmount;
            emit ResultMultiplayer(gambler, winnerPosition, individualAmount, diceWin );
        }
        lockedInBets -= uint128(diceWinAmount);
        
        sendFunds(gambler, diceWin  == 0 ? 1 sun : diceWin , diceWin);
    }

    // Refund transaction - return the bet amount of a roll that was not processed in a
    // due timeframe. Processing such blocks is not possible due to EVM limitations (see
    // BET_EXPIRATION_BLOCKS comment above for details).
    function refundBet(uint commit) external {
        // Check that bet is in 'active' state.
        Bet storage bet = bets[commit];
        uint amount = bet.amount;

        require (amount != 0, "Bet should be in an 'active' state");

        // Check that bet has already expired.
        require (block.number > bet.placeBlockNumber + BET_EXPIRATION_BLOCKS, "Blockhash can't be queried by EVM.");

        // Move bet into 'processed' state, release funds.
        bet.amount = 0;

        uint diceWinAmount;
        // uint jackpotFee;
        diceWinAmount = getDiceWinAmount(amount,  bet.players[0].rollNumber, bet.players[0].position);

        lockedInBets -= uint128(diceWinAmount);

        // Send the refund.
        for(uint i=0; i< bet.noOfPlayers; i++){
            sendFunds(bet.players[i].gambler, amount, amount);    
        }
    }

    // Get the expected win amount after house edge is subtracted.
    function getDiceWinAmount(uint amount, uint rollNumber, uint8 side) private pure returns (uint winAmount) {
        
        require (0 < rollNumber && rollNumber <= BET_MODULO, "Win probability out of range.");
        if(side == 1) {
            rollNumber = 100-rollNumber;
        }

        uint houseEdge = amount * HOUSE_EDGE_PERCENT / 100;

        if (houseEdge < HOUSE_EDGE_MINIMUM_AMOUNT) {
            houseEdge = HOUSE_EDGE_MINIMUM_AMOUNT;
        }

        require (houseEdge <= amount, "Bet doesn't even cover house edge.");
        winAmount = (amount - houseEdge) * BET_MODULO / rollNumber;
    }

    // Helper routine to process the payment.
    function sendFunds(address beneficiary, uint amount, uint successLogAmount) private {
        if (beneficiary.send(amount)) {
            emit Payment(beneficiary, successLogAmount);
        } else {
            emit FailedPayment(beneficiary, amount);
        }
    }

    // This are some constants making O(1) population count in placeBet possible.
    // See whitepaper for intuition and proofs behind it.
    uint constant POPCNT_MULT = 0x0000000000002000000000100000000008000000000400000000020000000001;
    uint constant POPCNT_MASK = 0x0001041041041041041041041041041041041041041041041041041041041041;
    uint constant POPCNT_MODULO = 0x3F;

    // *** Merkle proofs.

    // This helpers are used to verify cryptographic proofs of placeBet inclusion into
    // uncle blocks. They are used to prevent bet outcome changing on Ethereum reorgs without
    // compromising the security of the smart contract. Proof data is appended to the input data
    // in a simple prefix length format and does not adhere to the ABI.
    // Invariants checked:
    //  - receipt trie entry contains a (1) successful transaction (2) directed at this smart
    //    contract (3) containing commit as a payload.
    //  - receipt trie entry is a part of a valid merkle proof of a block header
    //  - the block header is a part of uncle list of some block on canonical chain
    // The implementation is optimized for gas cost and relies on the specifics of Ethereum internal data structures.
    // Read the whitepaper for details.

    // Helper to verify a full merkle proof starting from some seedHash (usually commit). "offset" is the location of the proof
    // beginning in the calldata.
    function verifyMerkleProof(uint seedHash, uint offset) pure private returns (bytes32 blockHash, bytes32 uncleHash) {
        // (Safe) assumption - nobody will write into RAM during this method invocation.
        uint scratchBuf1;  assembly { scratchBuf1 := mload(0x40) }

        uint uncleHeaderLength; uint blobLength; uint shift; uint hashSlot;

        // Verify merkle proofs up to uncle block header. Calldata layout is:
        //  - 2 byte big-endian slice length
        //  - 2 byte big-endian offset to the beginning of previous slice hash within the current slice (should be zeroed)
        //  - followed by the current slice verbatim
        for (;; offset += blobLength) {
            assembly { blobLength := and(calldataload(sub(offset, 30)), 0xffff) }
            if (blobLength == 0) {
                // Zero slice length marks the end of uncle proof.
                break;
            }

            assembly { shift := and(calldataload(sub(offset, 28)), 0xffff) }
            require (shift + 32 <= blobLength, "Shift bounds check.");

            offset += 4;
            assembly { hashSlot := calldataload(add(offset, shift)) }
            require (hashSlot == 0, "Non-empty hash slot.");

            assembly {
                calldatacopy(scratchBuf1, offset, blobLength)
                mstore(add(scratchBuf1, shift), seedHash)
                seedHash := sha3(scratchBuf1, blobLength)
                uncleHeaderLength := blobLength
            }
        }

        // At this moment the uncle hash is known.
        uncleHash = bytes32(seedHash);

        // Construct the uncle list of a canonical block.
        uint scratchBuf2 = scratchBuf1 + uncleHeaderLength;
        uint unclesLength; assembly { unclesLength := and(calldataload(sub(offset, 28)), 0xffff) }
        uint unclesShift;  assembly { unclesShift := and(calldataload(sub(offset, 26)), 0xffff) }
        require (unclesShift + uncleHeaderLength <= unclesLength, "Shift bounds check.");

        offset += 6;
        assembly { calldatacopy(scratchBuf2, offset, unclesLength) }
        memcpy(scratchBuf2 + unclesShift, scratchBuf1, uncleHeaderLength);

        assembly { seedHash := sha3(scratchBuf2, unclesLength) }

        offset += unclesLength;

        // Verify the canonical block header using the computed sha3Uncles.
        assembly {
            blobLength := and(calldataload(sub(offset, 30)), 0xffff)
            shift := and(calldataload(sub(offset, 28)), 0xffff)
        }
        require (shift + 32 <= blobLength, "Shift bounds check.");

        offset += 4;
        assembly { hashSlot := calldataload(add(offset, shift)) }
        require (hashSlot == 0, "Non-empty hash slot.");

        assembly {
            calldatacopy(scratchBuf1, offset, blobLength)
            mstore(add(scratchBuf1, shift), seedHash)

            // At this moment the canonical block hash is known.
            blockHash := sha3(scratchBuf1, blobLength)
        }
    }

    // Helper to check the placeBet receipt. "offset" is the location of the proof beginning in the calldata.
    // RLP layout: [triePath, str([status, cumGasUsed, bloomFilter, [[address, [topics], data]])]
    function requireCorrectReceipt(uint offset) view private {
        uint leafHeaderByte; assembly { leafHeaderByte := byte(0, calldataload(offset)) }

        require (leafHeaderByte >= 0xf7, "Receipt leaf longer than 55 bytes.");
        offset += leafHeaderByte - 0xf6;

        uint pathHeaderByte; assembly { pathHeaderByte := byte(0, calldataload(offset)) }

        if (pathHeaderByte <= 0x7f) {
            offset += 1;

        } else {
            require (pathHeaderByte >= 0x80 && pathHeaderByte <= 0xb7, "Path is an RLP string.");
            offset += pathHeaderByte - 0x7f;
        }

        uint receiptStringHeaderByte; assembly { receiptStringHeaderByte := byte(0, calldataload(offset)) }
        require (receiptStringHeaderByte == 0xb9, "Receipt string is always at least 256 bytes long, but less than 64k.");
        offset += 3;

        uint receiptHeaderByte; assembly { receiptHeaderByte := byte(0, calldataload(offset)) }
        require (receiptHeaderByte == 0xf9, "Receipt is always at least 256 bytes long, but less than 64k.");
        offset += 3;

        uint statusByte; assembly { statusByte := byte(0, calldataload(offset)) }
        require (statusByte == 0x1, "Status should be success.");
        offset += 1;

        uint cumGasHeaderByte; assembly { cumGasHeaderByte := byte(0, calldataload(offset)) }
        if (cumGasHeaderByte <= 0x7f) {
            offset += 1;

        } else {
            require (cumGasHeaderByte >= 0x80 && cumGasHeaderByte <= 0xb7, "Cumulative gas is an RLP string.");
            offset += cumGasHeaderByte - 0x7f;
        }

        uint bloomHeaderByte; assembly { bloomHeaderByte := byte(0, calldataload(offset)) }
        require (bloomHeaderByte == 0xb9, "Bloom filter is always 256 bytes long.");
        offset += 256 + 3;

        uint logsListHeaderByte; assembly { logsListHeaderByte := byte(0, calldataload(offset)) }
        require (logsListHeaderByte == 0xf8, "Logs list is less than 256 bytes long.");
        offset += 2;

        uint logEntryHeaderByte; assembly { logEntryHeaderByte := byte(0, calldataload(offset)) }
        require (logEntryHeaderByte == 0xf8, "Log entry is less than 256 bytes long.");
        offset += 2;

        uint addressHeaderByte; assembly { addressHeaderByte := byte(0, calldataload(offset)) }
        require (addressHeaderByte == 0x94, "Address is 20 bytes long.");

        uint logAddress; assembly { logAddress := and(calldataload(sub(offset, 11)), 0xffffffffffffffffffffffffffffffffffffffff) }
        require (logAddress == uint(address(this)));
    }



    ////token to mine calculation
    function tokenToMine(uint256 trxValue) private returns(uint) {
        uint minedSupply = tokenContract._minedSupply();
        uint trxTokenRatio = 1000.add(minedSupply.div(STAGE_SETP_TOKEN).mul(20));
        uint tokenToBeMined = trxValue / trxTokenRatio;
        return tokenToBeMined;
    }
    // Memory copy.
    function memcpy(uint dest, uint src, uint len) pure private {
        // Full 32 byte words
        for(; len >= 32; len -= 32) {
            assembly { mstore(dest, mload(src)) }
            dest += 32; src += 32;
        }

        // Remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
}