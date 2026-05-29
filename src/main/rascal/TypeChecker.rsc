module TypeChecker

import AST;
import IO;
import String;

data TypeError =
    undeclaredOperator(str name)
  | undeclaredVariable(str name)
  | undeclaredSpace   (str name)
  | unknownElement    (str elementName, str context)
  | typeMismatch      (str expectedType, str actualType, str context)
  | arityMismatch     (str operatorName, int expectedCount, int actualCount)
  | invalidRule       (str message);

data OperatorSig = operatorSig(list[str] args, str result);

alias VarEnv = map[str, str];
alias OpEnv  = map[str, OperatorSig];
alias Spaces = set[str];

data CheckContext = checkContext(VarEnv vars, OpEnv ops, Spaces spaces);

set[str] primitiveTypes = {"Int", "Bool", "Char", "String"};

int lenStrList(list[str] xs) {
  int n = 0;
  for (str x <- xs) {
    n += 1;
  }
  return n;
}

int lenRuleExprList(list[RuleExpr] xs) {
  int n = 0;
  for (RuleExpr x <- xs) {
    n += 1;
  }
  return n;
}

int lenTypeErrorList(list[TypeError] xs) {
  int n = 0;
  for (TypeError x <- xs) {
    n += 1;
  }
  return n;
}

str typeToStr(TypeExpr t) {
  switch (t) {
    case typeExpr(n): {
      return n;
    }
    default: {
      return "Unknown";
    }
  }
}

bool isValidType(str t, Spaces spaces) {
  return t in primitiveTypes || t in spaces;
}

OperatorSig operatorSignature(TypeExpr first, list[TypeExpr] rest) {
  list[str] args = [];
  str current = typeToStr(first);

  for (TypeExpr t <- rest) {
    args = args + [current];
    current = typeToStr(t);
  }

  return operatorSig(args, current);
}

list[str] signatureAllTypes(TypeExpr first, list[TypeExpr] rest) {
  list[str] types = [typeToStr(first)];

  for (TypeExpr t <- rest) {
    types = types + [typeToStr(t)];
  }

  return types;
}

CheckContext collectContext(list[Def] defs) {
  VarEnv vars = ();
  OpEnv ops = ();
  Spaces spaces = {};

  for (Def d <- defs) {
    switch (d) {
      case spaceDef(name, _): {
        spaces += {name};
      }

      default: {
        ;
      }
    }
  }

  for (Def d <- defs) {
    switch (d) {
      case variableDef(decls): {
        for (VarDecl v <- decls) {
          switch (v) {
            case varDecl(vname, vtype): {
              vars[vname] = typeToStr(vtype);
            }
          }
        }
      }

      case operatorDef(name, first, rest, _): {
        ops[name] = operatorSignature(first, rest);
      }

      default: {
        ;
      }
    }
  }

  return checkContext(vars, ops, spaces);
}

list[TypeError] checkModule(Module m) {
  list[TypeError] errors = [];

  switch (m) {
    case verilangModule(_, _, defs): {
      CheckContext ctx = collectContext(defs);

      errors = errors + checkContextDefinitions(defs, ctx);

      for (Def d <- defs) {
        errors = errors + checkDef(d, ctx);
      }
    }
  }

  return errors;
}

list[TypeError] checkContextDefinitions(list[Def] defs, CheckContext ctx) {
  list[TypeError] errors = [];

  switch (ctx) {
    case checkContext(_, _, spaces): {
      for (Def d <- defs) {
        switch (d) {
          case spaceDef(_, parent): {
            for (str p <- parent) {
              if (p notin spaces) {
                errors = errors + [undeclaredSpace(p)];
              }
            }
          }

          case operatorDef(opName, first, rest, _): {
            list[str] types = signatureAllTypes(first, rest);

            for (str t <- types) {
              if (!isValidType(t, spaces)) {
                errors = errors + [typeMismatch("declared type", t, "defoperator " + opName)];
              }
            }
          }

          default: {
            ;
          }
        }
      }
    }
  }

  return errors;
}

