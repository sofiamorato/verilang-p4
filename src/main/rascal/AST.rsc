module AST

data Module =
  verilangModule(str name, list[Using] usings, list[Def] defs);

data Using =
  using(str name);

data Def =
    spaceDef     (str name, list[str] parent)
  | operatorDef  (str name, TypeExpr first, list[TypeExpr] rest, list[Attribute] attrs)
  | variableDef  (list[VarDecl] decls)
  | ruleDef      (RuleExpr lhs, RuleExpr rhs)
  | expressionDef(LogExpr expr);

data Attribute =
  attribute(str key, list[TypeExpr] val);

data VarDecl =
  varDecl(str varName, TypeExpr varType);

data TypeExpr =
  typeExpr(str name);

data RuleExpr =
    ruleAtom(str name)
  | ruleApp (str op, list[RuleExpr] args);

data LogExpr =
    quantified(Quantifier q)
  | binary    (LogExpr left, BinOp binOp, LogExpr right)
  | unary     (UnaryOp unaryOp, LogExpr expr)
  | atom      (str name)
  | numLit    (str n)
  | boolLit   (bool b)
  | charLit   (str c)
  | stringLit (str s);

data BinOp =
    andOp()
  | orOp()
  | eqOp()
  | impOp()
  | ltOp()
  | gtOp()
  | leOp()
  | geOp()
  | addOp()
  | subOp()
  | mulOp()
  | divOp();

data UnaryOp =
  negOp();

data Quantifier =
    forallQ(str var, TypeExpr domain, LogExpr body)
  | existsQ(str var, TypeExpr domain, LogExpr body);