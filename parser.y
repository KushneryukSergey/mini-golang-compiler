%skeleton "lalr1.cc"
%require "3.5"

%defines
%define api.token.constructor
%define api.value.type variant
%define parse.assert

/* TODO:
func
import
var -> types
return
array: var id [...]
Unused variable = error
*/


%code requires {
    #include <string>
    #include <iostream>
    #include <algorithm>

    class Statement;
    class StmtList;
    class ExprStmt;
    class VarStmt;
    class NotStmt;
    class UnaryStmt;
    class BinaryStmt;
    class ConstStmt;
    class AssignStmt;
    class LoopStmt;
    class IfElseStmt;
    class WriteStmt;
    class ReadStmt;

    enum class UnaryOperationType;
    enum class BinaryOperationType;
    enum class LoopType;
    enum class Type;

    class Scanner;
    class Driver;
}

%define parse.trace
%define parse.error verbose

%code {
    #include "lib/driver.h"
    #include "lib/scanner.h"
    #include "lib/statement.h"
    #include "lib/var_type.h"
    #include "lib/tools.h"
    #include "location.hh"
    #include "parser.hh"

    class Scanner;
    class Driver;

    static yy::parser::symbol_type yylex(Scanner &scanner, Driver& driver) {
        return scanner.ScanToken();
    }
}

%lex-param { Scanner &scanner }
%lex-param { Driver &driver }
%parse-param { Scanner &scanner }
%parse-param { Driver &driver }

%locations

%define api.token.prefix {TOK_}

%token
    END 0       "end of file"

// MATHS
    MINUS       "-"
    PLUS        "+"
    STAR        "*"
    DIV         "/"
    MOD         "%"

// ASSIGNMENT
    ADD_ASGN    "="
    SHORT_ASSIGN ":="
    ADD_ASGN    "+="
    SUB_ASGN    "-="
    MUL_ASGN    "*="
    DIV_ASGN    "/="
    MOD_ASGN    "%="
    LEFT_ASGN   "<<="
    RIGHT_ASGN  ">>="
    AND_ASGN    "&="
    XOR_ASGN    "^="
    OR_ASGN     "|="

    INCR        "++"
    DECR        "--"

// COMPARISON
    EQUALS      "=="
    DIFFER      "!="
    LEQ         "<="
    GEQ         ">="
    LE          "<"
    GE          ">"

// LOGICAL
    true        "true"
    false       "false"
    LOG_AND     "&&"
    LOG_OR      "||"
    NOT         "!"

// BITWISE
    ANDSIGN     "&"
    BIT_AND     "|"
    BIT_XOR     "^"
    BIT_LEFT    "<<"
    BIT_RIGHT   ">>"
    REV         "~"

// CONDITION
    IF          "if"
    ELSE        "else"

//LOOP
    FOR         "for"

//FUNCTION
    FUNCDECL    "func"

//CLASSES/STRUCTS
    STRUCT      "struct"
    INTERFACE   "interface"

// SPEC
    VAR         "var"
    NEW         "new"
    MAKE        "make"
    SIZEOF      "sizeof"
    PACKAGE     "package"
    SEMICOLON   ";"
    COMMA       ","
    DOT         "."
    LBRACE      "{"
    RBRACE      "}"
    LBRACK      "["
    RBRACK      "]"
    LPAREN      "("
    RPAREN      ")"
    ARROW       "->"
    ELLIPSIS    "..."
;

%token <std::string> IDENT
%token <std::string> STRING "string literal"
%token <int> INTEGER "integer"
%token <float> FLOAT "float"

%nterm <StmtList*> STMTS
%nterm <ExprStmt*> EXPR
%nterm <AssignStmt*> TOP_LEVEL_EXPR
%nterm <AssignStmt*> DECLARATION
%nterm <AssignStmt*> ASSIGNMENT
%nterm <UnaryStmt*> UNARY_STMT
%nterm <IfElseStmt*> CONDITION
%nterm <WriteStmt*> OUTPUT
%nterm <ReadStmt*> INPUT
%nterm <LoopStmt*> LOOP


%printer { yyo << $$; } <*>;

%%
%start PROGRAM;

// PROGRAM DESCRIPTION
PROGRAM:
      PACKAGES {}
    | IMPORTS {}
    | DECL_LIST {}
    ;


PACKAGES:
      %empty
    | PACKAGES PACKAGE IDENT {}
    ;

IMPORTS:
      %empty
    | IMPORT IDENT {}
    | IMPORT LPAREN LIBS_LIST RPAREN {}
    ;

LIBS_LIST:
      IDENT {}
    | LIBS_LIST IDENT {}
    ;

DECL_LIST:
      FUNC_DECL {}
    | STRUCT_DECL {}
    | METHOD_DECL {}
    ;



// STATEMENTS
STMT:
      DECLARATION { $$ = $1; }
    | ASSIGNMENT  { $$ = $1; }
    | UNARY_STMT  { $$ = $1; }
    | CONDITION   { $$ = $1; }
    | OUTPUT      { $$ = $1; }
 // | INPUT       { $$ = $1; }
    | LOOP        { $$ = $1; }
    | EXPR        { $$ = $1; }
    ;

STMTS:
    %empty {
        $$ = new StmtList();
    }
    | STMTS STMT SEMICOLON { $$ = $1; $1->push_back($2); }
    ;



