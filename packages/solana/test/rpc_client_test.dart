// @dart=3.9
// ignore_for_file: cast_nullable_to_non_nullable, avoid-unnecessary-late, avoid-type-casts

@TestOn('vm')
library;

import 'dart:async';

import 'package:bip39/bip39.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

import 'config.dart';

const int _transferredAmount = lamportsPerSol;

void main() {
  group('Instance equality', () {
    test('Account', () {
      final accounts = <(Account, Account)>[
        (
          Account.fromJson({
            'lamports': 0,
            'owner': SystemProgram.programId,
            'executable': false,
            'rentEpoch': 0,
          }),
          Account.fromJson({
            'lamports': 0,
            'owner': SystemProgram.programId,
            'executable': false,
            'rentEpoch': '0',
          }),
        ),
        // Web max precise.
        (
          Account.fromJson({
            'lamports': 0,
            'owner': SystemProgram.programId,
            'executable': false,
            'rentEpoch': 0x20000000000000,
          }),
          Account.fromJson({
            'lamports': 0,
            'owner': SystemProgram.programId,
            'executable': false,
            'rentEpoch': '0x20000000000000',
          }),
        ),
        // 64-bit native.
        (
          Account.fromJson({
            'lamports': 0,
            'owner': SystemProgram.programId,
            'executable': false,
            'rentEpoch': 0x7FFFFFFFFFFFFFFF,
          }),
          Account.fromJson({
            'lamports': 0,
            'owner': SystemProgram.programId,
            'executable': false,
            'rentEpoch': '0x7FFFFFFFFFFFFFFF',
          }),
        ),
      ];
      for (final pair in accounts) {
        expect(pair.$1 == pair.$2, true);
      }
    });

    test('Context', () {
      final contexts = <(Context, Context)>[
        (Context.fromJson({'slot': 0}), Context.fromJson({'slot': '0'})),
        // Web max precise.
        (
          Context.fromJson({'slot': 0x20000000000000}),
          Context.fromJson({'slot': '0x20000000000000'}),
        ),
        // 64-bit native.
        (
          Context.fromJson({'slot': 0x7FFFFFFFFFFFFFFF}),
          Context.fromJson({'slot': '0x7FFFFFFFFFFFFFFF'}),
        ),
      ];
      for (final pair in contexts) {
        expect(pair.$1 == pair.$2, true);
      }
    });
  });

  group('Timeout exceptions', () {
    test('throws exception with method name on timeout', () {
      final client = RpcClient(devnetRpcUrl, timeout: Duration.zero);

      expectLater(
        client.getTransactionCount(),
        throwsA(
          isA<RpcTimeoutException>().having(
            (e) => e.message,
            'message',
            'RPC call getTransactionCount timed out.',
          ),
        ),
      );
    });

    test('throws exception with bulk method names on timeout', () {
      final client = RpcClient(devnetRpcUrl, timeout: Duration.zero);
      const transactions = [
        TransactionSignatureInformation(
          signature: 'signature',
          slot: 0,
          err: null,
          memo: null,
          blockTime: null,
        ),
        TransactionSignatureInformation(
          signature: 'signature',
          slot: 0,
          err: null,
          memo: null,
          blockTime: null,
        ),
      ];

      expectLater(
        client.getMultipleTransactions(transactions),
        throwsA(
          isA<RpcTimeoutException>().having(
            (e) => e.message,
            'message',
            'RPC call [getTransaction, getTransaction] timed out.',
          ),
        ),
      );
    });
  });

  group('RpcClient testsuite', () {
    final client = SolanaClient(
      rpcUrl: Uri.parse(devnetRpcUrl),
      websocketUrl: Uri.parse(devnetWebsocketUrl),
    );
    late Ed25519HDKeyPair destination;
    late Ed25519HDKeyPair source;
    int currentBalance = 0;

    setUpAll(() async {
      destination = await Ed25519HDKeyPair.fromMnemonic(generateMnemonic());
      source = await Ed25519HDKeyPair.fromMnemonic(generateMnemonic(), account: 1);

      currentBalance = await _createTokenAccount(client, source);
    });

    test('Call requestAirdrop and add SOL to an account works', () async {
      const int addedBalance = 100 * lamportsPerSol;
      final String signature = await client.rpcClient.requestAirdrop(
        source.address,
        addedBalance,
        commitment: Commitment.confirmed,
      );
      expect(signature, isNot(null));
      await client.waitForSignatureStatus(signature, status: ConfirmationStatus.confirmed);
      final int balance = await client.rpcClient
          .getBalance(source.address, commitment: Commitment.confirmed)
          .value;
      // Update the global balance
      currentBalance += addedBalance;
      // Check that it matches
      expect(balance, currentBalance);
    });

    test('Read the recent blockhash', () async {
      final bh = await client.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed).value;
      final blockHash = RecentBlockhash(
        blockhash: bh.blockhash,
        feeCalculator: const FeeCalculator(lamportsPerSignature: 500),
      );
      expect(blockHash, isNot(null));
      expect(blockHash.blockhash, isNot(null));
      expect(blockHash.blockhash, isNot(''));
      expect(blockHash.feeCalculator, isNot(null));
      expect(blockHash.feeCalculator.lamportsPerSignature, isNot(null));
    });

    test('Read the balance of an account', () async {
      final int balance = await client.rpcClient
          .getBalance(source.address, commitment: Commitment.confirmed)
          .value;
      expect(balance, currentBalance);
    });

    test('Get all the account information of an account', () async {
      final Account? accountInfo = await client.rpcClient
          .getAccountInfo(
            source.address,
            encoding: Encoding.jsonParsed,
            commitment: Commitment.confirmed,
          )
          .value;
      expect(accountInfo, isNotNull);
      expect(accountInfo?.lamports, currentBalance);
      expect(accountInfo?.owner, SystemProgram.programId);
      expect(accountInfo?.executable, false);
    });

    test('Simulate a transfer', () async {
      final bh = await client.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed).value;
      final instruction = SystemInstruction.transfer(
        fundingAccount: source.publicKey,
        recipientAccount: destination.publicKey,
        lamports: _transferredAmount,
      );
      final SignedTx signedTx = await source.signMessage(
        message: Message.only(instruction),
        recentBlockhash: bh.blockhash,
      );
      final TransactionStatus transferResult = await client.rpcClient
          .simulateTransaction(signedTx.encode(), commitment: Commitment.confirmed)
          .value;
      expect(transferResult.err, isNull);
    });

    test('Transfer SOL', () async {
      final bh = await client.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed).value;
      final instruction = SystemInstruction.transfer(
        fundingAccount: source.publicKey,
        recipientAccount: destination.publicKey,
        lamports: _transferredAmount,
      );
      final SignedTx signedTx = await source.signMessage(
        message: Message.only(instruction),
        recentBlockhash: bh.blockhash,
      );
      final String signature = await client.rpcClient.sendTransaction(
        signedTx.encode(),
        preflightCommitment: Commitment.confirmed,
      );
      expect(signature, signedTx.signatures.first.toBase58());
      await expectLater(
        client.waitForSignatureStatus(signature, status: ConfirmationStatus.confirmed),
        completes,
      );
      final int balance = await client.rpcClient
          .getBalance(destination.address, commitment: Commitment.confirmed)
          .value;
      expect(balance, greaterThan(0));
    });

    test('Transfer SOL to the same address', () async {
      final bh = await client.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed).value;
      final instruction = SystemInstruction.transfer(
        fundingAccount: source.publicKey,
        recipientAccount: source.publicKey,
        lamports: _transferredAmount,
      );
      final SignedTx signedTx = await source.signMessage(
        message: Message.only(instruction),
        recentBlockhash: bh.blockhash,
      );
      final String signature = await client.rpcClient.sendTransaction(
        signedTx.encode(),
        preflightCommitment: Commitment.confirmed,
      );
      expect(signature, isNot(null));

      await expectLater(
        client.waitForSignatureStatus(signature, status: Commitment.confirmed),
        completes,
      );
    });

    test('List recent transactions', () async {
      final txs = await client.rpcClient.getTransactionsList(
        source.publicKey,
        commitment: Commitment.confirmed,
      );
      expect(txs, isNot(null));

      for (final tx in txs) {
        expect(tx, isNot(null));
      }
      expect(txs.length, greaterThan(0));
    });

    test('List recent transactions for multiple addresses', () async {
      final secondWallet = await Ed25519HDKeyPair.fromMnemonic(generateMnemonic(), account: 2);

      await client.rpcClient.requestAirdrop(
        secondWallet.address,
        _transferredAmount,
        commitment: Commitment.confirmed,
      );

      final txs = await client.rpcClient.getTransactionListForAddresses([
        source.publicKey,
        secondWallet.publicKey,
      ], commitment: Commitment.confirmed);

      expect(txs, isNot(null));

      for (final tx in txs) {
        expect(tx, isNot(null));
      }

      expect(txs.length, greaterThan(0));
    });

    test('Transfer SOL with Versioned Transaction', () async {
      final bh = await client.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed).value;
      final instruction = SystemInstruction.transfer(
        fundingAccount: source.publicKey,
        recipientAccount: destination.publicKey,
        lamports: _transferredAmount,
      );

      final message = Message.only(instruction);

      final compiledMessage = message.compileV0(
        recentBlockhash: bh.blockhash,
        feePayer: source.publicKey,
      );
      final sign = await source.sign(compiledMessage.toByteArray());

      final SignedTx signedTx = SignedTx(signatures: [sign], compiledMessage: compiledMessage);

      final String signature = await client.rpcClient.sendTransaction(
        signedTx.encode(),
        preflightCommitment: Commitment.confirmed,
      );
      expect(signature, signedTx.signatures.first.toBase58());
      await expectLater(
        client.waitForSignatureStatus(signature, status: ConfirmationStatus.confirmed),
        completes,
      );
      final int balance = await client.rpcClient
          .getBalance(destination.address, commitment: Commitment.confirmed)
          .value;
      expect(balance, greaterThan(0));

      final transaction = await client.rpcClient.getTransaction(
        signature,
        commitment: Commitment.confirmed,
        maxSupportedTransactionVersion: 0,
      );

      expect(transaction?.version?.version, 0);
    });
  });

  group('Test commitment', () {
    final client = SolanaClient(
      rpcUrl: Uri.parse(devnetRpcUrl),
      websocketUrl: Uri.parse(devnetWebsocketUrl),
    );

    late Ed25519HDKeyPair wallet;

    setUp(() async {
      wallet = await Ed25519HDKeyPair.fromMnemonic(generateMnemonic());
    });

    test('Balance is not updated until tx is finalized', () async {
      const int addedBalance = 5 * lamportsPerSol;
      final String signature = await client.rpcClient.requestAirdrop(
        wallet.address,
        addedBalance,
        commitment: Commitment.confirmed,
      );

      await client.waitForSignatureStatus(signature, status: Commitment.confirmed);

      int balance = await client.rpcClient.getBalance(wallet.address).value;
      expect(balance, equals(0));

      await client.waitForSignatureStatus(signature, status: Commitment.finalized);
      balance = await client.rpcClient.getBalance(wallet.address).value;

      expect(balance, greaterThan(0));
    });

    test('Balance is updated if requested with confirmed commitment', () async {
      const int addedBalance = 5 * lamportsPerSol;
      final String signature = await client.rpcClient.requestAirdrop(
        wallet.address,
        addedBalance,
        commitment: Commitment.confirmed,
      );

      await client.waitForSignatureStatus(signature, status: Commitment.confirmed);

      final int balance = await client.rpcClient
          .getBalance(wallet.address, commitment: Commitment.confirmed)
          .value;
      expect(balance, greaterThan(0));
    });

    test('Get token accounts by owner', () async {
      final accountKeyPair = await Ed25519HDKeyPair.random();
      final accountCreator = await Ed25519HDKeyPair.random();

      await client.requestAirdrop(
        address: wallet.publicKey,
        lamports: 100 * lamportsPerSol,
        commitment: Commitment.confirmed,
      );
      await client.requestAirdrop(
        address: accountCreator.publicKey,
        lamports: 100 * lamportsPerSol,
        commitment: Commitment.confirmed,
      );

      final token = await client.initializeMint(
        mintAuthority: wallet,
        decimals: 8,
        commitment: Commitment.confirmed,
      );

      final tokenAccount = await client.createAssociatedTokenAccount(
        owner: accountKeyPair.publicKey,
        mint: token.address,
        funder: accountCreator,
        commitment: Commitment.confirmed,
      );

      final accounts = await client.rpcClient
          .getTokenAccountsByOwner(
            accountKeyPair.address,
            const TokenAccountsFilter.byProgramId(TokenProgram.programId),
            encoding: Encoding.jsonParsed,
            commitment: Commitment.confirmed,
          )
          .value;

      expect(accounts.length, equals(1));
      expect(accounts.first.pubkey, tokenAccount.pubkey);
      expect(accounts.first.account.data, isA<ParsedAccountData>());

      final data = accounts.first.account.data as ParsedAccountData;
      final programData = data as ParsedSplTokenProgramAccountData;
      final parsed = programData.parsed as TokenAccountData;
      expect(parsed.info.mint, token.address.toBase58());
    });
  });

  group('Test informational methods', () {
    final client = SolanaClient(
      rpcUrl: Uri.parse(devnetRpcUrl),
      websocketUrl: Uri.parse(devnetWebsocketUrl),
    );
    late final Ed25519HDKeyPair sampleSigner;

    setUpAll(() async {
      sampleSigner = await Ed25519HDKeyPair.random();

      await client.requestAirdrop(
        address: sampleSigner.publicKey,
        lamports: 10 * lamportsPerSol,
        commitment: Commitment.confirmed,
      );
    });

    test('Call to getVersion() succeeds and parses the response correctly', () async {
      final version = await client.rpcClient.getVersion();

      expect(version.solanaCore.codeUnitAt(0), anyOf(equals(50), equals(51), equals(52)));
      expect(version.solanaCore.codeUnitAt(1), equals(46));
    });

    test('Call to getSlot() succeeds', () async {
      final slot = await client.rpcClient.getSlot(commitment: Commitment.finalized);
      expect(slot, greaterThan(0));
    });

    test('Call to getSupply() succeeds with default parameters', () async {
      final supply = await client.rpcClient.getSupply(commitment: Commitment.finalized).value;

      expect(supply.total, equals(supply.circulating + supply.nonCirculating));
      expect(supply.nonCirculatingAccounts.length, greaterThan(0));
    });

    test('Call to getSupply() succeeds with circulating accounts list', () async {
      final supply = await client.rpcClient
          .getSupply(commitment: Commitment.finalized, excludeNonCirculatingAccountsList: false)
          .value;

      expect(supply.total, equals(supply.circulating + supply.nonCirculating));
      expect(supply.nonCirculatingAccounts.length, greaterThan(0));
    });

    test('Call to getSupply() succeeds excluding circulating accounts list', () async {
      final supply = await client.rpcClient
          .getSupply(commitment: Commitment.confirmed, excludeNonCirculatingAccountsList: true)
          .value;

      expect(supply.total, equals(supply.circulating + supply.nonCirculating));
      expect(supply.nonCirculatingAccounts.length, equals(0));
    });

    test('Call to getLeaderSchedule() succeeds with default parameters', () async {
      // FIXME: should not need the parameter (fix the generator)
      final leaderSchedule = await client.rpcClient.getLeaderSchedule(null);
      expect(leaderSchedule, isNotNull);
    });

    test('Call to getLargerAccounts() succeeds with default parameters', () async {
      final largestAccounts = await client.rpcClient.getLargestAccounts().value;
      expect(largestAccounts.length, equals(20));
    });

    test('Call to getLargerAccounts() succeeds with commitment', () async {
      final largestAccounts = await client.rpcClient
          .getLargestAccounts(commitment: Commitment.processed)
          .value;
      expect(largestAccounts.length, equals(20));
    });

    test('Call to getLargerAccounts() succeeds with filter: circulating', () async {
      final largestAccounts = await client.rpcClient
          .getLargestAccounts(filter: CirculationStatus.circulating)
          .value;
      expect(largestAccounts.length, equals(20));
    });

    test('Call to getLargerAccounts() succeeds with filter: non-circulating', () async {
      final largestAccounts = await client.rpcClient
          .getLargestAccounts(filter: CirculationStatus.nonCirculating)
          .value;
      expect(largestAccounts.length, equals(0));
    });

    test('Call to getMultipleAccounts() succeeds with jsonParsed encoding', () async {
      final largestAccounts = await client.rpcClient.getLargestAccounts().value;

      final accounts = await client.rpcClient
          .getMultipleAccounts(
            largestAccounts.map((l) => l.address).toList(),
            encoding: Encoding.jsonParsed,
          )
          .value;

      expect(accounts.length, equals(largestAccounts.length));
    });

    test('Call to getMultipleAccounts() succeeds with base64 encoding', () async {
      final largestAccounts = await client.rpcClient.getLargestAccounts().value;

      final accounts = await client.rpcClient
          .getMultipleAccounts(
            largestAccounts.map((l) => l.address).toList(),
            encoding: Encoding.base64,
          )
          .value;

      expect(accounts.length, equals(largestAccounts.length));
    });

    test('Call to getMultipleAccounts() succeeds with base58 encoding', () async {
      final largestAccounts = await client.rpcClient.getLargestAccounts().value;

      final future = client.rpcClient.getMultipleAccounts(
        largestAccounts.map((l) => l.address).toList(),
        encoding: Encoding.base58,
      );

      await expectLater(future, throwsA(isA<JsonRpcException>()));
    });

    test('Call to getBlockProduction() succeeds', () async {
      final blockProduction = await client.rpcClient.getBlockProduction();
      expect(blockProduction.value.range.firstSlot, isNonNegative);
    });

    test('Call to getTokenLargestAccounts succeeds', () async {
      final wallet = await Ed25519HDKeyPair.random();
      final token = await _createToken(
        decimals: 0,
        supply: 1,
        transferSomeToAddress: wallet.publicKey,
        transferSomeToAmount: 1,
      );
      final List<TokenLargestAccount> result = await client.rpcClient
          .getTokenLargestAccounts(token.address.toBase58(), commitment: Commitment.confirmed)
          .value;
      expect(result, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Call to getGenesisHash() succeeds', () async {
      final genesisHash = await client.rpcClient.getGenesisHash();
      // TODO(IA): could check if it is a valid base58 string
      expect(genesisHash, isNotEmpty);
    });

    test('Call to getHealth() succeeds', () async {
      final health = await client.rpcClient.getHealth();
      expect(health, equals('ok'));
    });

    test('Call to getInflationGovernor() succeeds', () async {
      final inflationGovernor = await client.rpcClient.getInflationGovernor();
      expect(inflationGovernor.foundation, isNonNegative);
    });

    test('Call to getInflationGovernor() succeeds with commitment', () async {
      final inflationGovernor = await client.rpcClient.getInflationGovernor(
        commitment: Commitment.finalized,
      );
      expect(inflationGovernor.foundation, isNonNegative);
    });

    test('Call to getInflationRate() succeeds', () async {
      final inflationGovernor = await client.rpcClient.getInflationRate();
      expect(inflationGovernor.foundation, isNonNegative);
    });

    test('Call to getInflationReward() succeeds', () async {
      final inflationReward = await client.rpcClient.getInflationReward([sampleSigner.address]);

      expect(inflationReward.length, greaterThan(0));
    }, skip: 'Needs too many slots to correctly work');

    test('Call to getClusterNodes() succeeds', () async {
      final clusterNodes = await client.rpcClient.getClusterNodes();
      expect(clusterNodes.length, equals(1));
    });

    test('Call to getBlockTime() succeeds', () async {
      final blockTime = await client.rpcClient.getBlockTime(
        await client.rpcClient.getFirstAvailableBlock(),
      );

      expect(blockTime, greaterThan(0));
    });

    test('Call to getEpochInfo() succeeds', () async {
      final epochInfo = await client.rpcClient.getEpochInfo();
      expect(epochInfo.absoluteSlot, greaterThan(0));
    });

    test('Call to getEpochInfo() succeeds with commitment', () async {
      final epochInfo = await client.rpcClient.getEpochInfo(commitment: Commitment.finalized);

      expect(epochInfo.absoluteSlot, greaterThan(0));
    });

    test('Call to getEpochSchedule() succeeds', () async {
      final epochInfo = await client.rpcClient.getEpochSchedule();
      expect(epochInfo.slotsPerEpoch, greaterThan(0));
    });

    test('Call to isBlockhashValid() succeeds', () async {
      final bh = await client.rpcClient.getLatestBlockhash().value;
      final bool isBlockhashValid = await client.rpcClient.isBlockhashValid(bh.blockhash).value;

      expect(isBlockhashValid, true);
    });

    test('Call to getHighestSnapshotSlot() succeeds', () async {
      final snapshot = await client.rpcClient.getHighestSnapshotSlot();
      expect(snapshot.full, isPositive);
    });

    test('Call to getLatestBlockhash() succeeds', () async {
      final blockhash = await client.rpcClient.getLatestBlockhash();
      expect(blockhash.value.blockhash, isNotEmpty);
    });

    test('Call to getStakeMinimumDelegation() succeeds', () async {
      final stakeMinimumDelegation = await client.rpcClient.getStakeMinimumDelegation();

      expect(stakeMinimumDelegation.value, isA<int>());
    });

    test('Call to getFirstAvailableBlock() succeeds', () async {
      final block = await client.rpcClient.getFirstAvailableBlock();
      expect(block, greaterThanOrEqualTo(0));
    });

    test('Call to getIdentity() succeeds', () async {
      final identity = await client.rpcClient.getIdentity();
      expect(identity.identity, isNotEmpty);
    });

    test('Call to getMaxRetransmitSlot() succeeds', () async {
      final maxRetransmitSlot = await client.rpcClient.getMaxRetransmitSlot();
      expect(maxRetransmitSlot, isA<int>());
    });

    test('Call to getMaxShredInsertSlot() succeeds', () async {
      final maxRetransmitSlot = await client.rpcClient.getMaxShredInsertSlot();
      expect(maxRetransmitSlot, isA<int>());
    });

    test('Call to getMinimumBalanceForRentExemption() succeeds', () async {
      final maxRetransmitSlot = await client.rpcClient.getMinimumBalanceForRentExemption(302);
      expect(maxRetransmitSlot, isA<int>());
    });

    test('Call to getProgramAccounts() with jsonParsed encoding succeeds', () async {
      final programAccounts = await client.rpcClient.getProgramAccounts(
        TokenProgram.programId,
        encoding: Encoding.jsonParsed,
      );

      expect(programAccounts.length, greaterThan(0));
    });

    test(
      'Call to getProgramAccounts() with base58 encoding succeeds',
      () async {
        final programAccounts = await client.rpcClient.getProgramAccounts(
          TokenProgram.programId,
          encoding: Encoding.base58,
        );

        expect(programAccounts.length, greaterThan(0));
      },
      skip: 'We cannot guess the size of the account, so we cannot test this for now',
    );

    test('Call to getProgramAccounts() with base64 encoding succeeds', () async {
      final programAccounts = await client.rpcClient.getProgramAccounts(
        TokenProgram.programId,
        encoding: Encoding.base64,
      );

      expect(programAccounts.length, greaterThan(0));
    });

    test('Call to getProgramAccounts() with memcmp filter succeeds', () async {
      final nonExistentMint = (await Ed25519HDKeyPair.random()).publicKey.bytes;

      final programAccounts = await client.rpcClient.getProgramAccounts(
        TokenProgram.programId,
        encoding: Encoding.jsonParsed,
        filters: [ProgramDataFilter.memcmp(offset: 0, bytes: nonExistentMint)],
      );

      expect(programAccounts.length, equals(0));
    });

    test('Call to getProgramAccounts() with dataSize filter succeeds', () async {
      final programAccounts = await client.rpcClient.getProgramAccounts(
        TokenProgram.programId,
        encoding: Encoding.jsonParsed,
        filters: const [ProgramDataFilter.dataSize(10)],
      );

      expect(programAccounts.length, equals(0));
    });

    test('Call to getSlotLeader() succeeds', () async {
      final slotLeader = await client.rpcClient.getSlotLeader();
      expect(slotLeader, _validAddressMatcher);
    });

    test('Call to getSlotLeaders() succeeds', () async {
      final slotLeaders = await client.rpcClient.getSlotLeaders(0, 4);

      expect(slotLeaders.length, lessThanOrEqualTo(4));
      expect(slotLeaders.every(isValidAddress), equals(true));
    }, skip: 'Leader schedule for epoch 0 is unavailable');

    test('Call to getVoteAccounts() succeeds', () async {
      final voteAccounts = await client.rpcClient.getVoteAccounts();

      expect(voteAccounts.delinquent.every((va) => isValidAddress(va.votePubkey)), equals(true));
      expect(voteAccounts.current.every((va) => isValidAddress(va.votePubkey)), equals(true));
    });

    test('Call to minimumLedgerSlot() succeeds', () async {
      final minimumLedgerSlot = await client.rpcClient.minimumLedgerSlot();
      expect(minimumLedgerSlot, greaterThanOrEqualTo(0));
    });

    test('Call to getAccountInfo() succeeds with base58 works for the right data size', () async {
      final accountAddress = await _createAccount(client, 128);

      final account = await client.rpcClient.getAccountInfo(
        accountAddress,
        encoding: Encoding.base58,
        commitment: Commitment.confirmed,
      );

      expect(account.value, isNotNull);
    });

    test('Call to getAccountInfo() succeeds with base58 throws for large data', () async {
      final accountAddress = await _createAccount(client, 130);

      final future = client.rpcClient.getAccountInfo(
        accountAddress,
        encoding: Encoding.base58,
        commitment: Commitment.confirmed,
      );

      await expectLater(future, throwsA(isA<JsonRpcException>()));
    });

    test('Call to getAccountInfo() succeeds with base64 encoding', () async {
      final accountAddress = await _createAccount(client, 230);

      final account = await client.rpcClient.getAccountInfo(
        accountAddress,
        encoding: Encoding.base64,
        commitment: Commitment.confirmed,
      );

      expect(account.value, isNotNull);
    });
  });
}

