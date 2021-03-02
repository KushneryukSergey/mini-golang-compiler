%{
    #include <cerrno>
    #include <climits>
    #include <cstdlib>
    #include <cstring> // strerror
    #include <string>
    #include <iostream>

    #include "parser.hh"

    #include "lib/driver.h"
    #include "lib/scanner.h"
    #include "lib/statement.h"
    #include "lib/var_type.h"
%}

%option noyywrap nounput noinput batch debug

%option c++
%option yyclass="Scanner"

%{
    yy::parser::symbol_type
    create_integer_from(const std::string &str,
                        const yy::parser::location_type& loc);

    yy::parser::symbol_type
    create_float_from(const std::string &str,
                      const yy::parser::location_type& loc);

    // TODO: correct process numbers in string
    yy::parser::symbol_type filter_string(
        const std::string &str,
        const yy::parser::location_type& loc
    );
%}

ESC_SEQ (\\\\)|(\\\')|(\\\")|(\\?)|(\\a)|(\\b)|(\\f)|(\\n)|(\\r)|(\\t)|(\\v)|(\\0)|(\\x)
IDENT   [a-zA-Z][a-zA-Z_0-9]*
STRING  \"(ESC_SEQ|[^\\\'\"\?])*\"
DEC     -?[1-9][0-9]*|0
OCT     0[0-9]*
HEX     0x[a-fA-F0-9]+
FLOAT   (DEC\.DEC)|(DEC\.)
SPACE   [ \t\r]

%{
  // Code run each time a pattern is matched.
  # define YY_USER_ACTION  loc.columns (yyleng);
%}
%%
%{
  // A handy shortcut to the location held by the driver.
  yy::location& loc = driver.location;
  loc.step();
%}


{SPACE}+    loc.step ();
\n+         loc.lines(yyleng); loc.step ();

// MATHS
"-"         return yy::parser::make_MINUS   (loc);
"+"         return yy::parser::make_PLUS    (loc);
"*"         return yy::parser::make_STAR    (loc); // not only math operation
"/"         return yy::parser::make_DIV     (loc);
"%"         return yy::parser::make_MOD     (loc);

// ASSIGNMENT
"="         return yy::parser::make_ADD_ASGN(loc);
":="        return yy::parser::make_SHORT_ASSIGN(loc);
"+="        return yy::parser::make_ADD_ASGN(loc);
"-="        return yy::parser::make_SUB_ASGN(loc);
"*="        return yy::parser::make_MUL_ASGN(loc);
"/="        return yy::parser::make_DIV_ASGN(loc);
"%="        return yy::parser::make_MOD_ASGN(loc);
"<<="       return yy::parser::make_LEFT_ASGN(loc);
">>="       return yy::parser::make_RIGHT_ASGN(loc);
"&="        return yy::parser::make_AND_ASGN(loc);
"^="        return yy::parser::make_XOR_ASGN(loc);
"|="        return yy::parser::make_OR_ASGN (loc);

"++"        return yy::parser::make_INCR    (loc);
"--"        return yy::parser::make_DECR    (loc);

// COMPARISON
"=="        return yy::parser::make_EQUALS  (loc);
"!="        return yy::parser::make_DIFFER  (loc);
"<="        return yy::parser::make_LEQ     (loc);
">="        return yy::parser::make_GEQ     (loc);
"<"         return yy::parser::make_LE      (loc);
">"         return yy::parser::make_GE      (loc);

// LOGICAL
"true"      return yy::parser::make_true    (loc);
"false"     return yy::parser::make_false   (loc);
"&&"        return yy::parser::make_LOG_AND (loc);
"||"        return yy::parser::make_LOG_OR  (loc);
"!"         return yy::parser::make_NOT     (loc);

// BITWISE
"&"         return yy::parser::make_ANDSIGN (loc);  // not only bitwise operation
"|"         return yy::parser::make_BIT_AND (loc);
"^"         return yy::parser::make_BIT_XOR (loc);
"<<"        return yy::parser::make_BIT_LEFT(loc);
">>"        return yy::parser::make_BIT_RIGHT(loc);
"~"         return yy::parser::make_REV     (loc);

// CONDITION
"if"        return yy::parser::make_IF      (loc);
"else"      return yy::parser::make_ELSE    (loc);

// LOOP
"for"       return yy::parser::make_FOR     (loc);

// FUNCTION
"func"      return yy::parser::make_FUNCDECL(loc);

// CLASSES/STRUCTS
"struct"    return yy::parser::make_STRUCT  (loc);
"interface" return yy::parser::make_INTERFACE(loc);

// SPEC
"new"       return yy::parser::make_NEW     (loc);
"var"       return yy::parser::make_VAR     (loc);
"make"      return yy::parser::make_MAKE    (loc);
"sizeof"    return yy::parser::make_SIZEOF  (loc);
"package"   return yy::parser::make_PACKAGE (loc);
";"         return yy::parser::make_SEMICOLON(loc);
","         return yy::parser::make_COMMA   (loc);
"."         return yy::parser::make_DOT     (loc);
"{"         return yy::parser::make_LBRACE  (loc);
"}"         return yy::parser::make_RBRACE  (loc);
"["         return yy::parser::make_LBRACK  (loc);
"]"         return yy::parser::make_RBRACK  (loc);
"("         return yy::parser::make_LPAREN  (loc);
")"         return yy::parser::make_RPAREN  (loc);
"->"        return yy::parser::make_ARROW   (loc);
"..."       return yy::parser::make_ELLIPSIS(loc);

// TEMPORARY: hardcode of Println and other special methods
"fmt.Println" return yy::parser::make_PRINTLN (loc);

{STRING}    return filter_string        (yytext, loc);
{IDENT      return yy::parser::make_IDENT(yytext, loc);
{DEC}       return create_integer_from  (yytext, loc);
{HEX}       return create_integer_from  (yytext, loc);
{OCT}       return create_integer_from  (yytext, loc);
{FLOAT}     return create_float_from    (yytext, loc);
.           throw yy::parser::syntax_error(loc, "invalid character: " + std::string(yytext));
<<EOF>>     return yy::parser::make_END (loc);
%%

// TODO:
// * check if all tokens created
// * predeclare functions

yy::parser::symbol_type filter_string (const std::string &str,
                                       const yy::parser::location_type& loc) {
    std::string result = "";
    bool prev_deux = false;
    for (int i = 1; i < str.size() - 1; ++i) {
        if (prev_deux) {
            if (str[i] == ':') {
                result.push_back(':');
            } else if (str[i] == ')') {
                result.push_back('\n');
            } else if (str[i] == '>') {
                result.push_back('\t');
            } else if (str[i] == 'o') {
                result.push_back('\a');
            } else if (str[i] == '\"') {
                result.push_back('\"');
            } else {
                throw yy::parser::syntax_error(loc, "incorrect string: " + str);
            }
            prev_deux = false;
        } else {
            if (str[i] == ':') {
                prev_deux = true;
            } else {
                result.push_back(str[i]);
            }
        }
    }
    return yy::parser::make_STRING(result, loc);
}

yy::parser::symbol_type create_integer_from(const std::string &str,
                                            const yy::parser::location_type& loc) {
    errno = 0;
    long long n = strtol(str.c_str(), NULL, 0);
    if (! (INT_MIN <= n && n <= INT_MAX && errno != ERANGE))
        throw yy::parser::syntax_error(loc, "integer is out of range: " + str);
    return yy::parser::make_NUMBER((int) n, loc);
}

yy::parser::symbol_type create_float_from(const std::string &str,
                                          const yy::parser::location_type& loc) {
    errno = 0;
    double d = strtod(str.c_str(), NULL, 0);
    if (errno == ERANGE)
        throw yy::parser::syntax_error(loc, "float is out of range: " + str);
    return yy::parser::make_FLOAT(n, loc);
}