list[TypeError] checkDef(Def d, CheckContext ctx) {
  list[TypeError] errors = [];

  switch (d) {
    case variableDef(decls): {
      switch (ctx) {
        case checkContext(_, _, spaces): {
          for (VarDecl v <- decls) {
            switch (v) {
              case varDecl(_, vtype): {
                str t = typeToStr(vtype);

                if (!isValidType(t, spaces)) {
                  errors = errors + [undeclaredSpace(t)];
                }
              }
            }
          }
        }
      }
    }

    case ruleDef(lhs, rhs): {
      tuple[str, list[TypeError]] lt = inferRuleExpr(lhs, ctx);
      tuple[str, list[TypeError]] rt = inferRuleExpr(rhs, ctx);

      errors = errors + lt[1];
      errors = errors + rt[1];

      if (lt[0] != "Unknown" && rt[0] != "Unknown" && lt[0] != rt[0]) {
        errors = errors + [typeMismatch(lt[0], rt[0], "defrule")];
      }
    }

    case expressionDef(expr): {
      tuple[str, list[TypeError]] t = inferLogExpr(expr, ctx);

      errors = errors + t[1];

      if (t[0] != "Unknown" && t[0] != "Bool") {
        errors = errors + [typeMismatch("Bool", t[0], "defexpression")];
      }
    }

    default: {
      ;
    }
  }

  return errors;
}

tuple[str, list[TypeError]] inferRuleExpr(RuleExpr e, CheckContext ctx) {
  list[TypeError] errors = [];

  switch (ctx) {
    case checkContext(vars, ops, _): {
      switch (e) {
        case ruleAtom(name): {
          if (name in vars) {
            return <vars[name], []>;
          }

          if (name in ops) {
            switch (ops[name]) {
              case operatorSig(_, result): {
                return <result, []>;
              }
            }
          }

          return <"Unknown", [unknownElement(name, "defrule")]>;
        }

        case ruleApp(op, args): {
          if (op notin ops) {
            return <"Unknown", [undeclaredOperator(op)]>;
          }

          OperatorSig sig = ops[op];
          list[str] expected = [];
          str result = "Unknown";

          switch (sig) {
            case operatorSig(a, r): {
              expected = a;
              result = r;
            }
          }

          int expectedSize = lenStrList(expected);
          int actualSize = lenRuleExprList(args);

          if (actualSize != expectedSize) {
            errors = errors + [arityMismatch(op, expectedSize, actualSize)];
          }

          int limit = actualSize < expectedSize ? actualSize : expectedSize;
          int i = 0;

          while (i < limit) {
            tuple[str, list[TypeError]] actual = inferRuleExpr(args[i], ctx);

            errors = errors + actual[1];

            if (actual[0] != "Unknown" && actual[0] != expected[i]) {
              str argNumber = "<i + 1>";
              str context = "argument " + argNumber + " of " + op;
              errors = errors + [typeMismatch(expected[i], actual[0], context)];
            }

            i += 1;
          }

          return <result, errors>;
        }
      }
    }
  }

  return <"Unknown", errors>;
}

tuple[str, list[TypeError]] inferLogExpr(LogExpr e, CheckContext ctx) {
  list[TypeError] errors = [];

  switch (ctx) {
    case checkContext(vars, ops, spaces): {
      switch (e) {
        case atom(name): {
          if (name in vars) {
            return <vars[name], []>;
          }

          return <"Unknown", [undeclaredVariable(name)]>;
        }

        case numLit(_): {
          return <"Int", []>;
        }

        case charLit(_): {
          return <"Char", []>;
        }

        case stringLit(_): {
          return <"String", []>;
        }

        case boolLit(_): {
          return <"Bool", []>;
        }

        case unary(_, expr): {
          tuple[str, list[TypeError]] t = inferLogExpr(expr, ctx);

          errors = errors + t[1];

          if (t[0] != "Unknown" && t[0] != "Bool") {
            errors = errors + [typeMismatch("Bool", t[0], "neg")];
          }

          return <"Bool", errors>;
        }

        case binary(left, op, right): {
          tuple[str, list[TypeError]] l = inferLogExpr(left, ctx);
          tuple[str, list[TypeError]] r = inferLogExpr(right, ctx);

          errors = errors + l[1];
          errors = errors + r[1];

          switch (op) {
            case andOp(): {
              return checkBinaryBool("and", l[0], r[0], errors);
            }

            case orOp(): {
              return checkBinaryBool("or", l[0], r[0], errors);
            }

            case impOp(): {
              return checkBinaryBool("implication", l[0], r[0], errors);
            }

            case eqOp(): {
              if (l[0] != "Unknown" && r[0] != "Unknown" && l[0] != r[0]) {
                errors = errors + [typeMismatch(l[0], r[0], "equality")];
              }

              return <"Bool", errors>;
            }

            case ltOp(): {
              return checkBinaryInt("less-than", l[0], r[0], errors, "Bool");
            }

            case gtOp(): {
              return checkBinaryInt("greater-than", l[0], r[0], errors, "Bool");
            }

            case leOp(): {
              return checkBinaryInt("less-equal", l[0], r[0], errors, "Bool");
            }

            case geOp(): {
              return checkBinaryInt("greater-equal", l[0], r[0], errors, "Bool");
            }

            case addOp(): {
              return checkBinaryInt("addition", l[0], r[0], errors, "Int");
            }

            case subOp(): {
              return checkBinaryInt("subtraction", l[0], r[0], errors, "Int");
            }

            case mulOp(): {
              return checkBinaryInt("multiplication", l[0], r[0], errors, "Int");
            }

            case divOp(): {
              return checkBinaryInt("division", l[0], r[0], errors, "Int");
            }
          }
        }

        case quantified(q): {
          switch (q) {
            case forallQ(var, domain, body): {
              return checkQuantified("forall", var, domain, body, ctx);
            }

            case existsQ(var, domain, body): {
              return checkQuantified("exists", var, domain, body, ctx);
            }
          }
        }
      }
    }
  }

  return <"Unknown", errors>;
}

