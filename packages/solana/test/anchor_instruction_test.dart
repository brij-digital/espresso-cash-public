// @dart=3.9

@TestOn('vm')
library;

import 'dart:io';

import 'package:solana/anchor.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

import 'anchor_tutorial_types/basic1.dart';
import 'config.dart';

void main() {
  // ignore: avoid-unnecessary-late, needed here
  late final Ed25519HDKeyPair payer;
  late final Ed25519HDKeyPair updater;
  final client = SolanaClient(
    rpcUrl: Uri.parse(devnetRpcUrl),
    websocketUrl: Uri.parse(devnetWebsocketUrl),
  );

  setUpAll(() async {
    payer = await Ed25519HDKeyPair.random();
    updater = await Ed25519HDKeyPair.random();

    await client.requestAirdrop(
      address: payer.publicKey,
      lamports: 10 * lamportsPerSol,
      commitment: Commitment.confirmed,
    );
  });

  test('Call basic-0 initialize method', () async {
    final instructions = [
      await AnchorInstruction.forMethod(
        programId: _basic0,
        method: 'initialize',
        accounts: [],
        namespace: 'global',
      ),
    ];
    final message = Message(instructions: instructions);
    final signature = await client.sendAndConfirmTransaction(
      message: message,
      signers: [payer],
      commitment: Commitment.confirmed,
    );

    expect(signature, isNotEmpty);
  }, skip: true);

  test('Call basic-1 initialize method', () async {
    // 8 bytes for the discriminator and 8 bytes for the data
    const space = 16;
    final rent = await client.rpcClient.getMinimumBalanceForRentExemption(space);
    final instructions = [
      SystemInstruction.createAccount(
        lamports: rent,
        owner: _basic1,
        newAccount: updater.publicKey,
        fundingAccount: payer.publicKey,
        space: space,
      ),
      await AnchorInstruction.forMethod(
        programId: _basic1,
        method: 'initialize',
        arguments: ByteArray(Basic1Arguments(data: BigInt.from(100)).toBorsh().toList()),
        accounts: <AccountMeta>[
          AccountMeta.writeable(pubKey: updater.publicKey, isSigner: false),
          AccountMeta.readonly(pubKey: Ed25519HDPublicKey.fromBase58(Sysvar.rent), isSigner: false),
        ],
        namespace: 'global',
      ),
    ];
    final message = Message(instructions: instructions);
    await client.sendAndConfirmTransaction(
      message: message,
      signers: [payer, updater],
      commitment: Commitment.confirmed,
    );

    final account = await client.rpcClient
        .getAccountInfo(updater.address, commitment: Commitment.confirmed)
        .value;

    expect(account, isNotNull);
    final rawData = account?.data;
    expect(rawData, isNotNull);
    // ignore: avoid-non-null-assertion, cannot be null here
    final data = Basic1DataAccount.fromAccountData(rawData!);
    final discriminator = await computeDiscriminator('account', 'MyAccount');
    expect(data.data, equals(100));
    expect(data.discriminator, equals(discriminator));
  }, skip: true);

  test('Call basic-1 update method', () async {
    // Call update
    final instructions = [
      await AnchorInstruction.forMethod(
        programId: _basic1,
        method: 'update',
        arguments: ByteArray(Basic1Arguments(data: BigInt.from(25)).toBorsh().toList()),
        accounts: <AccountMeta>[AccountMeta.writeable(pubKey: updater.publicKey, isSigner: false)],
        namespace: 'global',
      ),
    ];

    final message = Message(instructions: instructions);
    await client.sendAndConfirmTransaction(
      message: message,
      signers: [payer],
      commitment: Commitment.confirmed,
    );

    final discriminator = await computeDiscriminator('account', 'MyAccount');
    final account = await client.rpcClient
        .getAccountInfo(updater.address, commitment: Commitment.confirmed)
        .value;

    expect(account, isNotNull);
    final rawData = account?.data;
    expect(rawData, isNotNull);
    // ignore: avoid-non-null-assertion, cannot be null here
    final dataAccount = Basic1DataAccount.fromAccountData(rawData!);
    expect(dataAccount.data, equals(25));
    expect(dataAccount.discriminator, equals(discriminator));
  }, skip: true);
}

final _basic0 = Ed25519HDPublicKey.fromBase58(
  Platform.environment['PROGRAM_ID_BASIC_0'] ?? '73JSEtceE6QVgN44rfYtfkB1HnMW3z1tQH1ek79CTQtX',
);
final _basic1 = Ed25519HDPublicKey.fromBase58(
  Platform.environment['PROGRAM_ID_BASIC_1'] ?? '6gYaFMp7H5iao1wDJ7q7BAaXjLJi1w6UvSrGH14oUv4n',
);
