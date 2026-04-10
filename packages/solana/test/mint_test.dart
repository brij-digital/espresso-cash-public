// @dart=3.9
// ignore_for_file: avoid-unnecessary-late

@TestOn('vm')
library;

import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  group('Initialize tokens:', () {
    late final Ed25519HDKeyPair owner;
    late final SolanaClient solanaClient;

    setUpAll(() async {
      solanaClient = createTestSolanaClient();
      owner = await Ed25519HDKeyPair.random();
      await solanaClient.requestAirdrop(
        lamports: lamportsPerSol,
        address: owner.publicKey,
        commitment: Commitment.confirmed,
      );
    });

    test('Creates a new mint without freeze authority', () async {
      final token = await solanaClient.initializeMint(
        mintAuthority: owner,
        decimals: 2,
        commitment: Commitment.confirmed,
      );

      expect(token.supply, BigInt.zero);
      expect(token.decimals, 2);
      expect(token.mintAuthority, owner.publicKey);
    });

    test('Creates a new mint with freeze authority', () async {
      final freezeAuthority = await Ed25519HDKeyPair.random();

      final token = await solanaClient.initializeMint(
        mintAuthority: owner,
        freezeAuthority: freezeAuthority.publicKey,
        decimals: 2,
        commitment: Commitment.confirmed,
      );

      expect(token.supply, BigInt.zero);
      expect(token.decimals, 2);
      expect(token.mintAuthority, owner.publicKey);
    });
  });

  group('SolanaClient for SPL tokens', () {
    late final Mint newToken;
    late final Ed25519HDKeyPair owner;
    late final SolanaClient solanaClient;

    setUpAll(() async {
      solanaClient = createTestSolanaClient();
      owner = await Ed25519HDKeyPair.random();
      await solanaClient.requestAirdrop(
        lamports: 100 * lamportsPerSol,
        address: owner.publicKey,
        commitment: Commitment.confirmed,
      );
    });

    test('Create a new mint', () async {
      final token = await solanaClient.initializeMint(
        mintAuthority: owner,
        decimals: 2,
        commitment: Commitment.confirmed,
      );

      expect(token.supply, equals(BigInt.zero));
      expect(token.decimals, equals(2));

      newToken = token;
    });

    test('Create an account with', () async {
      final creator = await Ed25519HDKeyPair.random();
      final account = await Ed25519HDKeyPair.random();
      await solanaClient.requestAirdrop(
        lamports: 100 * lamportsPerSol,
        address: creator.publicKey,
        commitment: Commitment.confirmed,
      );
      await solanaClient.createTokenAccount(
        account: account,
        creator: creator,
        mint: newToken.address,
        commitment: Commitment.confirmed,
      );
    });

    test('Create an associated token account', () async {
      List<ProgramAccount> accounts = await solanaClient.rpcClient
          .getTokenAccountsByOwner(
            owner.address,
            TokenAccountsFilter.byMint(newToken.address.toBase58()),
            commitment: Commitment.confirmed,
          )
          .value;
      expect(accounts, isNot(null));
      expect(accounts.length, equals(0));

      final newAccount = await solanaClient.createAssociatedTokenAccount(
        funder: owner,
        mint: newToken.address,
        commitment: Commitment.confirmed,
      );

      accounts = await solanaClient.rpcClient
          .getTokenAccountsByOwner(
            owner.address,
            TokenAccountsFilter.byMint(newToken.address.toBase58()),
            encoding: Encoding.jsonParsed,
            commitment: Commitment.confirmed,
          )
          .value;
      // ignore: avoid-duplicate-test-assertions, accounts have changed
      expect(accounts, isNot(null));
      expect(accounts.length, equals(1));
      expect(accounts.where((a) => a.pubkey == newAccount.pubkey), isNot(null));
    });

    test('Mint the newly created token and account', () async {
      final accounts = await solanaClient.rpcClient
          .getTokenAccountsByOwner(
            owner.address,
            TokenAccountsFilter.byMint(newToken.address.toBase58()),
            encoding: Encoding.jsonParsed,
            commitment: Commitment.confirmed,
          )
          .value;
      await solanaClient.mintTo(
        destination: Ed25519HDPublicKey.fromBase58(accounts.first.pubkey),
        amount: _totalSupply,
        mint: newToken.address,
        authority: owner,
        commitment: Commitment.confirmed,
      );

      final TokenAmount tokenSupply = await solanaClient.rpcClient
          .getTokenSupply(newToken.address.toBase58(), commitment: Commitment.confirmed)
          .value;

      expect(int.parse(tokenSupply.amount), equals(_totalSupply));
    });

    test('Transfer tokens succeeds when associated accounts exist', () async {
      final recipient = await Ed25519HDKeyPair.random();
      // The account does not exist, so create it
      final account = await solanaClient.createAssociatedTokenAccount(
        owner: recipient.publicKey,
        funder: owner,
        mint: newToken.address,
        commitment: Commitment.confirmed,
      );
      expect(account, isA<ProgramAccount>());
      // Send to the newly created account
      await solanaClient.transferSplToken(
        owner: owner,
        destination: recipient.publicKey,
        amount: 100,
        mint: newToken.address,
        commitment: Commitment.confirmed,
      );
      final balance = await solanaClient.rpcClient
          .getTokenAccountBalance(account.pubkey, commitment: Commitment.confirmed)
          .value;

      expect(balance.amount, '100');
    });

    test('Transfer tokens succeeds with fee payer', () async {
      final recipient = await Ed25519HDKeyPair.random();
      final feePayer = await Ed25519HDKeyPair.random();
      // Add some tokens to pay for fees
      await solanaClient.requestAirdrop(
        lamports: 100 * lamportsPerSol,
        address: feePayer.publicKey,
        commitment: Commitment.confirmed,
      );

      // The account does not exist, so create it
      final account = await solanaClient.createAssociatedTokenAccount(
        owner: recipient.publicKey,
        funder: owner,
        mint: newToken.address,
        commitment: Commitment.confirmed,
      );
      // A sender must have the appropriate associated account, in case they
      // don't it's an error and we should throw an exception.
      final sourceAssociatedTokenAddress = await solanaClient.getAssociatedTokenAccount(
        mint: newToken.address,
        owner: owner.publicKey,
        commitment: Commitment.confirmed,
      );
      // A recipient needs an associated account as well
      final destinationAssociatedTokenAddress = await solanaClient.getAssociatedTokenAccount(
        mint: newToken.address,
        owner: recipient.publicKey,
        commitment: Commitment.confirmed,
      );
      expect(sourceAssociatedTokenAddress, isNotNull);
      expect(destinationAssociatedTokenAddress, isNotNull);

      expect(account, isA<ProgramAccount>());
      // Send to the newly created account
      final instruction = TokenInstruction.transfer(
        source: Ed25519HDPublicKey.fromBase58(
          // ignore: avoid-non-null-assertion, cannot be null here
          sourceAssociatedTokenAddress!.pubkey,
        ),
        destination: Ed25519HDPublicKey.fromBase58(
          // ignore: avoid-non-null-assertion, cannot be null here
          destinationAssociatedTokenAddress!.pubkey,
        ),
        amount: 100,
        owner: owner.publicKey,
      );

      final signature = await solanaClient.sendAndConfirmTransaction(
        message: Message.only(instruction),
        signers: [feePayer, owner],
        commitment: Commitment.confirmed,
      );

      expect(signature, isNot(null));
    });

    test('Fails to transfer tokens if the recipient has no associated token account', () async {
      final recipient = await Ed25519HDKeyPair.random();
      await expectLater(
        solanaClient.transferSplToken(
          owner: owner,
          destination: recipient.publicKey,
          amount: 100,
          mint: newToken.address,
          commitment: Commitment.confirmed,
        ),
        throwsA(isA<NoAssociatedTokenAccountException>()),
      );
    });

    test('Fails to transfer tokens if the sender has no associated token account', () async {
      final sender = await Ed25519HDKeyPair.random();
      await expectLater(
        solanaClient.transferSplToken(
          owner: sender,
          destination: owner.publicKey,
          amount: 100,
          mint: newToken.address,
          commitment: Commitment.confirmed,
        ),
        throwsA(isA<NoAssociatedTokenAccountException>()),
      );
    });

    test('Send transfer instruction in an existing transaction', () async {
      final destination = await Ed25519HDKeyPair.random();

      final associatedSourceAddress = await findAssociatedTokenAddress(
        owner: owner.publicKey,
        mint: newToken.address,
      );
      final destinationAccount = await solanaClient.createTokenAccount(
        account: destination,
        creator: owner,
        mint: newToken.address,
        commitment: Commitment.confirmed,
      );

      final instructions = <Instruction>[
        SystemInstruction.transfer(
          fundingAccount: owner.publicKey,
          recipientAccount: destination.publicKey,
          lamports: lamportsPerSol,
        ),
        TokenInstruction.transfer(
          source: associatedSourceAddress,
          destination: Ed25519HDPublicKey.fromBase58(destinationAccount.owner),
          owner: owner.publicKey,
          amount: 10,
        ),
        MemoInstruction(
          memo: 'Nice, it works with many more instructions too',
          signers: [owner.publicKey],
        ),
      ];
      final message = Message(instructions: instructions);

      await solanaClient.sendAndConfirmTransaction(
        message: message,
        signers: [owner],
        commitment: Commitment.confirmed,
      );
    });
  });
}

const _totalSupply = 1_000_000_000_000;