tuple[str, list[TypeError]] checkBinaryBool(str ctxName, str left, str right, list[TypeError] errors) {
  if (left != "Unknown" && left != "Bool") {
    errors = errors + [typeMismatch("Bool", left, ctxName)];
  }

  if (right != "Unknown" && right != "Bool") {
    errors = errors + [typeMismatch("Bool", right, ctxName)];
  }

  return <"Bool", errors>;
}

tuple[str, list[TypeError]] checkBinaryInt(str ctxName, str left, str right, list[TypeError] errors, str result) {
  if (left != "Unknown" && left != "Int") {
    errors = errors + [typeMismatch("Int", left, ctxName)];
  }

  if (right != "Unknown" && right != "Int") {
    errors = errors + [typeMismatch("Int", right, ctxName)];
  }

  return <result, errors>;
}

tuple[str, list[TypeError]] checkQuantified(str q, str var, TypeExpr domain, LogExpr body, CheckContext ctx) {
  list[TypeError] errors = [];
  str dom = typeToStr(domain);

  switch (ctx) {
    case checkContext(vars, ops, spaces): {
      if (dom notin spaces) {
        errors = errors + [undeclaredSpace(dom)];
      }

      VarEnv localVars = vars;
      localVars[var] = dom;

      tuple[str, list[TypeError]] bodyType = inferLogExpr(body, checkContext(localVars, ops, spaces));

      errors = errors + bodyType[1];

      if (bodyType[0] != "Unknown" && bodyType[0] != "Bool") {
        errors = errors + [typeMismatch("Bool", bodyType[0], q)];
      }

      return <"Bool", errors>;
    }
  }

  return <"Bool", errors>;
}

str typeErrorToStr(TypeError e) {
  switch (e) {
    case undeclaredOperator(name): {
      return "operador no declarado: <name>";
    }

    case undeclaredVariable(name): {
      return "variable no declarada: <name>";
    }

    case undeclaredSpace(name): {
      return "espacio/tipo no declarado: <name>";
    }

    case unknownElement(elementName, context): {
      return "elemento desconocido <elementName> en <context>";
    }

    case typeMismatch(expectedType, actualType, context): {
      return "tipo esperado <expectedType>, encontrado <actualType> en <context>";
    }

    case arityMismatch(operatorName, expectedCount, actualCount): {
      return "aridad incorrecta en <operatorName>: esperaba <expectedCount>, recibio <actualCount>";
    }

    case invalidRule(message): {
      return "regla invalida: <message>";
    }
  }
}

void printErrors(list[TypeError] errors) {
  int total = lenTypeErrorList(errors);

  if (total == 0) {
    println("Type check OK: no se encontraron errores.");
  } else {
    println("Errores encontrados (<total>):");

    for (TypeError e <- errors) {
      println("  ERROR: <typeErrorToStr(e)>");
    }
  }
}