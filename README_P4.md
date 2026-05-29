# VeriLang P4

Este proyecto extiende VeriLang a partir del Proyecto 3 e integra el parser y el type checker de Rascal con una interfaz en Kotlin.

## Estructura esperada

```text
verilang-p4-initial/
├── rascal-shell-stable.jar
├── pom.xml
├── src/main/rascal/
│   ├── Syntax.rsc
│   ├── AST.rsc
│   ├── Main.rsc
│   ├── TypeChecker.rsc
│   └── RunnerJson.rsc
├── instance/
│   ├── test.vl
│   ├── invalid-test.vl
│   └── output/
└── kotlin-app/