module Main

import AST;
import TypeChecker;
import ParseTree;
import IO;
import String;
import Syntax;

AST::Module parseVeriLang(loc file) {
  str src = readFile(file);
  Tree t = parse(#start[Module], src, file);
  return implode(#AST::Module, t);
}

str typeStr(TypeExpr t) {
  return typeToStr(t);
}

list[str] operatorAllTypes(TypeExpr first, list[TypeExpr] rest) {
  list[str] result = [typeStr(first)];

  for (TypeExpr t <- rest) {
    result += [typeStr(t)];
  }

  return result;
}

list[str] operatorArgTypes(TypeExpr first, list[TypeExpr] rest) {
  list[str] allTypes = operatorAllTypes(first, rest);
  list[str] args = [];

  int i = 0;
  while (i < size(allTypes) - 1) {
    args += allTypes[i];
    i += 1;
  }

  return args;
}

str operatorReturnType(TypeExpr first, list[TypeExpr] rest) {
  list[str] allTypes = operatorAllTypes(first, rest);

  if (isEmpty(allTypes)) {
    return "Unknown";
  }

  return allTypes[size(allTypes) - 1];
}

void printModule(AST::Module m) {
  switch (m) {
    case verilangModule(name, usings, defs): {
      println("=== Modulo: <name> ===");

      if (!isEmpty(usings)) {
        list[str] usingNames = [];

        for (Using u <- usings) {
          switch (u) {
            case using(n): {
              usingNames += n;
            }
          }
        }

        str usingsText = intercalate(", ", usingNames);
        println("  Usa: <usingsText>");
      }

      for (Def d <- defs) {
        printDef(d);
      }
    }
  }
}

void printDef(Def d) {
  switch (d) {
    case spaceDef(name, parent): {
      str parentText = "";

      if (!isEmpty(parent)) {
        str parents = intercalate(", ", parent);
        parentText = " \< <parents>";
      }

      println("  [Espacio]   <name><parentText>");
    }

    case operatorDef(name, first, rest, attrs): {
      list[str] args = operatorArgTypes(first, rest);
      str result = operatorReturnType(first, rest);

      str signature = result;

      if (!isEmpty(args)) {
        str argsText = intercalate(" -\> ", args);
        signature = argsText + " -\> " + result;
      }

      println("  [Operador]  <name> : <signature>");
    }

    case variableDef(decls): {
      for (VarDecl v <- decls) {
        switch (v) {
          case varDecl(vname, vtype): {
            str vtypeText = typeStr(vtype);
            println("  [Variable]  <vname> : <vtypeText>");
          }
        }
      }
    }

    case ruleDef(lhs, rhs): {
      str lhsText = printRuleExpr(lhs);
      str rhsText = printRuleExpr(rhs);
      println("  [Regla]     <lhsText> -\> <rhsText>");
    }

    case expressionDef(expr): {
      str exprText = printLogExpr(expr);
      println("  [Expresion] <exprText>");
    }
  }
}

str printRuleExpr(RuleExpr e) {
  switch (e) {
    case ruleAtom(n): {
      return n;
    }

    case ruleApp(op, args): {
      list[str] printedArgs = [];

      for (RuleExpr a <- args) {
        printedArgs += printRuleExpr(a);
      }

      str argsText = intercalate(" ", printedArgs);
      return "(" + op + " " + argsText + ")";
    }

    default: {
      return "?";
    }
  }
}

str printLogExpr(LogExpr e) {
  switch (e) {
    case atom(n): {
      return n;
    }

    case numLit(n): {
      return n;
    }

    case charLit(c): {
      return c;
    }

    case stringLit(s): {
      return s;
    }

    case boolLit(b): {
      return "<b>";
    }

    case unary(negOp(), expr): {
      str exprText = printLogExpr(expr);
      return "(neg " + exprText + ")";
    }

    case binary(l, binOp, r): {
      str leftText = printLogExpr(l);
      str opText = printBinOp(binOp);
      str rightText = printLogExpr(r);
      return "(" + leftText + " " + opText + " " + rightText + ")";
    }

    case quantified(q): {
      return printQuantifier(q);
    }

    default: {
      return "?";
    }
  }
}

str printBinOp(BinOp op) {
  switch (op) {
    case andOp(): {
      return "and";
    }

    case orOp(): {
      return "or";
    }

    case eqOp(): {
      return "=";
    }

    case impOp(): {
      return "=\>";
    }

    case ltOp(): {
      return "\<";
    }

    case gtOp(): {
      return "\>";
    }

    case leOp(): {
      return "\<=";
    }

    case geOp(): {
      return "\>=";
    }

    case addOp(): {
      return "+";
    }

    case subOp(): {
      return "-";
    }

    case mulOp(): {
      return "*";
    }

    case divOp(): {
      return "/";
    }

    default: {
      return "?";
    }
  }
}

str printQuantifier(Quantifier q) {
  switch (q) {
    case forallQ(v, dom, body): {
      str domText = typeStr(dom);
      str bodyText = printLogExpr(body);
      return "(forall " + v + " in " + domText + " . " + bodyText + ")";
    }

    case existsQ(v, dom, body): {
      str domText = typeStr(dom);
      str bodyText = printLogExpr(body);
      return "(exists " + v + " in " + domText + " . " + bodyText + ")";
    }

    default: {
      return "?";
    }
  }
}

void runFile(loc file) {
  println("Parseando: <file>\n");

  try {
    AST::Module m = parseVeriLang(file);

    printModule(m);

    println("\n--- Type Checking ---");
    list[TypeError] errors = checkModule(m);
    printErrors(errors);
  }
  catch e: {
    println("Error al parsear: <e>");
  }
}

void main() {
  runFile(|cwd:///instance/test.vl|);
}