import 'dart:io';

import 'package:auto_dto/src/dto_generator.dart';
import 'package:auto_dto/src/idl_parser.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run auto_dto <path_to_idl.json>');
    exit(1);
  }

  final idlPath = args.first;
  final parser = IdlParser();
  final generator = DtoGenerator();

  try {
    final dtos = await parser.parse(idlPath);
    final generatedCode = generator.generate(dtos);

    for (final dto in dtos) {
      final fileName = generator.toSnakeCase(dto.name);
      final file = File('lib/src/generated/$fileName.dart');
      await file.writeAsString(generatedCode);
    }

    print('Successfully generated DTOs!');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
