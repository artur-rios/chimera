enum SqlDialect { postgresql, mysql, sqlServer, sqlite }

enum SqlKeywordCase { upper, lower, preserve }

extension SqlDialectValue on SqlDialect {
  String get value => switch (this) {
    SqlDialect.postgresql => 'postgresql',
    SqlDialect.mysql => 'mysql',
    SqlDialect.sqlServer => 'sqlserver',
    SqlDialect.sqlite => 'sqlite',
  };
}

extension SqlKeywordCaseValue on SqlKeywordCase {
  String get value => switch (this) {
    SqlKeywordCase.upper => 'upper',
    SqlKeywordCase.lower => 'lower',
    SqlKeywordCase.preserve => 'preserve',
  };
}

SqlDialect? parseSqlDialect(String value) => switch (value.toLowerCase()) {
  'postgresql' => SqlDialect.postgresql,
  'mysql' => SqlDialect.mysql,
  'sqlserver' => SqlDialect.sqlServer,
  'sqlite' => SqlDialect.sqlite,
  _ => null,
};

SqlKeywordCase? parseSqlKeywordCase(String value) =>
    switch (value.toLowerCase()) {
      'upper' => SqlKeywordCase.upper,
      'lower' => SqlKeywordCase.lower,
      'preserve' => SqlKeywordCase.preserve,
      _ => null,
    };

enum SqlFormatFailureKind { validation, resource }

final class SqlFormatException implements Exception {
  const SqlFormatException({
    required this.kind,
    required this.code,
    this.offset,
    this.reason,
  });

  final SqlFormatFailureKind kind;
  final String code;
  final int? offset;
  final String? reason;
}

final class SqlFormatRequest {
  const SqlFormatRequest({
    required this.source,
    required this.dialect,
    required this.indent,
    required this.keywordCase,
  });

  final String source;
  final SqlDialect dialect;
  final int indent;
  final SqlKeywordCase keywordCase;
}

final class SqlFormatResult {
  const SqlFormatResult({
    required this.formatted,
    required this.dialect,
    required this.indent,
    required this.keywordCase,
  });

  final String formatted;
  final SqlDialect dialect;
  final int indent;
  final SqlKeywordCase keywordCase;
}

final class SqlFormatter {
  const SqlFormatter({
    this.maxSourceChars = 4000000,
    this.maxTokens = 100000,
    this.maxDepth = 100,
    this.maxOutputChars = 4000000,
  }) : assert(maxSourceChars >= 0, 'maxSourceChars must not be negative'),
       assert(maxTokens >= 0, 'maxTokens must not be negative'),
       assert(maxDepth >= 0, 'maxDepth must not be negative'),
       assert(maxOutputChars >= 0, 'maxOutputChars must not be negative');

  final int maxSourceChars;
  final int maxTokens;
  final int maxDepth;
  final int maxOutputChars;

  SqlFormatResult format(SqlFormatRequest request) {
    if (request.indent != 2 && request.indent != 4) {
      throw const SqlFormatException(
        kind: SqlFormatFailureKind.validation,
        code: 'sql-format.invalid-indent',
      );
    }
    if (request.source.length > maxSourceChars) _throwResourceLimit();

    final tokens = _SqlTokenizer(
      request.source,
      dialect: request.dialect,
      maxTokens: maxTokens,
      maxDepth: maxDepth,
    ).tokenize();
    final formatted = _SqlEmitter(
      tokens,
      dialect: request.dialect,
      indent: request.indent,
      keywordCase: request.keywordCase,
      maxOutputChars: maxOutputChars,
    ).format();
    return SqlFormatResult(
      formatted: formatted,
      dialect: request.dialect,
      indent: request.indent,
      keywordCase: request.keywordCase,
    );
  }

  Never _throwResourceLimit() => throw const SqlFormatException(
    kind: SqlFormatFailureKind.resource,
    code: 'sql-format.resource-limit',
  );
}

enum _SqlTokenKind {
  word,
  number,
  string,
  identifier,
  parameter,
  operator,
  comma,
  dot,
  semicolon,
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  lineComment,
  blockComment,
}

final class _SqlToken {
  const _SqlToken(this.kind, this.lexeme, this.offset);

  final _SqlTokenKind kind;
  final String lexeme;
  final int offset;

  String get lower => lexeme.toLowerCase();
}

final class _SqlTokenizer {
  _SqlTokenizer(
    this.source, {
    required this.dialect,
    required this.maxTokens,
    required this.maxDepth,
  });

  final String source;
  final SqlDialect dialect;
  final int maxTokens;
  final int maxDepth;

  final List<_SqlToken> _tokens = <_SqlToken>[];
  var _index = 0;
  var _depth = 0;
  var _bracketDepth = 0;

