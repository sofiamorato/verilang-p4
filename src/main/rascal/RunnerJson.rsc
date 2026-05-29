module RunnerJson

import AST;
import Syntax;
import TypeChecker;
import Main;
import IO;
import String;
import List;

str escapeJson(str s) {
  str r = replaceAll(s, "\\", "\\\\");
  r = replaceAll(r, "\"", "\\\"");
  r = replaceAll(r, "\n", "\\n");
  r = replaceAll(r, "\r", "");
  return r;
}

str quoted(str s) {
  return "\"" + escapeJson(s) + "\"";
}

str boolText(bool b) {
  if (b) {
    return "true";
  }
  return "false";
}

str intText(int n) {
  return "<n>";
}

int lenStrings(list[str] xs) {
  int n = 0;
  for (str x <- xs) {
    n += 1;
  }
  return n;
}

int lenErrors(list[TypeError] xs) {
  int n = 0;
  for (TypeError e <- xs) {
    n += 1;
  }
  return n;
}

str arrayJson(list[str] xs) {
  list[str] parts = [];

  for (str x <- xs) {
    parts = parts + [quoted(x)];
  }

  return "[" + intercalate(",", parts) + "]";
}

str getModuleName(AST::Module m) {
  switch (m) {
    case verilangModule(name, _, _): {
      return name;
    }
  }

  return "";
}

list[str] getModules(AST::Module m) {
  return [getModuleName(m)];
}

list[str] getUsings(AST::Module m) {
  list[str] out = [];

  switch (m) {
    case verilangModule(_, usings, _): {
      for (Using u <- usings) {
        switch (u) {
          case using(n): {
            out = out + [n];
          }
        }
      }
    }
  }

  return out;
}

list[str] getSpaces(AST::Module m) {
  list[str] out = [];

  switch (m) {
    case verilangModule(_, _, defs): {
      for (Def d <- defs) {
        switch (d) {
          case spaceDef(n, _): {
            out = out + [n];
          }
          default: {
            ;
          }
        }
      }
    }
  }

  return out;
}

list[str] getTypeNames(TypeExpr first, list[TypeExpr] rest) {
  list[str] out = [typeToStr(first)];

  for (TypeExpr t <- rest) {
    out = out + [typeToStr(t)];
  }

  return out;
}

list[str] getOperators(AST::Module m) {
  list[str] out = [];

  switch (m) {
    case verilangModule(_, _, defs): {
      for (Def d <- defs) {
        switch (d) {
          case operatorDef(name, first, rest, _): {
            list[str] types = getTypeNames(first, rest);
            str signature = intercalate(" -\> ", types);
            out = out + [name + ": " + signature];
          }
          default: {
            ;
          }
        }
      }
    }
  }

  return out;
}