// FUNCTIONS
FUNC_DECL:
      FUNCDECL IDENT LPAREN PARAM_LIST RPAREN RET_TYPES STMTS {}
    ;

PARAM_LIST:
    {}
    | PARAM_LIST IDENT IDENT {}
    ;

RET_TYPES:
    {}
    | ONE_RET_TYPE {}
    | LPAREN MULT_RET_TYPES RPAREN {}
    ;

ONE_RET_TYPE:
    IDENT IDENT {}
    ;

MULT_RET_TYPES:
    ONE_RET_TYPE {}
    | MULT_RET_TYPES COMMA ONE_RET_TYPE {}
    ;


// STRUCTURES
STRUCT_DECL:
    STRUCT IDENT LBRACK MEMBER_LIST RBRACK {}
    ;

MEMBER_LIST:
      IDENT IDENT {}
    | MEMBER_LIST IDENT IDENT {}
    ;

// TODO: methods


// EXPRESSIONS AND DECLARATIONS
EXPR:
// constants and variables
      IDENT {
          $$ = new VarStmt(driver.variables[$1]);
      }
    | STRING {
          $$ = new ConstStmt(VarType($1));
      }
    | INTEGER {
          $$ = new ConstStmt(VarType($1));
      }
    | FLOAT {
          $$ = new ConstStmt(VarType($1));
      }
// comparison
    | EXPR EQUALS EXPR {
        $$ = new BinaryStmt($2, $4, BinaryOperationType::EQUALS);
      }
    | EXPR DIFFER EXPR {
        $$ = new BinaryStmt($2, $4, BinaryOperationType::EQUALS);
      }
    | EXPR LEQ EXPR {
        $$ = new BinaryStmt($2, $4, BinaryOperationType::EQUALS);
      }
    | EXPR GEQ EXPR {
        $$ = new BinaryStmt($2, $4, BinaryOperationType::EQUALS);
      }
    | EXPR LE EXPR {
        $$ = new BinaryStmt($2, $4, BinaryOperationType::EQUALS);
      }
    | EXPR GE EXPR {
        $$ = new BinaryStmt($2, $4, BinaryOperationType::EQUALS);
      }
// logical expression
    | true {
          $$ = new ConstStmt(VarType(true));
      }
    | false {
          $$ = new ConstStmt(VarType(false));
      }
    | NOT EXPR {
          $$ = new NotStmt($2);
      }
    | EXPR LOG_AND EXPR {
          $$ = new BinaryStmt($3, $5, BinaryOperationType::AND);
      }
    | EXPR LOG_OR  EXPR {
          $$ = new BinaryStmt($3, $5, BinaryOperationType::OR);
      }
// mathematical expression
    | EXPR PLUS EXPR {
          $$ = new BinaryStmt($3, $5, BinaryOperationType::SUM);
      }
    | EXPR MINUS EXPR {
          $$ = new BinaryStmt($3, $5, BinaryOperationType::SUB);
      }
    | EXPR STAR EXPR {
          $$ = new BinaryStmt($3, $5, BinaryOperationType::MUL);
      }
    | EXPR DIV EXPR {
          $$ = new BinaryStmt($3, $5, BinaryOperationType::DIV);
      }
    | EXPR MOD EXPR {
          $$ = new BinaryStmt($3, $5, BinaryOperationType::MOD);
      }
    | LPAREN EXPR RPAREN {
          $$ = $2;
      }
    | UNARY_STMT {
          $$ = $2;
      }

    ;

DECLARATION:
      VAR IDENT IDENT {
        $$ = new AssignStmt(new ConstStmt(VarType(0)), driver.variables[$2]);
    }
    | VAR IDENT IDENT ASSIGN EXPR {
          $$ = new AssignStmt(new ConstStmt($5), driver.variables[$2]);
      }
    ;

ASSIGNMENT:
      IDENT ASSIGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT SHORT_ASSIGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT ADD_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT SUB_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT MUL_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT DIV_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT MOD_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT AND_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT XOR_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    | IDENT OR_ASGN EXPR {
          $$ = new AssignStmt($3, driver.variables[$1]);
      }
    ;

UNARY_STMT:
      MINUS EXPR {}
    | INCR IDENT {
          $$ = $2;
      }
    | IDENT INCR {
          $$ = $2;
      }
    | DECR IDENT {
          $$ = $2;
      }
    | IDENT DECR {
          $$ = $2;
      }
    ;

CONDITION:
      IF EXPR LBRACK STMTS RBRACK {
          $$ = new IfElseStmt($3, new StmtList(), driver.variables["IT"]);
      }
    | IF EXPR LBRACK STMTS RBRACK ELSE LBRACK STMTS RBRACK {
          $$ = new IfElseStmt($3, $5, driver.variables["IT"]);
      }
    ;

OUTPUT:
    PRINTLN LPAREN EXPR RPAREN { $$ = new WriteStmt($3); }
    ;

LOOP:
    FOR EXPR LBRACK STMTS RBRACK {
         $$ = new LoopStmt(nullptr, $2, $4, LoopType::WHILE);
    }
    ;

%%

void
yy::parser::error(const location_type& l, const std::string& m)
{
  std::cerr << l << ": " << m << '\n';
}
