import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Identifiant unique, stable après sauvegarde.
String newId([String prefix = '']) =>
    prefix.isEmpty ? _uuid.v4() : '$prefix-${_uuid.v4()}';