  List<_SqlToken> tokenize() {
    while (_index < source.length) {
      final codeUnit = source.codeUnitAt(_index);
      if (_isWhitespace(codeUnit)) {
        _index++;
      } else if (_startsWith('--') && _isDashCommentStart()) {
        _readLineComment();
      } else if (codeUnit == 0x23 && dialect == SqlDialect.mysql) {
        _readLineComment(markerLength: 1);
      } else if (_startsWith('/*')) {
        _readBlockComment();
      } else if (_isPrefixedLiteralStart()) {
        _readPrefixedLiteral();
      } else if (codeUnit == 0x27) {
        _readDelimited(
          _SqlTokenKind.string,
          "'",
          doubledEscape: true,
          backslashEscape: dialect == SqlDialect.mysql,
        );
      } else if (codeUnit == 0x22) {
        _readDelimited(_SqlTokenKind.identifier, '"', doubledEscape: true);
      } else if (codeUnit == 0x60) {
        if (dialect == SqlDialect.postgresql) {
          _readOperator();
        } else if (dialect == SqlDialect.mysql ||
            dialect == SqlDialect.sqlite) {
          _readDelimited(_SqlTokenKind.identifier, '`', doubledEscape: true);
        } else {
          _throwInvalid('unsupported-dialect-syntax');
        }
      } else if (codeUnit == 0x5B) {
        if (dialect == SqlDialect.sqlServer || dialect == SqlDialect.sqlite) {
          _readBracketIdentifier();
        } else if (dialect == SqlDialect.postgresql) {
          _bracketDepth++;
          if (_bracketDepth > maxDepth) _throwResourceLimit();
          _add(_SqlTokenKind.leftBracket, _index, ++_index);
        } else {
          _throwInvalid('unsupported-dialect-syntax');
        }
      } else if (codeUnit == 0x5D) {
        if (dialect != SqlDialect.postgresql) {
          _throwInvalid('unexpected-character');
        }
        if (_bracketDepth == 0) {
          _throwInvalid('unexpected-closing-bracket');
        }
        _bracketDepth--;
        _add(_SqlTokenKind.rightBracket, _index, ++_index);
      } else if (codeUnit == 0x24 && dialect == SqlDialect.postgresql) {
        if (!_readPostgreSqlDollarValue()) _readWordOrParameter();
      } else if (codeUnit == 0x24 && dialect == SqlDialect.sqlite) {
        _readNamedParameter();
      } else if (codeUnit == 0x3F) {
        if (dialect == SqlDialect.sqlite || dialect == SqlDialect.mysql) {
          _readQuestionParameter();
        } else if (dialect == SqlDialect.postgresql) {
          _readOperator();
        } else {
          _throwInvalid('unsupported-dialect-syntax');
        }
      } else if (codeUnit == 0x40 || codeUnit == 0x3A) {
        if (codeUnit == 0x40 && dialect == SqlDialect.postgresql) {
          _readOperator();
        } else {
          _readNamedParameter();
        }
      } else if (codeUnit == 0x23 && dialect == SqlDialect.sqlServer) {
        _readTemporaryTable();
      } else if (codeUnit == 0x28) {
        final start = _index++;
        _depth++;
        if (_depth > maxDepth) _throwResourceLimit();
        _add(_SqlTokenKind.leftParen, start, _index);
      } else if (codeUnit == 0x29) {
        final start = _index++;
        if (_depth == 0) _throwInvalid('unexpected-closing-parenthesis', start);
        _depth--;
        _add(_SqlTokenKind.rightParen, start, _index);
      } else if (codeUnit == 0x2C) {
        _add(_SqlTokenKind.comma, _index, ++_index);
      } else if (codeUnit == 0x2E) {
        if (_index + 1 < source.length &&
            _isDigit(source.codeUnitAt(_index + 1))) {
          _readLeadingDecimalNumber();
        } else {
          _add(_SqlTokenKind.dot, _index, ++_index);
        }
      } else if (codeUnit == 0x3B) {
        _add(_SqlTokenKind.semicolon, _index, ++_index);
      } else if (_isDigit(codeUnit)) {
        _readNumber();
      } else if (_isOperator(codeUnit)) {
        _readOperator();
      } else {
        _readWordOrParameter();
      }
    }

    if (_depth != 0) {
      _throwInvalid('unclosed-parenthesis', source.length);
    }
    if (_bracketDepth != 0) {
      _throwInvalid('unclosed-bracket', source.length);
    }
    _validateStatements();
    return List<_SqlToken>.unmodifiable(_tokens);
  }

  void _readLineComment({int markerLength = 2}) {
    final start = _index;
    _index += markerLength;
    while (_index < source.length &&
        source.codeUnitAt(_index) != 0x0A &&
        source.codeUnitAt(_index) != 0x0D) {
      _index++;
    }
    _add(_SqlTokenKind.lineComment, start, _index);
  }

  void _readBlockComment() {
    final start = _index;
    _index += 2;
    var nesting = 1;
    final supportsNesting =
        dialect == SqlDialect.postgresql || dialect == SqlDialect.sqlServer;
    while (_index < source.length) {
      if (supportsNesting && _startsWith('/*')) {
        nesting++;
        if (nesting > maxDepth) _throwResourceLimit();
        _index += 2;
        continue;
      }
      if (_startsWith('*/')) {
        nesting--;
        _index += 2;
        if (nesting == 0) {
          _add(_SqlTokenKind.blockComment, start, _index);
          return;
        }
        continue;
      }
      _index++;
    }
    _throwInvalid('unterminated-comment', start);
  }

  void _readDelimited(
    _SqlTokenKind kind,
    String delimiter, {
    required bool doubledEscape,
    bool backslashEscape = false,
    int? tokenStart,
  }) {
    final start = tokenStart ?? _index;
    _index++;
    final delimiterCode = delimiter.codeUnitAt(0);
    while (_index < source.length) {
      if (backslashEscape && source.codeUnitAt(_index) == 0x5C) {
        _index++;
        if (_index < source.length) _index++;
        continue;
      }
      if (source.codeUnitAt(_index) != delimiterCode) {
        _index++;
        continue;
      }
      _index++;
      if (doubledEscape &&
          _index < source.length &&
          source.codeUnitAt(_index) == delimiterCode) {
        _index++;
        continue;
      }
      _add(kind, start, _index);
      return;
    }
    _throwInvalid('unterminated-literal', start);
  }