Future<int> _createTokenAccount(SolanaClient client, Ed25519HDKeyPair source) async {
  final accountKeyPair = await Ed25519HDKeyPair.fromMnemonic(generateMnemonic(), account: 0);
  await client.requestAirdrop(
    address: source.publicKey,
    lamports: 10 * lamportsPerSol,
    commitment: Commitment.confirmed,
  );

  final token = await _createToken(
    decimals: 2,
    supply: 100_000_000_000_000,
    transferSomeToAddress: source.publicKey,
    transferSomeToAmount: 1000,
  );
  final rent = await client.rpcClient.getMinimumBalanceForRentExemption(
    TokenProgram.neededAccountSpace,
    commitment: Commitment.confirmed,
  );

  final instructions = TokenInstruction.createAndInitializeAccount(
    mint: token.address,
    owner: source.publicKey,
    address: accountKeyPair.publicKey,
    rent: rent,
    space: TokenProgram.neededAccountSpace,
  );

  final bh = await client.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed).value;
  final recentBlockhash = RecentBlockhash(
    blockhash: bh.blockhash,
    feeCalculator: const FeeCalculator(lamportsPerSignature: 5000),
  );

  await client.sendAndConfirmTransaction(
    message: Message(instructions: instructions),
    signers: [source, accountKeyPair],
    commitment: Commitment.confirmed,
  );

  final fee = recentBlockhash.feeCalculator.lamportsPerSignature;

  return 10 * lamportsPerSol - rent - 2 * fee;
}

