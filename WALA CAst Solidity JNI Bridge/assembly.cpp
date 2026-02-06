//
//  assembly.cpp
//  WALA CAst Solidity
//
//  Created by Julian Dolby on 2/6/26.
//

#include "translator.h"
#include <libyul/AST.h>

namespace yul = solidity::yul;
using namespace yul;

jobject visitAssembly(CAstWrapper &cast, const yul::Statement &s) {
    return std::visit([&](auto&& arg) -> jobject {
        using T = std::decay_t<decltype(arg)>;
        if constexpr (std::is_same_v<T, yul::ExpressionStatement>) {

            return std::visit([&](auto&& expr) -> jobject {
                using U = std::decay_t<decltype(expr)>;
                if constexpr (std::is_same_v<U, yul::FunctionCall>) {
                    
                } else if constexpr (std::is_same_v<U, yul::Identifier>) {
                    return cast.makeNode(cast.VAR, cast.makeConstant(expr.name.str().c_str()));
                } else if constexpr (std::is_same_v<U, yul::Literal>) {
                    switch (expr.kind) {
                        case LiteralKind::Number:
                            return cast.makeConstant((long)expr.value.value());
                        case LiteralKind::String:
                            return cast.makeConstant(expr.value.builtinStringLiteralValue().c_str());
                        case LiteralKind::Boolean:
                            return cast.makeConstant(expr.value.value() != 0);
                        default:
                            return cast.makeConstant(NULL);
                    }
                } else
                    static_assert(false, "non-exhaustive visitor!");
            }, arg.expression);

        } else if constexpr (std::is_same_v<T, yul::Assignment>) {
            
        } else if constexpr (std::is_same_v<T, yul::VariableDeclaration>) {
            
        } else if constexpr (std::is_same_v<T, yul::FunctionDefinition>) {
            
        } else if constexpr (std::is_same_v<T, If>) {
            
        } else if constexpr (std::is_same_v<T, Switch>) {
            
        } else if constexpr (std::is_same_v<T, ForLoop>) {
            
        } else if constexpr (std::is_same_v<T, yul::Break>) {
            
        } else if constexpr (std::is_same_v<T, yul::Continue>) {
            
        } else if constexpr (std::is_same_v<T, Leave>) {
            
        } else if constexpr (std::is_same_v<T, yul::Block>) {
            for(const yul::Statement& ss : arg.statements) {
                visitAssembly(cast, ss);
            }

        } else
            static_assert(false, "non-exhaustive visitor!");
    }, s);
}

bool Translator::visit(const InlineAssembly &_node) {
    yul::AST const& ast = _node.operations();
    yul::Block const& root = ast.root();
    
    for(const yul::Statement& s : root.statements) {
        visitAssembly(cast, s);
    }
    
    ret(cast.makeNode(cast.EMPTY));
    return false;
}