  bool _isPrefixedLiteralStart() {
    if (dialect == SqlDialect.postgresql &&
        _index + 2 < source.length &&
        source[_index].toLowerCase() == 'u' &&
        source.codeUnitAt(_index + 1) == 0x26 &&
        (source.codeUnitAt(_index + 2) == 0x27 ||
            source.codeUnitAt(_index + 2) == 0x22)) {
      return true;
    }
    if (dialect == SqlDialect.mysql && source.codeUnitAt(_index) == 0x5F) {
      var cursor = _index + 1;
      while (cursor < source.length &&
          _isIdentifierPart(source.codeUnitAt(cursor))) {
        cursor++;
      }
      return cursor < source.length && source.codeUnitAt(cursor) == 0x27;
    }
    if (_index + 1 >= source.length || source.codeUnitAt(_index + 1) != 0x27) {
      return false;
    }
    final prefix = source[_index].toLowerCase();
    return switch (dialect) {
      SqlDialect.postgresql => prefix == 'e' || prefix == 'b' || prefix == 'x',
      SqlDialect.mysql => prefix == 'n' || prefix == 'b' || prefix == 'x',
      SqlDialect.sqlServer => prefix == 'n',
      SqlDialect.sqlite => prefix == 'x',
    };
  }

  void _readPrefixedLiteral() {
    final start = _index;
    final unicodeEscape =
        dialect == SqlDialect.postgresql &&
        _index + 2 < source.length &&
        source[_index].toLowerCase() == 'u' &&
        source.codeUnitAt(_index + 1) == 0x26;
    if (unicodeEscape) {
      _index += 2;
    } else if (dialect == SqlDialect.mysql &&
        source.codeUnitAt(_index) == 0x5F) {
      while (_index < source.length &&
          _isIdentifierPart(source.codeUnitAt(_index))) {
        _index++;
      }
    } else {
      _index++;
    }
    final delimiter = source[_index];
    _readDelimited(
      delimiter == '"' ? _SqlTokenKind.identifier : _SqlTokenKind.string,
      delimiter,
      doubledEscape: true,
      backslashEscape:
          !unicodeEscape &&
          (dialect == SqlDialect.mysql ||
              (dialect == SqlDialect.postgresql &&
                  source[start].toLowerCase() == 'e')),
      tokenStart: start,
    );
  }

  void _readBracketIdentifier() {
    final start = _index++;
    while (_index < source.length) {
      if (source.codeUnitAt(_index) != 0x5D) {
        _index++;
        continue;
      }
      _index++;
      if (_index < source.length && source.codeUnitAt(_index) == 0x5D) {
        _index++;
        continue;
      }
      _add(_SqlTokenKind.identifier, start, _index);
      return;
    }
    _throwInvalid('unterminated-identifier', start);
  }

  bool _readPostgreSqlDollarValue() {
    final start = _index;
    var cursor = _index + 1;
    while (cursor < source.length &&
        _isDollarTagPart(source.codeUnitAt(cursor))) {
      cursor++;
    }
    if (cursor < source.length && source.codeUnitAt(cursor) == 0x24) {
      final delimiter = source.substring(start, cursor + 1);
      final close = source.indexOf(delimiter, cursor + 1);
      if (close < 0) _throwInvalid('unterminated-literal', start);
      _index = close + delimiter.length;
      _add(_SqlTokenKind.string, start, _index);
      return true;
    }
    if (cursor > start + 1 &&
        _isAllDigits(source.substring(start + 1, cursor))) {
      _index = cursor;
      _add(_SqlTokenKind.parameter, start, _index);
      return true;
    }
    return false;
  }

  void _readQuestionParameter() {
    final start = _index++;
    if (dialect == SqlDialect.sqlite) {
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }
    _add(_SqlTokenKind.parameter, start, _index);
  }

  void _readNamedParameter() {
    final start = _index;
    final marker = source.codeUnitAt(_index++);
    if (marker == 0x40 &&
        dialect != SqlDialect.mysql &&
        dialect != SqlDialect.sqlServer &&
        dialect != SqlDialect.sqlite) {
      _throwInvalid('unsupported-dialect-syntax', start);
    }
    if (marker == 0x24 && dialect != SqlDialect.sqlite) {
      _throwInvalid('unsupported-dialect-syntax', start);
    }
    if (marker == 0x40 &&
        _index < source.length &&
        source.codeUnitAt(_index) == 0x40 &&
        (dialect == SqlDialect.mysql || dialect == SqlDialect.sqlServer)) {
      _index++;
    }
    if (marker == 0x40 &&
        dialect == SqlDialect.mysql &&
        _index < source.length &&
        (source.codeUnitAt(_index) == 0x27 ||
            source.codeUnitAt(_index) == 0x22 ||
            source.codeUnitAt(_index) == 0x60)) {
      final delimiter = source[_index];
      _readDelimited(
        _SqlTokenKind.parameter,
        delimiter,
        doubledEscape: true,
        backslashEscape: true,
        tokenStart: start,
      );
      return;
    }
    if (_index >= source.length ||
        !_isIdentifierStart(source.codeUnitAt(_index))) {
      _index = start;
      _readOperator();
      return;
    }
    while (_index < source.length &&
        _isIdentifierPart(source.codeUnitAt(_index))) {
      _index++;
    }
    if (marker == 0x24 && dialect == SqlDialect.sqlite) {
      while (_index + 1 < source.length && _startsWith('::')) {
        _index += 2;
        if (_index >= source.length ||
            !_isIdentifierStart(source.codeUnitAt(_index))) {
          _throwInvalid('invalid-parameter', start);
        }
        while (_index < source.length &&
            _isIdentifierPart(source.codeUnitAt(_index))) {
          _index++;
        }
      }
      if (_index < source.length && source.codeUnitAt(_index) == 0x28) {
        _index++;
        while (_index < source.length && source.codeUnitAt(_index) != 0x29) {
          _index++;
        }
        if (_index >= source.length) {
          _throwInvalid('invalid-parameter', start);
        }
        _index++;
      }
    }
    _add(_SqlTokenKind.parameter, start, _index);
  }

