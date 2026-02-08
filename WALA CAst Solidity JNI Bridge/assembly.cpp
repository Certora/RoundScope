//
//  assembly.cpp
//  WALA CAst Solidity
//
//  Created by Julian Dolby on 2/6/26.
//

#include "translator.h"
#include <libyul/AST.h>
#include <libyul/Dialect.h>

namespace yul = solidity::yul;
using namespace yul;

jobject visitAssemblyExpression(CAstWrapper &cast, yul::Dialect const& dialect, std::map<yul::Identifier const*, InlineAssemblyAnnotation::ExternalIdentifierInfo>& info, const yul::Expression &e) {
    return std::visit([&](auto&& expr) -> jobject {
        using U = std::decay_t<decltype(expr)>;
        if constexpr (std::is_same_v<U, yul::FunctionCall>) {
            const std::vector<yul::Expression> &args = expr.arguments;
            return std::visit([&](auto&& fn) -> jobject {
                using V = std::decay_t<decltype(fn)>;
                if constexpr (std::is_same_v<V, yul::Identifier>) {
                    return visitAssemblyExpression(cast, dialect, info, fn);
                } else if constexpr (std::is_same_v<V, yul::BuiltinName>) {
                    BuiltinFunction const& fun = dialect.builtin(fn.handle);
                    if (fun.name == "add") {
                        return cast.makeNode(cast.BINARY_EXPR, cast.OP_ADD, visitAssemblyExpression(cast, dialect, info, args[0]), visitAssemblyExpression(cast, dialect, info, args[1]));
                    } else if (fun.name == "div") {
                        return cast.makeNode(cast.BINARY_EXPR, cast.OP_DIV, visitAssemblyExpression(cast, dialect, info, args[0]), visitAssemblyExpression(cast, dialect, info, args[1]));
                    } else if (fun.name == "gt") {
                        return cast.makeNode(cast.IF_EXPR, cast.makeNode(cast.BINARY_EXPR, cast.OP_GT, visitAssemblyExpression(cast, dialect, info, args[0]), visitAssemblyExpression(cast, dialect, info, args[1])), cast.makeConstant(1), cast.makeConstant(0));
                    } else if (fun.name == "iszero") {
                        return cast.makeNode(cast.BINARY_EXPR, cast.OP_EQ, visitAssemblyExpression(cast, dialect, info, args[0]), cast.makeConstant(0));
                    } else if (fun.name == "lt") {
                        return cast.makeNode(cast.IF_EXPR, cast.makeNode(cast.BINARY_EXPR, cast.OP_LT, visitAssemblyExpression(cast, dialect, info, args[0]), visitAssemblyExpression(cast, dialect, info, args[1])), cast.makeConstant(1), cast.makeConstant(0));
                   } else if (fun.name == "mulmod") {
                        return cast.makeNode(cast.BINARY_EXPR, cast.OP_MOD, cast.makeNode(cast.BINARY_EXPR, cast.OP_MUL, visitAssemblyExpression(cast, dialect, info, args[0]), visitAssemblyExpression(cast, dialect, info, args[1])), visitAssemblyExpression(cast, dialect, info, args[2]));
                    } else if (fun.name == "shr") {
                        return cast.makeNode(cast.BINARY_EXPR, cast.OP_RSH, visitAssemblyExpression(cast, dialect, info, args[0]), visitAssemblyExpression(cast, dialect, info, args[1]));
                    } else if (fun.name == "sub") {
                        return cast.makeNode(cast.BINARY_EXPR, cast.OP_SUB, visitAssemblyExpression(cast, dialect, info, args[0]), visitAssemblyExpression(cast, dialect, info, args[1]));
                    } else {
                        std::cout << "builtin assembly function " << fun.name << std::endl;
                        return cast.makeNode(cast.EMPTY);
                    }
                }
            }, expr.functionName);
            
        } else if constexpr (std::is_same_v<U, yul::Identifier>) {
            
            if (info.contains(&expr)) {
                InlineAssemblyAnnotation::ExternalIdentifierInfo& id_info = info[&expr];
                std::cout << id_info.declaration->name() << " for " << expr.name.str();
            } else {
                std::cout << "nothing for " << expr.name.str();
            }
            std::cout << " " << expr.debugData->originLocation.start << ":" << *expr.debugData->originLocation.sourceName << std::endl;
            
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
    }, e);
}

jobject visitAssemblyBlock(JNIEnv *jniEnv, CAstWrapper &cast, yul::Dialect const& dialect, std::map<yul::Identifier const*, InlineAssemblyAnnotation::ExternalIdentifierInfo>& info, const yul::Block& b) {
    jclass wcn = jniEnv->FindClass("com/ibm/wala/cast/tree/CAstNode");
    int i = 0;
    jobjectArray stmts = jniEnv->NewObjectArray(b.statements.size(), wcn, cast.makeNode(cast.EMPTY));
    std::cout << stmts << std::endl;
    for(const yul::Statement& s : b.statements) {
        std::cout << i << std::endl;
        jobject x = std::visit([&](auto&& arg) -> jobject {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, yul::ExpressionStatement>) {
                return visitAssemblyExpression(cast, dialect, info, arg.expression);
                
            } else if constexpr (std::is_same_v<T, yul::Assignment>) {
                yul::Expression& r = *arg.value;
                jobject rhs = visitAssemblyExpression(cast, dialect, info, r);
                
                const std::vector<yul::Identifier>& vns = arg.variableNames;
                if (vns.size() == 1) {
                    jobject lhs = visitAssemblyExpression(cast, dialect, info, *vns.begin());
                    
                    std::cout << lhs << " " << rhs << std::endl;
                    return cast.makeNode(cast.ASSIGN, lhs, rhs);
                } else {
                    return cast.makeNode(cast.EMPTY);
                }
                
            } else if constexpr (std::is_same_v<T, yul::VariableDeclaration>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, yul::FunctionDefinition>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, If>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, Switch>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, ForLoop>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, yul::Break>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, yul::Continue>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, Leave>) {
                return cast.makeNode(cast.EMPTY);

            } else if constexpr (std::is_same_v<T, yul::Block>) {
                return visitAssemblyBlock(jniEnv, cast, dialect, info, arg);
                
            } else
                static_assert(false, "non-exhaustive visitor!");
        }, s);
        if (x != NULL) {
            jniEnv->SetObjectArrayElement(stmts, i++, x);
        }
    }
    return cast.makeNode(cast.BLOCK_STMT, stmts);
}

bool Translator::visit(const InlineAssembly &_node) {
    yul::AST const& ast = _node.operations();
    yul::Block const& root = ast.root();
    yul::Dialect const& dialect = _node.dialect();
    std::map<yul::Identifier const*, InlineAssemblyAnnotation::ExternalIdentifierInfo>& info = _node.annotation().externalReferences;
    
    ret(record(visitAssemblyBlock(jniEnv, cast, dialect, info, root), _node.location()));
    
    return false;
}