Future<String> _createAccount(SolanaClient client, int size) async {
  final source = await Ed25519HDKeyPair.fromMnemonic(generateMnemonic(), account: 0);

  final accountKeyPair = await Ed25519HDKeyPair.fromMnemonic(generateMnemonic(), account: 0);

  await client.requestAirdrop(
    address: source.publicKey,
    lamports: 10 * lamportsPerSol,
    commitment: Commitment.confirmed,
  );

  final instruction = SystemInstruction.createAccount(
    fundingAccount: source.publicKey,
    owner: SystemProgram.id,
    newAccount: accountKeyPair.publicKey,
    lamports: await client.rpcClient.getMinimumBalanceForRentExemption(
      size,
      commitment: Commitment.finalized,
    ),
    space: size,
  );
  final bh = await client.rpcClient.getLatestBlockhash(commitment: Commitment.finalized).value;

  final signedTx = await signTransaction(bh, Message.only(instruction), [source, accountKeyPair]);
  final signature = await client.rpcClient.sendTransaction(
    signedTx.encode(),
    preflightCommitment: Commitment.confirmed,
  );
  await client.waitForSignatureStatus(signature, status: ConfirmationStatus.confirmed);

  return accountKeyPair.address;
}

const Matcher _validAddressMatcher = _AddressMatcher();