  void _readTemporaryTable() {
    final start = _index++;
    if (_index < source.length && source.codeUnitAt(_index) == 0x23) {
      _index++;
    }
    if (_index >= source.length ||
        !_isIdentifierStart(source.codeUnitAt(_index))) {
      _throwInvalid('unexpected-character', start);
    }
    while (_index < source.length &&
        _isIdentifierPart(source.codeUnitAt(_index))) {
      _index++;
    }
    _add(_SqlTokenKind.identifier, start, _index);
  }

  void _readWordOrParameter() {
    final start = _index;
    if (!_isIdentifierStart(source.codeUnitAt(_index))) {
      _throwInvalid('unexpected-character');
    }
    _index++;
    while (_index < source.length &&
        _isIdentifierPart(source.codeUnitAt(_index))) {
      _index++;
    }
    _add(_SqlTokenKind.word, start, _index);
  }

  void _readNumber() {
    final start = _index++;
    if (source.codeUnitAt(start) == 0x30 &&
        _index < source.length &&
        (source.codeUnitAt(_index) == 0x78 ||
            source.codeUnitAt(_index) == 0x58)) {
      if (dialect == SqlDialect.postgresql) {
        _throwInvalid('unsupported-dialect-syntax', start);
      }
      _index++;
      final digitsStart = _index;
      while (_index < source.length && _isHexDigit(source.codeUnitAt(_index))) {
        _index++;
      }
      if (_index == digitsStart) _throwInvalid('invalid-number', start);
      _rejectNumberSuffix(start);
      _add(_SqlTokenKind.number, start, _index);
      return;
    }
    if (source.codeUnitAt(start) == 0x30 &&
        _index < source.length &&
        (source.codeUnitAt(_index) == 0x62 ||
            source.codeUnitAt(_index) == 0x42)) {
      if (dialect != SqlDialect.mysql) {
        _throwInvalid('unsupported-dialect-syntax', start);
      }
      _index++;
      final digitsStart = _index;
      while (_index < source.length &&
          (source.codeUnitAt(_index) == 0x30 ||
              source.codeUnitAt(_index) == 0x31)) {
        _index++;
      }
      if (_index == digitsStart) _throwInvalid('invalid-number', start);
      _rejectNumberSuffix(start);
      _add(_SqlTokenKind.number, start, _index);
      return;
    }
    while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
      _index++;
    }
    if (_index < source.length && source.codeUnitAt(_index) == 0x2E) {
      _index++;
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }
    if (_index < source.length &&
        (source.codeUnitAt(_index) == 0x65 ||
            source.codeUnitAt(_index) == 0x45)) {
      _index++;
      if (_index < source.length &&
          (source.codeUnitAt(_index) == 0x2B ||
              source.codeUnitAt(_index) == 0x2D)) {
        _index++;
      }
      if (_index >= source.length || !_isDigit(source.codeUnitAt(_index))) {
        _throwInvalid('invalid-number');
      }
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }
    _rejectNumberSuffix(start);
    _add(_SqlTokenKind.number, start, _index);
  }

  void _readLeadingDecimalNumber() {
    final start = _index++;
    while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
      _index++;
    }
    _readExponentIfPresent();
    _rejectNumberSuffix(start);
    _add(_SqlTokenKind.number, start, _index);
  }

  void _readExponentIfPresent() {
    if (_index >= source.length ||
        (source.codeUnitAt(_index) != 0x65 &&
            source.codeUnitAt(_index) != 0x45)) {
      return;
    }
    _index++;
    if (_index < source.length &&
        (source.codeUnitAt(_index) == 0x2B ||
            source.codeUnitAt(_index) == 0x2D)) {
      _index++;
    }
    if (_index >= source.length || !_isDigit(source.codeUnitAt(_index))) {
      _throwInvalid('invalid-number');
    }
    while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
      _index++;
    }
  }

  void _rejectNumberSuffix(int start) {
    if (_index < source.length &&
        _isIdentifierPart(source.codeUnitAt(_index))) {
      _throwInvalid('invalid-number', start);
    }
  }

  void _readOperator() {
    final start = _index++;
    if (dialect == SqlDialect.mysql &&
        source.codeUnitAt(start) == 0x2D &&
        _index < source.length &&
        source.codeUnitAt(_index) == 0x2D) {
      _add(_SqlTokenKind.operator, start, _index);
      return;
    }
    if (dialect == SqlDialect.postgresql) {
      while (_index < source.length &&
          _isPostgreSqlOperator(source.codeUnitAt(_index)) &&
          !_startsWith('/*') &&
          !_startsWith('--')) {
        _index++;
      }
    } else {
      final operators = switch (dialect) {
        SqlDialect.mysql => _mysqlOperators,
        SqlDialect.sqlServer => _sqlServerOperators,
        SqlDialect.sqlite => _sqliteOperators,
        SqlDialect.postgresql => const <String>[],
      };
      for (final operator in operators) {
        if (source.startsWith(operator, start)) {
          _index = start + operator.length;
          break;
        }
      }
    }
    _add(_SqlTokenKind.operator, start, _index);
  }

  void _validateStatements() {
    final significant = _tokens
        .where(
          (token) =>
              token.kind != _SqlTokenKind.lineComment &&
              token.kind != _SqlTokenKind.blockComment,
        )
        .toList(growable: false);
    var expectingStart = true;
    var foundStatement = false;
    for (var index = 0; index < significant.length; index++) {
      final token = significant[index];
      if (token.kind == _SqlTokenKind.semicolon) {
        expectingStart = true;
        continue;
      }
      if (!expectingStart) continue;
      if (token.kind != _SqlTokenKind.word ||
          !_supportedStatements.contains(token.lower)) {
        _throwInvalid('unsupported-statement', token.offset);
      }
      _validateStatementHead(significant, index);
      foundStatement = true;
      expectingStart = false;
    }
    if (!foundStatement) _throwInvalid('empty-input', 0);

    for (var index = 0; index < significant.length; index++) {
      final token = significant[index];
      final next = index + 1 < significant.length
          ? significant[index + 1]
          : null;
      final previous = index > 0 ? significant[index - 1] : null;

      if (token.kind == _SqlTokenKind.word && token.lower == 'select') {
        final postgreSqlEmptyTarget =
            dialect == SqlDialect.postgresql &&
            (next == null ||
                next.kind == _SqlTokenKind.semicolon ||
                (next.kind == _SqlTokenKind.word &&
                    _expressionStoppingClauses.contains(next.lower)));
        if (!postgreSqlEmptyTarget &&
            (!_isExpressionStart(next) ||
                (next!.kind == _SqlTokenKind.word &&
                    _expressionStoppingClauses.contains(next.lower)))) {
          _throwInvalid('missing-expression', next?.offset ?? token.offset);
        }
      }

      if (token.kind == _SqlTokenKind.word &&
          _relationClauses.contains(token.lower)) {
        if (!_isRelationStart(next)) {
          _throwInvalid('missing-relation', next?.offset ?? token.offset);
        }
        if (previous != null &&
            ((previous.kind == _SqlTokenKind.operator &&
                    previous.lexeme != '*') ||
                previous.kind == _SqlTokenKind.comma ||
                previous.kind == _SqlTokenKind.dot ||
                previous.kind == _SqlTokenKind.leftParen)) {
          _throwInvalid('missing-expression', token.offset);
        }
      }

      if (token.kind == _SqlTokenKind.semicolon ||
          index == significant.length - 1) {
        final last = token.kind == _SqlTokenKind.semicolon ? previous : token;
        if (last != null && _isIncompleteEnding(last)) {
          _throwInvalid('incomplete-statement', last.offset);
        }
      }
    }
  }

  void _validateStatementHead(List<_SqlToken> tokens, int index) {
    final statement = tokens[index];
    final next = index + 1 < tokens.length ? tokens[index + 1] : null;
    if (dialect == SqlDialect.postgresql && statement.lower == 'select') {
      return;
    }
    if (next == null || next.kind == _SqlTokenKind.semicolon) {
      _throwInvalid('incomplete-statement', statement.offset);
    }
    if (statement.lower == 'update' &&
        (!_isRelationStart(next) ||
            (next.kind == _SqlTokenKind.word &&
                _updateTargetStoppingWords.contains(next.lower)))) {
      _throwInvalid('missing-relation', next.offset);
    }
  }

  bool _isExpressionStart(_SqlToken? token) {
    if (token == null) return false;
    return switch (token.kind) {
      _SqlTokenKind.word ||
      _SqlTokenKind.number ||
      _SqlTokenKind.string ||
      _SqlTokenKind.identifier ||
      _SqlTokenKind.parameter ||
      _SqlTokenKind.leftParen => true,
      _SqlTokenKind.operator =>
        token.lexeme == '*' ||
            token.lexeme == '+' ||
            token.lexeme == '-' ||
            token.lexeme == '~' ||
            token.lexeme == '!',
      _ => false,
    };
  }

  bool _isRelationStart(_SqlToken? token) {
    if (token == null) return false;
    return token.kind == _SqlTokenKind.word ||
        token.kind == _SqlTokenKind.identifier ||
        token.kind == _SqlTokenKind.parameter ||
        token.kind == _SqlTokenKind.leftParen;
  }

  bool _isIncompleteEnding(_SqlToken token) =>
      token.kind == _SqlTokenKind.operator ||
      token.kind == _SqlTokenKind.comma ||
      token.kind == _SqlTokenKind.dot ||
      token.kind == _SqlTokenKind.leftParen ||
      (token.kind == _SqlTokenKind.word &&
          _incompleteEndingWords.contains(token.lower));

  void _add(_SqlTokenKind kind, int start, int end) {
    if (_tokens.length >= maxTokens) _throwResourceLimit();
    _tokens.add(_SqlToken(kind, source.substring(start, end), start));
  }

  bool _startsWith(String value) => source.startsWith(value, _index);

  bool _isDashCommentStart() {
    if (dialect != SqlDialect.mysql) return true;
    final afterMarker = _index + 2;
    return afterMarker >= source.length ||
        source.codeUnitAt(afterMarker) <= 0x20;
  }

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D;

  bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  bool _isHexDigit(int codeUnit) =>
      _isDigit(codeUnit) ||
      (codeUnit >= 0x41 && codeUnit <= 0x46) ||
      (codeUnit >= 0x61 && codeUnit <= 0x66);

  bool _isIdentifierStart(int codeUnit) =>
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F ||
      codeUnit > 0x7F;

  bool _isIdentifierPart(int codeUnit) =>
      _isIdentifierStart(codeUnit) || _isDigit(codeUnit) || codeUnit == 0x24;

  bool _isDollarTagPart(int codeUnit) =>
      _isIdentifierStart(codeUnit) || _isDigit(codeUnit);

  bool _isOperator(int codeUnit) => const <int>{
    0x2B,
    0x2D,
    0x2A,
    0x2F,
    0x25,
    0x3D,
    0x3C,
    0x3E,
    0x21,
    0x7C,
    0x26,
    0x5E,
    0x7E,
    0x3A,
    0x3F,
    0x40,
    0x23,
    0x60,
  }.contains(codeUnit);

  bool _isPostgreSqlOperator(int codeUnit) => const <int>{
    0x2B,
    0x2D,
    0x2A,
    0x2F,
    0x25,
    0x3D,
    0x3C,
    0x3E,
    0x21,
    0x7C,
    0x26,
    0x5E,
    0x7E,
    0x3A,
    0x3F,
    0x40,
    0x23,
    0x60,
  }.contains(codeUnit);

  bool _isAllDigits(String value) {
    for (final codeUnit in value.codeUnits) {
      if (!_isDigit(codeUnit)) return false;
    }
    return value.isNotEmpty;
  }

  Never _throwInvalid(String reason, [int? offset]) => throw SqlFormatException(
    kind: SqlFormatFailureKind.validation,
    code: 'sql-format.invalid-sql',
    offset: offset ?? _index,
    reason: reason,
  );

  Never _throwResourceLimit() => throw const SqlFormatException(
    kind: SqlFormatFailureKind.resource,
    code: 'sql-format.resource-limit',
  );
}

