// @dart=3.9
// ignore_for_file: avoid-future-ignore

@TestOn('vm')
library;

import 'dart:async';

import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  test('accountSubscribe must return account owned by the system program', () async {
    const originalLamports = lamportsPerSol;
    final sender = await Ed25519HDKeyPair.random();
    final recipient = await Ed25519HDKeyPair.random();
    final rpcClient = RpcClient(devnetRpcUrl);
    final signature = await rpcClient.requestAirdrop(
      sender.address,
      originalLamports,
      commitment: Commitment.confirmed,
    );

    final subscriptionClient = SubscriptionClient.connect(devnetWebsocketUrl);

    final result = await subscriptionClient
        .signatureSubscribe(signature, commitment: Commitment.confirmed)
        .first;
    expect(result.err, isNull);

    // System program
    final accountStream = subscriptionClient.accountSubscribe(
      sender.address,
      commitment: Commitment.confirmed,
    );

    // Now send some tokens
    createTestSolanaClient()
        .transferLamports(
          destination: recipient.publicKey,
          lamports: lamportsPerSol ~/ 2,
          source: sender,
          commitment: Commitment.confirmed,
        )
        .ignore();

    final account = await accountStream.firstWhere(
      (Account data) => data.lamports < originalLamports,
    );

    expect(account.lamports, lessThan(originalLamports));
  });

  test('waitForSignatureStatus throws Exception on timout', () {
    final client = SubscriptionClient.connect(devnetWebsocketUrl);
    expect(
      () => client.waitForSignatureStatus(
        '3mx8XfKKwJHk3r5gezhedyzZTaDYgyA31jWp7DTfvifRJkouaA7kWwcReP1XRCvyAXeAgsUWQrTQffhR8rWHHCvN',
        status: ConfirmationStatus.finalized,
        timeout: Duration.zero,
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
