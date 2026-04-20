import 'dart:io';
import 'package:auto_dto/src/idl_parser.dart';
import 'package:auto_dto/src/dto_generator.dart';

void main() async {
  final idlPath = 'example/idl.json';
  final parser = IdlParser();
  final generator = DtoGenerator();

  final dtos = await parser.parse(idlPath);
  final generatedCode = generator.generate(dtos, libraryFileStem: 'idl_dto');

  // Print the generated code to the console
  print('Generated DTOs:\n$generatedCode');

  // Optionally, write to a file
  final outputFile = File('example/idl_dto.dart');
  await outputFile.writeAsString(generatedCode);
  print('\nGenerated DTOs written to ${outputFile.path}');
}