final class _SqlEmitter {
  _SqlEmitter(
    this.tokens, {
    required SqlDialect dialect,
    required this.indent,
    required this.keywordCase,
    required int maxOutputChars,
  }) : _keywords = _keywordsFor(dialect),
       _sink = _BoundedSqlSink(maxOutputChars);

  final List<_SqlToken> tokens;
  final int indent;
  final SqlKeywordCase keywordCase;
  final Set<String> _keywords;
  final _BoundedSqlSink _sink;

  final Set<int> _commaBreakDepths = <int>{};
  final Set<int> _conditionDepths = <int>{};
  final Set<int> _multilineParentheses = <int>{};
  var _depth = 0;
  var _atLineStart = true;
  var _pendingIndent = 0;
  _SqlToken? _previous;

  String format() {
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final consumed = _writeClause(index);
      if (consumed > 0) {
        index += consumed - 1;
        continue;
      }
      _writeToken(token, index);
    }
    return _sink.toString();
  }

  int _writeClause(int index) {
    final token = tokens[index];
    if (token.kind != _SqlTokenKind.word) return 0;
    final word = token.lower;

    final phrase = _compoundClause(index);
    if (phrase != null) {
      final (length, category) = phrase;
      _writeClauseText(index, length, category);
      return length;
    }

    if (word == 'select') {
      _line(_depth);
      _append(_keyword(token));
      if (index + 1 < tokens.length &&
          tokens[index + 1].kind != _SqlTokenKind.semicolon) {
        _line(_depth + 1);
      }
      _commaBreakDepths.add(_depth);
      _conditionDepths.remove(_depth);
      _previous = token;
      return 1;
    }
    if (word == 'from') {
      _line(_depth);
      _append(_keyword(token));
      _commaBreakDepths.remove(_depth);
      _conditionDepths.remove(_depth);
      _previous = token;
      return 1;
    }
    if (word == 'where' || word == 'having' || word == 'on') {
      _line(_depth);
      _append(_keyword(token));
      _commaBreakDepths.remove(_depth);
      _conditionDepths.add(_depth);
      _previous = token;
      return 1;
    }
    if (word == 'and' || word == 'or') {
      if (_conditionDepths.contains(_depth)) _line(_depth + 1);
      _writeOrdinary(token);
      _previous = token;
      return 1;
    }
    if (_singleLineClauses.contains(word)) {
      _line(_depth);
      _append(_keyword(token));
      _conditionDepths.remove(_depth);
      if (word == 'set' || word == 'values' || word == 'returning') {
        _commaBreakDepths.add(_depth);
      } else {
        _commaBreakDepths.remove(_depth);
      }
      _previous = token;
      return 1;
    }
    return 0;
  }

  (int, _ClauseCategory)? _compoundClause(int index) {
    final first = tokens[index].lower;
    final second = _wordAt(index + 1);
    final third = _wordAt(index + 2);
    if ((first == 'order' || first == 'group' || first == 'partition') &&
        second == 'by') {
      return (2, _ClauseCategory.list);
    }
    if ((first == 'insert' && second == 'into') ||
        (first == 'delete' && second == 'from')) {
      return (2, _ClauseCategory.standard);
    }
    if ((first == 'left' ||
            first == 'right' ||
            first == 'full' ||
            first == 'inner' ||
            first == 'cross') &&
        second == 'join') {
      return (2, _ClauseCategory.standard);
    }
    if (first == 'union' && second == 'all') {
      return (2, _ClauseCategory.standard);
    }
    if (first == 'on' && second == 'conflict') {
      return (2, _ClauseCategory.standard);
    }
    if (first == 'on' &&
        second == 'duplicate' &&
        third == 'key' &&
        _wordAt(index + 3) == 'update') {
      return (4, _ClauseCategory.list);
    }
    return null;
  }

  void _writeClauseText(int index, int length, _ClauseCategory category) {
    _line(_depth);
    for (var offset = 0; offset < length; offset++) {
      if (offset > 0) _space();
      _append(_keyword(tokens[index + offset]));
    }
    _conditionDepths.remove(_depth);
    if (category == _ClauseCategory.list) {
      _commaBreakDepths.add(_depth);
    } else {
      _commaBreakDepths.remove(_depth);
    }
    _previous = tokens[index + length - 1];
  }

  void _writeToken(_SqlToken token, int index) {
    switch (token.kind) {
      case _SqlTokenKind.comma:
        _append(',');
        if (_commaBreakDepths.contains(_depth)) {
          _line(_depth + 1);
        } else {
          _space();
        }
      case _SqlTokenKind.dot:
        _append('.');
      case _SqlTokenKind.semicolon:
        _append(';');
        _commaBreakDepths.remove(_depth);
        _conditionDepths.remove(_depth);
        if (index + 1 < tokens.length) _line(0);
      case _SqlTokenKind.leftParen:
        _writeLeftParenthesis(index);
      case _SqlTokenKind.rightParen:
        _writeRightParenthesis();
      case _SqlTokenKind.leftBracket:
        _append('[');
      case _SqlTokenKind.rightBracket:
        _append(']');
      case _SqlTokenKind.operator:
        _writeOperator(token, index);
      case _SqlTokenKind.lineComment:
        _space();
        _append(token.lexeme);
        if (index + 1 < tokens.length) _line(_depth);
      case _SqlTokenKind.blockComment:
        _space();
        _append(token.lexeme);
        _space();
      case _SqlTokenKind.word:
      case _SqlTokenKind.number:
      case _SqlTokenKind.string:
      case _SqlTokenKind.identifier:
      case _SqlTokenKind.parameter:
        _writeOrdinary(token);
    }
    _previous = token;
  }

  void _writeLeftParenthesis(int index) {
    final previous = _previous;
    final functionCall =
        previous != null &&
        (previous.kind == _SqlTokenKind.word ||
            previous.kind == _SqlTokenKind.identifier) &&
        !_keywords.contains(previous.lower);
    if (!functionCall && previous != null) _space();
    _append('(');
    _depth++;
    final next = _wordAt(index + 1);
    if (next == 'select' || next == 'with') {
      _multilineParentheses.add(_depth);
      _line(_depth);
    }
  }

  void _writeRightParenthesis() {
    if (_multilineParentheses.remove(_depth)) _line(_depth);
    _depth--;
    _append(')');
    _commaBreakDepths.remove(_depth + 1);
    _conditionDepths.remove(_depth + 1);
  }

  void _writeOperator(_SqlToken token, int index) {
    if (token.lexeme == '::') {
      _append(token.lexeme);
      return;
    }
    if (token.lexeme == '*' &&
        (_previous?.kind == _SqlTokenKind.leftParen) &&
        index + 1 < tokens.length &&
        tokens[index + 1].kind == _SqlTokenKind.rightParen) {
      _append('*');
      return;
    }
    _space();
    _append(token.lexeme);
    _space();
  }

  void _writeOrdinary(_SqlToken token) {
    final previous = _previous;
    final noSpace =
        previous == null ||
        previous.kind == _SqlTokenKind.leftParen ||
        previous.kind == _SqlTokenKind.leftBracket ||
        previous.kind == _SqlTokenKind.dot ||
        (previous.kind == _SqlTokenKind.operator && previous.lexeme == '::');
    if (!noSpace) _space();
    _append(
      token.kind == _SqlTokenKind.word && _keywords.contains(token.lower)
          ? _keyword(token)
          : token.lexeme,
    );
  }

  String _keyword(_SqlToken token) => switch (keywordCase) {
    SqlKeywordCase.upper => token.lexeme.toUpperCase(),
    SqlKeywordCase.lower => token.lexeme.toLowerCase(),
    SqlKeywordCase.preserve => token.lexeme,
  };

  String? _wordAt(int index) {
    if (index >= tokens.length || tokens[index].kind != _SqlTokenKind.word) {
      return null;
    }
    return tokens[index].lower;
  }

  void _line(int indentLevel) {
    if (!_atLineStart) {
      _sink.write('\n');
      _atLineStart = true;
    }
    _pendingIndent = indentLevel;
    _previous = null;
  }

  void _space() {
    if (_atLineStart || _sink.endsWithWhitespace) return;
    _sink.write(' ');
  }

  void _append(String value) {
    if (_atLineStart) {
      _sink.write(' ' * (_pendingIndent * indent));
      _atLineStart = false;
    }
    _sink.write(value);
  }
}

