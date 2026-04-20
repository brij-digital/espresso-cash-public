import 'dart:convert';
import 'dart:io';

import 'package:auto_dto/src/dto_info.dart';

class IdlParser {
  Future<List<DtoInfo>> parse(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    final dtos = <DtoInfo>[];

    // Parse accounts
    final accounts = json['accounts'] as List<dynamic>? ?? [];
    for (final account in accounts) {
      final accountMap = account as Map<String, dynamic>;
      final name = accountMap['name'] as String;
      final type = accountMap['type'] as Map<String, dynamic>;
      final kind = type['kind'] as String;

      if (kind == 'struct') {
        final fields = (type['fields'] as List<dynamic>)
            .map((field) {
              final fieldMap = field as Map<String, dynamic>;
              return FieldInfo(
                name: fieldMap['name'] as String,
                type: fieldMap['type'] as String,
              );
            })
            .toList();

        dtos.add(DtoInfo(name: name, fields: fields));
      }
    }

    // Parse instructions
    final instructions = json['instructions'] as List<dynamic>? ?? [];
    for (final instruction in instructions) {
      final instructionMap = instruction as Map<String, dynamic>;
      final instructionName = instructionMap['name'] as String;
      final args = instructionMap['args'] as List<dynamic>;

      final fields = args
          .map((arg) {
            final argMap = arg as Map<String, dynamic>;
            return FieldInfo(
              name: argMap['name'] as String,
              type: argMap['type'] as String,
            );
          })
          .toList();

      // DTO name for instruction arguments, e.g., CreatePlayerProfileArgs
      final camelCaseInstructionName = _toCamelCase(instructionName);
      final dtoName = '${camelCaseInstructionName}Dto';
      dtos.add(DtoInfo(name: dtoName, fields: fields));
    }

    return dtos;
  }

  String _toCamelCase(String snakeCase) {
    if (snakeCase.isEmpty) {
      return '';
    }
    final parts = snakeCase.split('_');
    return parts.map((part) => part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}').join();
  }
}