list[str] getVariables(AST::Module m) {
  list[str] out = [];

  switch (m) {
    case verilangModule(_, _, defs): {
      for (Def d <- defs) {
        switch (d) {
          case variableDef(decls): {
            for (VarDecl v <- decls) {
              switch (v) {
                case varDecl(n, t): {
                  out = out + [n + ": " + typeToStr(t)];
                }
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

  return out;
}

list[str] getExpressions(AST::Module m) {
  list[str] out = [];

  switch (m) {
    case verilangModule(_, _, defs): {
      for (Def d <- defs) {
        switch (d) {
          case expressionDef(e): {
            out = out + [printLogExpr(e)];
          }
          default: {
            ;
          }
        }
      }
    }
  }

  return out;
}

int getRuleCount(AST::Module m) {
  int n = 0;

  switch (m) {
    case verilangModule(_, _, defs): {
      for (Def d <- defs) {
        switch (d) {
          case ruleDef(_, _): {
            n += 1;
          }
          default: {
            ;
          }
        }
      }
    }
  }

  return n;
}

list[str] getTypeErrors(list[TypeError] errors) {
  list[str] out = [];

  for (TypeError e <- errors) {
    out = out + [typeErrorToStr(e)];
  }

  return out;
}

str makeOkJson(AST::Module m, list[TypeError] errors) {
  bool ok = lenErrors(errors) == 0;

  list[str] modules = getModules(m);
  list[str] usings = getUsings(m);
  list[str] spaces = getSpaces(m);
  list[str] operators = getOperators(m);
  list[str] variables = getVariables(m);
  list[str] expressions = getExpressions(m);
  list[str] typeErrors = getTypeErrors(errors);

  int rules = getRuleCount(m);

  list[str] output = [];
  output = output + ["Modules: " + intercalate(", ", modules)];
  output = output + ["Usings: " + intercalate(", ", usings)];
  output = output + ["Spaces: " + intercalate(", ", spaces)];
  output = output + ["Operators: " + intercalate("; ", operators)];
  output = output + ["Variables: " + intercalate("; ", variables)];
  output = output + ["Rules: " + intText(rules)];
  output = output + ["Expressions: " + intercalate("; ", expressions)];

  str formatted = intercalate("\n", output);

  str summary = "";
  summary = summary + "modules=" + intText(lenStrings(modules));
  summary = summary + ", spaces=" + intText(lenStrings(spaces));
  summary = summary + ", operators=" + intText(lenStrings(operators));
  summary = summary + ", variables=" + intText(lenStrings(variables));
  summary = summary + ", rules=" + intText(rules);
  summary = summary + ", expressions=" + intText(lenStrings(expressions));

  str json = "{\n";
  json = json + "\"success\":" + boolText(ok) + ",\n";
  json = json + "\"parseOk\":true,\n";
  json = json + "\"typeCheckOk\":" + boolText(ok) + ",\n";
  json = json + "\"semanticOk\":" + boolText(ok) + ",\n";
  json = json + "\"module\":" + quoted(getModuleName(m)) + ",\n";
  json = json + "\"modules\":" + arrayJson(modules) + ",\n";
  json = json + "\"usings\":" + arrayJson(usings) + ",\n";
  json = json + "\"spaces\":" + arrayJson(spaces) + ",\n";
  json = json + "\"operators\":" + arrayJson(operators) + ",\n";
  json = json + "\"variables\":" + arrayJson(variables) + ",\n";
  json = json + "\"rules\":" + intText(rules) + ",\n";
  json = json + "\"expressions\":" + arrayJson(expressions) + ",\n";
  json = json + "\"typeErrors\":" + arrayJson(typeErrors) + ",\n";
  json = json + "\"semanticErrors\":[],\n";
  json = json + "\"output\":" + arrayJson(output) + ",\n";
  json = json + "\"error\":\"\",\n";
  json = json + "\"codigoFormateado\":" + quoted(formatted) + ",\n";
  json = json + "\"resumen\":" + quoted(summary) + "\n";
  json = json + "}";

  return json;
}

str makeFailJson(str errorMessage) {
  str json = "{\n";
  json = json + "\"success\":false,\n";
  json = json + "\"parseOk\":false,\n";
  json = json + "\"typeCheckOk\":false,\n";
  json = json + "\"semanticOk\":false,\n";
  json = json + "\"module\":\"\",\n";
  json = json + "\"modules\":[],\n";
  json = json + "\"usings\":[],\n";
  json = json + "\"spaces\":[],\n";
  json = json + "\"operators\":[],\n";
  json = json + "\"variables\":[],\n";
  json = json + "\"rules\":0,\n";
  json = json + "\"expressions\":[],\n";
  json = json + "\"typeErrors\":[],\n";
  json = json + "\"semanticErrors\":[],\n";
  json = json + "\"output\":[],\n";
  json = json + "\"error\":" + quoted(errorMessage) + ",\n";
  json = json + "\"codigoFormateado\":\"\",\n";
  json = json + "\"resumen\":\"parser failed\"\n";
  json = json + "}";

  return json;
}

str runToJson(loc file) {
  try {
    AST::Module m = parseVeriLang(file);
    list[TypeError] errors = checkModule(m);
    return makeOkJson(m, errors);
  }
  catch e: {
    return makeFailJson("<e>");
  }
}

void writeJsonFile(str json) {
  try {
    writeFile(|cwd:///instance/output/verilang-result.json|, json);
  }
  catch e1: {
    try {
      writeFile(|cwd:///instance/verilang-result.json|, json);
    }
    catch e2: {
      ;
    }
  }
}

loc pathToLoc(str path) {
  str clean = replaceAll(path, "\\", "/");
  return |file:///<clean>|;
}

void main(list[str] args) {
  loc file = |cwd:///instance/test.vl|;

  if (lenStrings(args) > 0) {
    file = pathToLoc(args[0]);
  }

  str json = runToJson(file);
  writeJsonFile(json);
  println(json);
}

void main() {
  main([]);
}