enum _ClauseCategory { standard, list }

final class _BoundedSqlSink {
  _BoundedSqlSink(this.maximumLength);

  final int maximumLength;
  final _buffer = StringBuffer();
  var _length = 0;
  var _lastCodeUnit = -1;

  bool get endsWithWhitespace =>
      _lastCodeUnit == 0x20 || _lastCodeUnit == 0x0A || _lastCodeUnit == 0x0D;

  void write(String value) {
    if (_length + value.length > maximumLength) {
      throw const SqlFormatException(
        kind: SqlFormatFailureKind.resource,
        code: 'sql-format.resource-limit',
      );
    }
    _length += value.length;
    if (value.isNotEmpty) _lastCodeUnit = value.codeUnitAt(value.length - 1);
    _buffer.write(value);
  }

  @override
  String toString() => _buffer.toString();
}

const _supportedStatements = <String>{
  'with',
  'select',
  'insert',
  'update',
  'delete',
  'merge',
  'create',
  'alter',
  'drop',
  'truncate',
};

const _singleLineClauses = <String>{
  'update',
  'set',
  'values',
  'returning',
  'limit',
  'offset',
  'fetch',
  'join',
  'union',
  'except',
  'intersect',
};

final _commonKeywords = <String>{
  ..._supportedStatements,
  ..._singleLineClauses,
  'add',
  'after',
  'all',
  'always',
  'and',
  'any',
  'as',
  'asc',
  'before',
  'begin',
  'between',
  'bigint',
  'binary',
  'boolean',
  'by',
  'case',
  'cast',
  'char',
  'check',
  'column',
  'commit',
  'conflict',
  'constraint',
  'cross',
  'current',
  'date',
  'day',
  'decimal',
  'default',
  'desc',
  'distinct',
  'double',
  'duplicate',
  'else',
  'end',
  'escape',
  'exists',
  'foreign',
  'false',
  'first',
  'following',
  'for',
  'from',
  'full',
  'generated',
  'group',
  'having',
  'in',
  'index',
  'inner',
  'insert',
  'instead',
  'integer',
  'interval',
  'into',
  'is',
  'key',
  'last',
  'left',
  'like',
  'match',
  'materialized',
  'month',
  'natural',
  'numeric',
  'not',
  'null',
  'nulls',
  'on',
  'or',
  'order',
  'outer',
  'over',
  'partition',
  'preceding',
  'precision',
  'primary',
  'real',
  'references',
  'recursive',
  'release',
  'rename',
  'replace',
  'restrict',
  'right',
  'rollback',
  'rows',
  'savepoint',
  'schema',
  'select',
  'smallint',
  'some',
  'stored',
  'then',
  'table',
  'temporary',
  'text',
  'time',
  'timestamp',
  'top',
  'true',
  'unbounded',
  'unique',
  'using',
  'varchar',
  'view',
  'virtual',
  'when',
  'where',
  'with',
  'year',
};

