import 'package:auto_dto/src/dto_generator.dart';
import 'package:auto_dto/src/idl_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Dto Generation from IDL', () {
    final parser = IdlParser();
    final generator = DtoGenerator();

    test('should generate correct DTOs for instructions', () async {
      final idlPath = 'test/test1.json';
      final dtos = await parser.parse(idlPath);
      final generatedCode = generator.generate(dtos, libraryFileStem: 'test_dto');

      expect(generatedCode, contains("import 'dart:typed_data';"));
      expect(generatedCode, contains("import 'package:borsh_annotation/borsh_annotation.dart';"));
      expect(generatedCode, contains("import 'package:solana/solana.dart';"));
      expect(generatedCode, contains("part 'test_dto.g.dart';"));

      // Assertions for CreatePlayerProfileDto
      expect(generatedCode, contains("@BorshSerializable()"));
      expect(generatedCode, contains("class CreatePlayerProfileDto with _\$CreatePlayerProfileDto {"));
      expect(generatedCode, contains("  factory CreatePlayerProfileDto({"));
      expect(generatedCode, contains("    @BString() required String name,"));
      expect(generatedCode, contains("  }) = _CreatePlayerProfileDto;"));
      expect(generatedCode, contains("  CreatePlayerProfileDto._();"));
      expect(generatedCode, contains("  factory CreatePlayerProfileDto.fromBorsh(Uint8List data) =>"));
      expect(generatedCode, contains("      _\$CreatePlayerProfileDtoFromBorsh(data);"));

      // Assertions for ExecuteTossDto
      expect(generatedCode, contains("class ExecuteTossDto with _\$ExecuteTossDto {"));
      expect(generatedCode, contains("  factory ExecuteTossDto({"));
      expect(generatedCode, contains("    @BBool() required bool won,"));
      expect(generatedCode, contains("  }) = _ExecuteTossDto;"));
      expect(generatedCode, contains("  ExecuteTossDto._();"));
      expect(generatedCode, contains("  factory ExecuteTossDto.fromBorsh(Uint8List data) =>"));
      expect(generatedCode, contains("      _\$ExecuteTossDtoFromBorsh(data);"));
    });

    test('should generate DTOs with multiple field types', () async {
      final idlPath = 'test/test2.json';
      final dtos = await parser.parse(idlPath);
      final generatedCode = generator.generate(dtos, libraryFileStem: 'test2_dto');

      // Header & part
      expect(generatedCode, contains("import 'dart:typed_data';"));
      expect(generatedCode, contains("import 'package:borsh_annotation/borsh_annotation.dart';"));
      expect(generatedCode, contains("import 'package:solana/solana.dart';"));
      expect(generatedCode, contains("part 'test2_dto.g.dart';"));

      // ---- PlaceBetDto (u64, string, bool)
      expect(generatedCode, contains("@BorshSerializable()"));
      expect(generatedCode, contains("class PlaceBetDto with _\$PlaceBetDto {"));
      expect(generatedCode, contains("  factory PlaceBetDto({"));
      expect(generatedCode, contains("    @BU64() required BigInt amount,")); // u64 -> BigInt
      expect(generatedCode, contains("    @BString() required String memo,")); // string
      expect(generatedCode, contains("    @BBool() required bool won,"));     // bool
      expect(generatedCode, contains("  }) = _PlaceBetDto;"));
      expect(generatedCode, contains("  PlaceBetDto._();"));
      expect(generatedCode, contains("  factory PlaceBetDto.fromBorsh(Uint8List data) =>"));
      expect(generatedCode, contains("      _\$PlaceBetDtoFromBorsh(data);"));

      // ---- UpdateConfigDto (another multi-field mix)
      expect(generatedCode, contains("class UpdateConfigDto with _\$UpdateConfigDto {"));
      expect(generatedCode, contains("  factory UpdateConfigDto({"));
      expect(generatedCode, contains("    @BU64() required BigInt minBet,"));
      expect(generatedCode, contains("    @BString() required String note,"));
      expect(generatedCode, contains("  }) = _UpdateConfigDto;"));
      expect(generatedCode, contains("  UpdateConfigDto._();"));
      expect(generatedCode, contains("  factory UpdateConfigDto.fromBorsh(Uint8List data) =>"));
      expect(generatedCode, contains("      _\$UpdateConfigDtoFromBorsh(data);"));
    });
  });
}
