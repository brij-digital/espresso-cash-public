import 'package:auto_dto/src/dto_info.dart';

class DtoGenerator {
  String generate(List<DtoInfo> dtos, {String? libraryFileStem}) {
    final buffer = StringBuffer();

    // --- header once ---
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'package:borsh_annotation/borsh_annotation.dart';");
    buffer.writeln("import 'package:solana/solana.dart';");
    buffer.writeln("import 'package:solana/src/borsh_ext.dart';");
    // If you emit public keys later, also add:
    // buffer.writeln("import 'package:solana/solana.dart';");
    buffer.writeln('');
    final partStem = libraryFileStem ?? toSnakeCase(dtos.first.name);
    buffer.writeln("part '$partStem.g.dart';");
    buffer.writeln('');

    for (final dto in dtos) {
      buffer.writeln('@BorshSerializable()');
      buffer.writeln('class ${dto.name} with _\$${dto.name} {');
      buffer.writeln('  factory ${dto.name}({');

      for (final field in dto.fields) {
        final anno = _mapBorshAnno(field.type); // e.g. @BBool(), @BString()
        final dart = _mapDartType(field.type);
        if (anno == null || dart == null) {
          throw UnsupportedError('Unsupported type: ${field.type} in ${dto.name}.${field.name}');
        }
        buffer.writeln('    $anno required $dart ${field.name},');
      }

      // Freezed-style private impl name
      buffer.writeln('  }) = _${dto.name};');
      buffer.writeln('');
      buffer.writeln('  ${dto.name}._();');
      buffer.writeln('');
      buffer.writeln('  factory ${dto.name}.fromBorsh(Uint8List data) =>');
      buffer.writeln('      _\$${dto.name}FromBorsh(data);');
      buffer.writeln('}');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  // Return full annotation token or null if unsupported
  String? _mapBorshAnno(String type) {
    switch (type) {
      case 'string': return '@BString()';
      case 'bool':   return '@BBool()';
      case 'u8':     return '@BU8()';
      case 'u16':    return '@BU16()';
      case 'u32':    return '@BU32()';
      case 'u64':    return '@BU64()';
      case 'publicKey': return '@BPublicKey()';
      default:       return null;
    }
  }

  // Return Dart type token or null if unsupported
  String? _mapDartType(String type) {
    switch (type) {
      case 'string': return 'String';
      case 'bool':   return 'bool';
      case 'u8':
      case 'u16':
      case 'u32':    return 'int';    
      case 'u64':
      case 'u128':   return 'BigInt';
      case 'publicKey': return 'Ed25519HDPublicKey';
      default:       return null;
    }
  }

  // If you need snake_case for per-file generation
  String toSnakeCase(String name) {
    final exp = RegExp(r'(?<=[a-z0-9])[A-Z]');
    return name.replaceAllMapped(exp, (m) => '_${m.group(0)}').toLowerCase();
  }
}