const _postgresqlKeywords = <String>{
  'bigserial',
  'bytea',
  'citext',
  'ilike',
  'inet',
  'json',
  'jsonb',
  'serial',
  'tsvector',
  'uuid',
};

const _mysqlKeywords = <String>{
  'auto_increment',
  'datetime',
  'engine',
  'longtext',
  'mediumint',
  'tinyint',
  'unsigned',
};

const _sqlServerKeywords = <String>{
  'bit',
  'datetime2',
  'datetimeoffset',
  'identity',
  'nchar',
  'nvarchar',
  'uniqueidentifier',
  'varbinary',
};

const _sqliteKeywords = <String>{
  'any',
  'autoincrement',
  'blob',
  'clob',
  'pragma',
  'strict',
  'without',
};

Set<String> _keywordsFor(SqlDialect dialect) => <String>{
  ..._commonKeywords,
  ...switch (dialect) {
    SqlDialect.postgresql => _postgresqlKeywords,
    SqlDialect.mysql => _mysqlKeywords,
    SqlDialect.sqlServer => _sqlServerKeywords,
    SqlDialect.sqlite => _sqliteKeywords,
  },
};

const _expressionStoppingClauses = <String>{
  'from',
  'where',
  'group',
  'order',
  'having',
  'limit',
  'offset',
  'fetch',
  'union',
  'except',
  'intersect',
};

const _relationClauses = <String>{'from', 'into', 'join'};

const _updateTargetStoppingWords = <String>{'set', 'where', 'returning'};

const _incompleteEndingWords = <String>{
  'from',
  'into',
  'join',
  'on',
  'set',
  'values',
  'where',
  'having',
  'by',
};

const _mysqlOperators = <String>[
  '<=>',
  '->>',
  '!=',
  '&&',
  ':=',
  '<<',
  '<=',
  '<>',
  '>=',
  '>>',
  '->',
  '||',
];

const _sqlServerOperators = <String>[
  '!=',
  '!<',
  '!>',
  '%=',
  '&=',
  '*=',
  '+=',
  '-=',
  '/=',
  '<=',
  '<>',
  '>=',
  '^=',
  '|=',
];

const _sqliteOperators = <String>[
  '->>',
  '!=',
  '<<',
  '<=',
  '<>',
  '==',
  '>=',
  '>>',
  '->',
  '||',
];