class _AddressMatcher extends Matcher {
  const _AddressMatcher();

  @override
  Description describe(Description description) => description.add('is valid address');

  @override
  bool matches(covariant String item, Map<dynamic, dynamic> matchState) => isValidAddress(item);
}

Future<Mint> _createToken({
  required int decimals,
  required int supply,
  required Ed25519HDPublicKey transferSomeToAddress,
  required int transferSomeToAmount,
}) async {
  // This is the authority that will create the token and be able to emit
  // currency.
  final tokenMintAuthority = await Ed25519HDKeyPair.random();
  final client = createTestSolanaClient();

  // Put some tokens in the authority wallet.
  await client.requestAirdrop(
    address: tokenMintAuthority.publicKey,
    lamports: 5 * lamportsPerSol,
    commitment: Commitment.confirmed,
  );

  // Now we have SOL to create the token.
  final splToken = await client.initializeMint(
    mintAuthority: tokenMintAuthority,
    decimals: decimals,
    commitment: Commitment.confirmed,
  );

  // Now lets create an account to store the supply. All SPL token transfer must
  // be done to an associated token account which belongs to the specific token.
  //
  // The mint authority will also, own the total supply of the token.
  final supplyAccount = await findAssociatedTokenAddress(
    owner: tokenMintAuthority.publicKey,
    mint: splToken.address,
  );
  await client.createAssociatedTokenAccount(
    mint: splToken.address,
    funder: tokenMintAuthority,
    commitment: Commitment.confirmed,
  );

  // Now we have a spl token, let's add the supply to it.
  await client.mintTo(
    authority: tokenMintAuthority,
    destination: supplyAccount,
    amount: supply,
    mint: splToken.address,
    commitment: Commitment.confirmed,
  );

  // We must check if the recipient has an associated token account, if not we
  // have to create it.
  await client.getAssociatedTokenAccount(
        mint: splToken.address,
        owner: transferSomeToAddress,
        commitment: Commitment.confirmed,
      ) ??
      await client.createAssociatedTokenAccount(
        mint: splToken.address,
        funder: tokenMintAuthority,
        owner: transferSomeToAddress,
        commitment: Commitment.confirmed,
      );

  // And finally transfer them from the supply account to the destination
  // account, this is similar to what a faucet does.
  await client.transferSplToken(
    owner: tokenMintAuthority,
    destination: transferSomeToAddress,
    amount: transferSomeToAmount,
    mint: splToken.address,
    commitment: Commitment.confirmed,
  );

  return client.getMint(address: splToken.address, commitment: Commitment.confirmed);
}
