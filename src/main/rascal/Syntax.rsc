module Syntax

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r];
lexical WhitespaceAndComment = [\ \t\n\r] | @category="Comment" "#" ![\n]* $;

start syntax Module =
  verilangModule:
    "defmodule" Name name
    Using* usings
    (SpaceDef | OperatorDef | VariableDef | RuleDef | ExpressionDef)* defs
    "end";

syntax Using =
  using: "using" Name name;

syntax SpaceDef =
  spaceDef: "defspace" Name name ("\<" Name parent)? "end";

syntax OperatorDef =
  operatorDef:
    "defoperator" Name name
    ":" TypeExpr first
    ("-\>" TypeExpr)+ rest
    Attribute* attrs
    "end";

syntax Attribute =
  attribute: "[" Name key (":" TypeExpr val)? "]";

syntax VariableDef =
  variableDef: "defvar" {VarDecl ","}+ decls "end";

syntax VarDecl =
  varDecl: Name varName ":" TypeExpr varType;

syntax RuleDef =
  ruleDef:
    "defrule"
    RuleExpr lhs
    "-\>"
    RuleExpr rhs
    "end";

syntax RuleExpr =
    ruleAtom : Name name
  | ruleApp  : "(" Name op RuleExpr+ args ")";

syntax ExpressionDef =
  expressionDef: "defexpression" LogExpr expr "end";

syntax LogExpr =
    quantified : "(" Quantifier q ")"
  | binary     : "(" LogExpr left BinOp op LogExpr right ")"
  | unary      : "(" UnaryOp op LogExpr expr ")"
  | stringLit  : StringLiteral s
  | charLit    : CharLiteral c
  | numLit     : Number n
  | boolLit    : Boolean b
  | atom       : Name n;

syntax BinOp =
    andOp : "and"
  | orOp  : "or"
  | impOp : "=\>"
  | eqOp  : "="
  | leOp  : "\<="
  | geOp  : "\>="
  | ltOp  : "\<"
  | gtOp  : "\>"
  | addOp : "+"
  | subOp : "-"
  | mulOp : "*"
  | divOp : "/";

syntax UnaryOp =
  negOp: "neg";

syntax Quantifier =
    forallQ: "forall" Name var "in" TypeExpr domain "." LogExpr body
  | existsQ: "exists" Name var "in" TypeExpr domain "." LogExpr body;

syntax TypeExpr =
  typeExpr: TypeName name;

syntax Boolean =
    boolTrue  : "true"
  | boolFalse : "false";

lexical TypeName      = [a-zA-Z][a-zA-Z0-9\-]* !>> [a-zA-Z0-9\-];
lexical StringLiteral = "\"" ![\"\n]* "\"";
lexical CharLiteral   = "\'" ![\'\n] "\'";
lexical Number        = [0-9]+ ("." [0-9]+)? !>> [0-9];

keyword Reserved =
  "defmodule" | "using"          | "defspace"   |
  "defoperator"| "defexpression" | "defrule"    |
  "defvar"    | "end"            |
  "forall"    | "exists"         |
  "in"        | "and"            | "or"         |
  "true"      | "false"          |
  "neg";

lexical Name = [a-zA-Z][a-zA-Z0-9\-]* !>> [a-zA-Z0-9\-] \ Reserved;