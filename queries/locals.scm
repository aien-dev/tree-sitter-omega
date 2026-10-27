; Omega scoping (OMEGESE.md 3 rule 4): a name first written inside a block dies at its `end`;
; parameters live for the whole function.

(function_definition) @local.scope

(block) @local.scope

(function_definition
  name: (identifier) @local.definition.function)

(parameter_list
  (identifier) @local.definition.parameter)

(assignment
  name: (identifier) @local.definition.var)

(for_statement
  counter: (identifier) @local.definition.var)

(global_declaration
  name: (identifier) @local.definition.var)

(text_declaration
  name: (identifier) @local.definition.var)

(const_declaration
  name: (identifier) @local.definition.constant)

(struct_declaration
  name: (identifier) @local.definition.type)

(layout_declaration
  name: (identifier) @local.definition.type)

(abstract_declaration
  name: (identifier) @local.definition.type)

(identifier) @local.reference
