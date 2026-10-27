/**
 * @file Omega (.om, Omegese) grammar for tree-sitter
 * @author Drake Stapleton <drake@aienos.com>
 * @license Apache-2.0 WITH LLVM-exception
 *
 * Source of truth for the language: aien-dev/omega-mv
 *   docs/one_layer/OMEGESE.md (sections 3, 9, 10, 12)
 *   seed/omc/omc.om  (fn tok / tok2 / tok_num / tok_text: the lexer; fn kw / kw2: reserved words)
 *
 * Omega is line oriented. A line holds one statement; words are separated by blanks; `(` and `)`
 * are words of their own; a text literal is one word in double quotes. Values are prefix
 * expressions whose arity comes from the words themselves (and, for calls, from the callee's
 * signature), so this grammar keeps a line's value as a flat sequence of words and gives structure
 * to the parts that are context free: blocks (`fn`/`if`/`else`/`while`/`for`/`layout` ... `end`),
 * declarations, and the statement kind a line starts with. Operator and type words are ordinary
 * identifiers here and are coloured by queries/highlights.scm, because OM-1 units may use the OM-2
 * words (`open`, `field`, `rotr`, ...) as names.
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const words = ($) => repeat1($._word);

// A block's lines: the newline that ends the header, then statement lines. The `block` node holds
// the statements (absent when the block is empty).
const block = ($, name) => seq($._sep, optional(field(name, $.block)));

export default grammar({
  name: 'omega',

  extras: ($) => [/[ \t\r]/, $.comment],

  word: ($) => $.identifier,

  rules: {
    source_file: ($) =>
      seq(
        optional($._sep),
        optional(seq($._top_level, repeat(seq($._sep, $._top_level)), optional($._sep))),
      ),

    _sep: ($) => repeat1($._newline),
    _newline: (_) => '\n',

    _top_level: ($) =>
      choice(
        $.profile,
        $.global_declaration,
        $.text_declaration,
        $.const_declaration,
        $.struct_declaration,
        $.layout_declaration,
        $.abstract_declaration,
        $.holds_declaration,
        $.function_definition,
      ),

    // `om2`, `om2 diag`, `om2 fmt`, `om2 release` ... (OMEGESE.md 9.13, 12) and the IR-mode header `ir` (11).
    profile: ($) => seq(field('name', choice('om2', 'ir')), repeat(field('option', $.identifier))),

    global_declaration: ($) => seq('global', field('name', $.identifier), words($)),
    text_declaration: ($) => seq('text', field('name', $.identifier), field('value', $.string)),
    const_declaration: ($) => seq('const', field('name', $.identifier), words($)),
    // `struct Name field type [len] ... end` is one line (OMEGESE.md 9.7).
    struct_declaration: ($) => seq('struct', field('name', $.identifier), repeat($._word), 'end'),
    abstract_declaration: ($) => seq('abstract', field('name', $.identifier), words($)),
    holds_declaration: ($) => seq('holds', field('name', $.identifier), words($)),

    // `layout NAME SIZE`, field lines, `end` (OMEGESE.md 9.13 External layout).
    layout_declaration: ($) =>
      seq(
        'layout',
        field('name', $.identifier),
        repeat($._word),
        $._sep,
        repeat(seq($.field_declaration, $._sep)),
        'end',
      ),
    field_declaration: ($) => seq('field', field('name', $.identifier), repeat($._word)),

    // `[export] fn NAME (param mode? type len?)* to TYPE [inline]` ... `end`
    function_definition: ($) =>
      seq(
        optional('export'),
        'fn',
        field('name', $.identifier),
        optional(field('parameters', $.parameter_list)),
        'to',
        field('return_type', $.return_type),
        block($, 'body'),
        'end',
      ),
    parameter_list: ($) => words($),
    return_type: ($) => words($),

    _statement: ($) =>
      choice(
        $.if_statement,
        $.while_statement,
        $.for_statement,
        $.return_statement,
        $.put_statement,
        $.trap_statement,
        $.exit_statement,
        $.break_statement,
        $.continue_statement,
        $.assignment,
        $.expression_statement,
      ),

    block: ($) => repeat1(seq($._statement, $._sep)),

    if_statement: ($) =>
      seq(
        'if',
        field('condition', $.expression),
        block($, 'consequence'),
        optional(field('alternative', $.else_clause)),
        'end',
      ),
    else_clause: ($) => seq('else', block($, 'body')),

    while_statement: ($) =>
      seq(
        'while',
        field('condition', $.expression),
        optional(seq('bound', field('bound', $._word))),
        block($, 'body'),
        'end',
      ),

    for_statement: ($) =>
      seq(
        'for',
        field('counter', $.identifier),
        field('count', $.expression),
        block($, 'body'),
        'end',
      ),

    return_statement: ($) => seq('ret', optional(field('value', $.expression))),
    put_statement: ($) => seq('put', field('arguments', $.expression)),
    trap_statement: ($) => seq('trap', field('code', $.expression)),
    exit_statement: ($) => seq('exit', field('value', $.expression)),
    break_statement: (_) => 'break',
    continue_statement: (_) => 'continue',

    assignment: ($) => seq(field('name', $.identifier), '=', field('value', $.expression)),

    // A line that is a call, an assignment written without `=`, or a contract clause
    // (`requires`/`ensures`/`invariant` are only reserved inside OM-2 units).
    expression_statement: ($) => $.expression,

    expression: ($) => words($),

    _word: ($) =>
      choice($.identifier, $.integer, $.float, $.string, $.parenthesized, $.unsized),

    parenthesized: ($) => seq('(', repeat($._word), ')'),

    // `NAME view T *`: an unsized view (OMEGESE.md 9.13 Unsized views).
    unsized: (_) => '*',

    identifier: (_) => /[A-Za-z_][A-Za-z0-9_]*/,

    // Decimal (with optional leading minus) and the OM-2 hex form `0x` + 1..16 lowercase digits.
    integer: (_) => token(choice(/-?[0-9]+/, /0x[0-9a-f]+/)),

    // `digits.digits[(e|E)[+|-]digits][f32|f64]` (OMEGESE.md 9.9); the exponent form without a dot
    // is accepted here too because omc's tok_num treats any word holding `.`, `e`, `E` or `f` as a float.
    float: (_) =>
      token(
        choice(
          /-?[0-9]+\.[0-9]+([eE][+-]?[0-9]+)?(f32|f64)?/,
          /-?[0-9]+[eE][+-]?[0-9]+(f32|f64)?/,
          /-?[0-9]+(f32|f64)/,
        ),
      ),

    // Escapes: \n \t \\ \" (others are compile error 22, still one word to the lexer). Inside text
    // the comment extra must never win: `" note "` and `"\nnote ..."` are text (omc tok_text reads to
    // the closing quote), so string_content outranks comment (prec 2 > 1) and also covers the blanks
    // that would otherwise be skipped as extras.
    string: ($) =>
      seq('"', repeat(choice($.string_content, $.escape_sequence)), token.immediate('"')),
    string_content: (_) => token.immediate(prec(2, /[^"\\\n]+/)),
    escape_sequence: (_) => token.immediate(/\\[^\n]/),

    // `note ...` is a line the compiler does not read beyond its first word (OMEGESE.md 9.5; omc
    // reads it only where a line starts, after blanks). The word is exactly `note`: omc isnote ends
    // it at a blank, a parenthesis or the end, so `notes` and `noted` are names. A bare `note` is a
    // keyword (lexed as an identifier, then matched whole against the keywords), and the longer
    // `note text` / `note(...)` token outmatches the identifier `note`.
    comment: (_) => choice('note', token(/note[ \t\r()][^\n]*/)),
  },
});
