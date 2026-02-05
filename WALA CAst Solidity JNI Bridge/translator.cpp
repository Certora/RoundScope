//
//  translator.cpp
//  WALA CAst Solidity
//
//  Created by Julian Dolby on 12/19/25.
//
#include "translator.h"
#include "CAstWrapper.h"

void showStackTrace() {
    std::cout << cpptrace::generate_trace() << std::endl;
}

std::map<std::string, jobject> types;

jobject Translator::getType(std::string tn) {
    jclass sct = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/SolidityCAstType");
    jmethodID gt = jniEnv->GetStaticMethodID(sct, "get", "(Ljava/lang/String;)Lcom/ibm/wala/cast/tree/CAstType;");
    jobject jtn = jniEnv->NewStringUTF(tn.c_str());
    return jniEnv->CallStaticObjectMethod(sct, gt, jtn);
}

jobject Translator::getType(Type const* type) {
    if (type->category() == Type::Category::Array) {
        ArrayType const* arrayType = (ArrayType *)type;
        jobject elt = getType(arrayType->baseType());
        jclass smt = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/SolidityArrayType");
        jmethodID gt = jniEnv->GetStaticMethodID(smt, "get", "(Lcom/ibm/wala/cast/tree/CAstType;)Lcom/ibm/wala/cast/tree/CAstType;");
        return jniEnv->CallStaticObjectMethod(smt, gt, elt);

    } else if (type->category() == Type::Category::Tuple) {
        TupleType const* tupleType = (TupleType const*)type;
        std::vector<Type const*> const& eltTypes = tupleType->components();
        jobjectArray eltCAstTypes = jniEnv->NewObjectArray(eltTypes.size(), jniEnv->FindClass("com/ibm/wala/cast/tree/CAstType"), NULL);
        int i = 0;
        for (std::vector<Type const *>::const_iterator t=eltTypes.begin();
             t != eltTypes.end();
             ++t, i++)
        {
            jniEnv->SetObjectArrayElement(eltCAstTypes, i, getType(*t));
        }
        jclass smt = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/SolidityTupleType");
        jmethodID gt = jniEnv->GetStaticMethodID(smt, "get", "([Lcom/ibm/wala/cast/tree/CAstType;)Lcom/ibm/wala/cast/tree/CAstType;");
        return jniEnv->CallStaticObjectMethod(smt, gt, eltCAstTypes);

    } else if (type->category() == Type::Category::Mapping) {
        MappingType const* mapType = (MappingType const*)type;
       jobject keyType = getType(mapType->keyType());
        jobject valueType = getType(mapType->valueType());
        jclass smt = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/SolidityMappingType");
        jmethodID gt = jniEnv->GetStaticMethodID(smt, "get", "(Lcom/ibm/wala/cast/tree/CAstType;Lcom/ibm/wala/cast/tree/CAstType;)Lcom/ibm/wala/cast/tree/CAstType;");
        return jniEnv->CallStaticObjectMethod(smt, gt, keyType, valueType);
        
    } else {
        const UserDefinedValueTypeDefinition *t = dynamic_cast<UserDefinedValueTypeDefinition const*>(type->typeDefinition());
        std::string tn;
        if (t != NULL) {
            return getType(t->underlyingType()->annotation().type);
            
        } else {
            tn = type->toString(true);
        }
        
         return getType(tn);
    }
}

bool Translator::visitNode(ASTNode const&_node) {
    level++;
    indent();
    std::cout << _node.location() << " " << _node.id() << " " << typeid(_node).name() << std::endl;
    showStackTrace();
    jobject nothing = cast.makeNode(cast.EMPTY);
    ret(nothing);
    return true;
}

void Translator::endVisitNode(ASTNode const&_node) {
    level--;
}

bool Translator::visit(const SourceUnit &_node) {
    std::vector<ASTPointer<ASTNode>> nodes = _node.nodes();
    int len = (int)nodes.size();
    jclass cnc = jniEnv->FindClass("com/ibm/wala/cast/tree/CAstNode");
    jobjectArray children = jniEnv->NewObjectArray(len, cnc, NULL);

    int i = 0;
    for (std::vector<ASTPointer<ASTNode>>::iterator t=nodes.begin();
         t != nodes.end();
         ++t, i++)
    {
        t->get()->accept(*this);
        jobject stmts = last();
        if (stmts == NULL) {
            stmts = cast.makeNode(cast.EMPTY);
        }
        jniEnv->SetObjectArrayElement(children, i, stmts);
    }
    
    ret(cast.makeNode(cast.BLOCK_STMT, children));
    return false;
}

class ContractContext : public virtual VariableContainerContext, public virtual FunctionContainerContext {
private:
    jobject supersSet;
    jobject _type;
    JNIEnv *jniEnv;
    
public:
    ContractContext(DelegatingContext *parent, JNIEnv *jniEnv, jobject supersSet, jobject type) : DelegatingContext(parent), FunctionContainerContext(parent), VariableContainerContext(parent), jniEnv(jniEnv), supersSet(supersSet), _type(type){
        
    }
    
    virtual jobject type() override {
        return _type;
    }
    
    virtual void addSuperclass(std::string type) override {
        jclass sCls = jniEnv->FindClass("java/util/HashSet");
        jmethodID add = jniEnv->GetMethodID(sCls, "add", "(Ljava/lang/Object;)Z");
        jniEnv->CallBooleanMethod(supersSet, add, jniEnv->NewStringUTF(type.c_str()));
    }
    
    virtual jobject& superClasses() override {
        return supersSet;
    }
};

bool Translator::visit(const ContractDefinition &_node) {
    std::string contractName = ((TypeType*)_node.type())->actualType()->toString(true);
    jclass sCls = jniEnv->FindClass("java/util/HashSet");
    jmethodID sCtor = jniEnv->GetMethodID(sCls, "<init>", "()V");
    jobject supersSet = jniEnv->NewObject(sCls, sCtor);
    jstring entityName = jniEnv->NewStringUTF(contractName.c_str());

    jclass ctCls;
    jobject contractType;
    if (_node.isInterface()) {
        ctCls = jniEnv->FindClass("com/certora/wala/cast/solidity/loader/InterfaceType");
        jmethodID ctCtor = jniEnv->GetMethodID(ctCls, "<init>", "(Ljava/lang/String;Ljava/util/Set;)V");
        contractType = jniEnv->NewObject(ctCls, ctCtor, entityName, supersSet);
    } else if (_node.isLibrary()) {
        ctCls = jniEnv->FindClass("com/certora/wala/cast/solidity/loader/LibraryType");
        jmethodID ctCtor = jniEnv->GetMethodID(ctCls, "<init>", "(Ljava/lang/String;)V");
        contractType = jniEnv->NewObject(ctCls, ctCtor, entityName);
    } else {
        ctCls = jniEnv->FindClass("com/certora/wala/cast/solidity/loader/ContractType");
        jmethodID ctCtor = jniEnv->GetMethodID(ctCls, "<init>", "(Ljava/lang/String;Ljava/util/Set;)V");
        contractType = jniEnv->NewObject(ctCls, ctCtor, entityName, supersSet);
    }
    
    types[contractName] = contractType;
    

    context = new ContractContext(context, jniEnv, supersSet, contractType);
    return true;
}

void Translator::endVisit(const ContractDefinition &_node) {
    std::string contractName = ((TypeType*)_node.type())->actualType()->toString(true);
 
    jobject contractType = types[contractName] ;
    
    jclass sCls = jniEnv->FindClass("java/util/HashSet");
    jmethodID sCtor = jniEnv->GetMethodID(sCls, "<init>", "()V");
    jmethodID add = jniEnv->GetMethodID(sCls, "add", "(Ljava/lang/Object;)Z");
    jobject entitiesSet = jniEnv->NewObject(sCls, sCtor);
    std::map<jstring, jobject>& functions = context->functions();
    for (std::map<jstring,jobject>::iterator t=functions.begin();
         t != functions.end();
         ++t)
    {
        jniEnv->CallBooleanMethod(entitiesSet, add, t->second);
    }
    std::map<jstring, jobject>& fields = context->variables();
    for (std::map<jstring,jobject>::iterator t=fields.begin();
         t != fields.end();
         ++t)
    {
        jniEnv->CallBooleanMethod(entitiesSet, add, t->second);
    }

    jclass ceCls = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/ContractEntity");
    jmethodID ceCtor = jniEnv->GetMethodID(ceCls, "<init>", "(Lcom/ibm/wala/cast/tree/CAstType$Class;Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;Ljava/util/Set;)V");
    jobject contractEntity = jniEnv->NewObject(ceCls, ceCtor, contractType, makePosition(_node.location()), makePosition(_node.nameLocation()), entitiesSet);
    
    context = context->parent();
    
    cast.addChildEntity(context->entity(), NULL, contractEntity);
}

jobject translateOpcode(CAstWrapper& cast, Token t) {
    switch(t) {
        case Token::Not: return cast.OP_NOT;
        case Token::Exp: return cast.OP_POW;
        case Token::Add: case Token::AssignAdd: case Token::Inc: return cast.OP_ADD;
        case Token::Sub: case Token::AssignSub: case Token::Dec: return cast.OP_SUB;
        case Token::Mul: case Token::AssignMul: return cast.OP_MUL;
        case Token::Div: case Token::AssignDiv: return cast.OP_DIV;
        case Token::Mod: case Token::AssignMod: return cast.OP_MOD;
        case Token::Equal: return cast.OP_EQ;
        case Token::NotEqual: return cast.OP_NE;
        case Token::LessThan: return cast.OP_LT;
        case Token::LessThanOrEqual: return cast.OP_LE;
        case Token::GreaterThan: return cast.OP_GT;
        case Token::GreaterThanOrEqual: return cast.OP_GE;
        case Token::BitXor: case Token::AssignBitXor: return cast.OP_BIT_XOR;
        case Token::BitOr: case Token::AssignBitOr: return cast.OP_BIT_OR;
        case Token::BitAnd: case Token::AssignBitAnd: return cast.OP_BIT_AND;
        case Token::SHL: case Token::AssignShl: return cast.OP_LSH;
        case Token::SHR: case Token::AssignShr: return cast.OP_URSH;
        case Token::SAR: case Token::AssignSar: return cast.OP_RSH;
        default: return NULL;
    }
 }

bool Translator::visit(const Assignment &_node) {
    _node.leftHandSide().accept(*this);
    jobject lhs = last();

    _node.rightHandSide().accept(*this);
    jobject rhs = last();

    Token op = _node.assignmentOperator();
    
    ret(record((op == Token::Assign?
               cast.makeNode(cast.ASSIGN, lhs, rhs):
               cast.makeNode(cast.ASSIGN_POST_OP, lhs, rhs, translateOpcode(cast, op))),
            _node.location(), _node.annotation().type));
    return false;
}

bool Translator::visit(const BinaryOperation &_node) {
    _node.leftExpression().accept(*this);
    jobject left = last();

    _node.rightExpression().accept(*this);
    jobject right = last();

    jobject expr;
    if (_node.getOperator() == Token::And) {
        expr = cast.makeNode(cast.IF_EXPR, left, right, cast.makeConstant(false));
    } else if (_node.getOperator() == Token::Or) {
        expr = cast.makeNode(cast.IF_EXPR, left, cast.makeConstant(true), right);
    } else {
        jobject op = translateOpcode(cast, _node.getOperator());
        expr = cast.makeNode(cast.BINARY_EXPR, op, left, right);
    }
    
    ret(record(expr, _node.location(), _node.annotation().type));
    
    return false;
}

bool Translator::visit(const Block &_node) {
    const std::vector<ASTPointer<Statement>> nodes = _node.statements();
    int len = (int)nodes.size();
    jclass cnc = jniEnv->FindClass("com/ibm/wala/cast/tree/CAstNode");
    jobjectArray children = jniEnv->NewObjectArray(len, cnc, NULL);

    int i = 0;
    for (std::vector<ASTPointer<Statement>>::const_iterator t=nodes.begin();
         t != nodes.end();
         ++t, i++)
    {
        t->get()->accept(*this);
        jniEnv->SetObjectArrayElement(children, i, last());
    }
    
    ret(record(cast.makeNode(cast.BLOCK_STMT, children), _node.location()));
    return false;
 }

bool Translator::visit(const ElementaryTypeName &_node) {
    ret(record(cast.makeNode(cast.TYPE_LITERAL_EXPR, cast.makeConstant(_node.typeName().toString(true).c_str())), _node.location()));
    return false;
}

bool Translator::visit(const ElementaryTypeNameExpression &_node) {
    _node.type().accept(*this);
    return false;
}

bool Translator::visit(const EmitStatement &_node) {
    _node.eventCall().accept(*this);
    return false;
}

jobject Translator::visitCall(const CallableDeclaration &_node, jobject retType, bool isCtor) {
     const std::vector<ASTPointer<VariableDeclaration>> parameters = _node.parameters();
    std::cout << _node.name() << std::endl;
    jstring funName = jniEnv->NewStringUTF(isCtor? "<init>": _node.name().c_str());
 
    int i = 0;
    int len = (int)parameters.size();
    jclass ctc = jniEnv->FindClass("com/ibm/wala/cast/tree/CAstType");
    jobjectArray children = jniEnv->NewObjectArray(len, ctc, NULL);
    for (std::vector<ASTPointer<VariableDeclaration>>::const_iterator t=parameters.begin();
         t != parameters.end();
         ++t, i++)
    {
        jobject type = getType(t->get()->type());
        jniEnv->SetObjectArrayElement(children, i, type);
    }
 
    std::cout << "ft 1:" << _node.name().c_str() << std::endl;

    jobject selfType = context->type();
    
    std::cout << "ft 2:" << _node.name().c_str() << std::endl;
    std::cout << funName << endl;
    print(funName);
    print(selfType);

    jclass sft = jniEnv->FindClass("com/certora/wala/cast/solidity/loader/FunctionType");
    jmethodID sfCtor = jniEnv->GetStaticMethodID(sft, "findOrCreate", "(Ljava/lang/String;Lcom/ibm/wala/cast/tree/CAstType;Lcom/ibm/wala/cast/tree/CAstType;[Lcom/ibm/wala/cast/tree/CAstType;)Lcom/certora/wala/cast/solidity/loader/FunctionType;");
    jobject funType = jniEnv->CallStaticObjectMethod(sft, sfCtor, funName, selfType, retType, children);
    std::cout << "ft 3:" << _node.name().c_str() << std::endl;

    jobject loc = makePosition(_node.location());
    
    jobject nameLoc = makePosition(_node.nameLocation());

    std::cout << "ft 4:" << _node.name().c_str() << std::endl;

    i = 0;
    jclass jsc = jniEnv->FindClass("java/lang/String");
    jclass wpc = jniEnv->FindClass("Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;");
    jobjectArray argNames = jniEnv->NewObjectArray(len, jsc, NULL);
    jobjectArray argLocations = jniEnv->NewObjectArray(len, wpc, NULL);
    for (std::vector<ASTPointer<VariableDeclaration>>::const_iterator t=parameters.begin();
         t != parameters.end();
         ++t, i++)
    {
        jniEnv->SetObjectArrayElement(argNames, i, jniEnv->NewStringUTF(t->get()->name().c_str()));
        jniEnv->SetObjectArrayElement(argLocations, i, makePosition(t->get()->location()));
    }
    std::cout << "ft 5:" << _node.name().c_str() << std::endl;

    jobject qual;
    if (isCtor) {
        qual = cast.PUBLIC;
    } else {
        switch (_node.visibility()) {
            case Visibility::Default:
            case Visibility::Private:
                qual = cast.PRIVATE;
                break;
            case Visibility::Internal:
                qual = cast.PROTECTED;
                break;
            case Visibility::Public:
            case Visibility::External:
                qual = cast.PUBLIC;
        }
    }
 
    jclass sfet = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/FunctionEntity");
    jmethodID sfeCtor = jniEnv->GetMethodID(sfet, "<init>", "(Ljava/lang/String;Lcom/ibm/wala/cast/tree/CAstType$Function;[Ljava/lang/String;Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;[Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;Lcom/ibm/wala/cast/tree/CAstQualifier;Lcom/ibm/wala/cast/tree/CAstNode;)V");
    
    return jniEnv->NewObject(sfet, sfeCtor, funName, funType, argNames, loc, nameLoc, argLocations,qual, NULL);
}

bool Translator::visit(const EnumDefinition &_node) {
    jstring enumName = jniEnv->NewStringUTF(((TypeType*)_node.type())->actualType()->toString(true).c_str());
    // jniEnv->NewStringUTF(_node.name().c_str());
    
    jclass sCls = jniEnv->FindClass("java/util/HashSet");
    jmethodID sCtor = jniEnv->GetMethodID(sCls, "<init>", "()V");
    jmethodID add = jniEnv->GetMethodID(sCls, "add", "(Ljava/lang/Object;)Z");
    jobject membersSet = jniEnv->NewObject(sCls, sCtor);

    std::vector<ASTPointer<EnumValue>> const& elts = _node.members();
    for (std::vector<ASTPointer<EnumValue>>::const_iterator t=elts.begin();
         t != elts.end();
         ++t) {
        jniEnv->CallBooleanMethod(membersSet, add, jniEnv->NewStringUTF(t->get()->name().c_str()));
    }

    jclass ctCls = jniEnv->FindClass("com/certora/wala/cast/solidity/loader/EnumType");
    jmethodID ctCtor = jniEnv->GetMethodID(ctCls, "<init>", "(Ljava/lang/String;Ljava/util/Collection;)V");
    jniEnv->NewObject(ctCls, ctCtor, enumName, membersSet);
    
    return false;
}

bool Translator::visit(const ErrorDefinition &_node) {
    jobject funEntity = visitCall(_node, NULL, false);
    
    jstring funName = jniEnv->NewStringUTF(_node.name().c_str());

    context->registerFunction(funName, funEntity);

     return false;
}

bool Translator::visit(const EventDefinition &_node) {
    jobject funEntity = visitCall(_node, NULL, false);
    
    jstring funName = jniEnv->NewStringUTF(_node.name().c_str());

    context->registerFunction(funName, funEntity);

     return false;
}

bool Translator::visit(const ExpressionStatement &_node) {
    _node.expression().accept(*this);
    jobject expr = last();
    
    ret(record(cast.makeNode(cast.EXPR_STMT, expr), _node.location(), _node.expression().annotation().type));
    
    return false;
}

bool Translator::visit(const ForStatement &_node) {
    jobject stuff = NULL;
    if (_node.initializationExpression()) {
        _node.initializationExpression()->accept(*this);
        stuff = last();
    }
    
    _node.condition()->accept(*this);
    jobject test = last();
    
    _node.loopExpression()->accept(*this);
    jobject update = last();
    
    _node.body().accept(*this);
    jobject body = last();
    
    jobject loop = record(cast.makeNode(cast.LOOP, test, cast.makeNode(cast.BLOCK_STMT, body, update)), _node.location());
    
    if (stuff == NULL) {
        ret(loop);
    } else {
        ret(record(cast.makeNode(cast.BLOCK_STMT, stuff, loop), _node.location()));
    }
    
    return false;
}

bool Translator::visit(const FunctionCall &_node) {
    _node.expression().accept(*this);
    jobject fun = last();
 
    int i = 1;
    std::cout << "***" << _node.location().start << std::endl;
    std::cout << "***" << typeid(_node.expression()).name() << std::endl;
 std::vector<ASTPointer<const Expression>> args = _node.arguments();
    int len = (int)args.size();
    jclass cnc = jniEnv->FindClass("com/ibm/wala/cast/tree/CAstNode");
    jobjectArray children = jniEnv->NewObjectArray(len+1, cnc, NULL);
    jniEnv->SetObjectArrayElement(children, 0, cast.makeNode(cast.EMPTY));
   for (std::vector<ASTPointer<const Expression>>::const_iterator t=args.begin();
         t != args.end();
         ++t, i++)
    {
        std::cout << "***" << typeid(*t->get()).name() << std::endl;
        t->get()->accept(*this);
        jniEnv->SetObjectArrayElement(children, i, last());
    }

    ret(record(cast.makeNode(cast.CALL, fun, children), _node.location(), _node.annotation().type));
    return false;
}

class CodeContext : public virtual VariableContainerContext, public virtual EntityContext {
public:
    CodeContext(jobject entity, DelegatingContext *parent) : DelegatingContext(parent), EntityContext(entity, parent), VariableContainerContext(parent) {}
};

bool Translator::visit(const FunctionDefinition &_node) {
    jobject retType = NULL;
    const std::vector<ASTPointer<VariableDeclaration>> rets = _node.returnParameters();
    if (rets.size() == 0) {
        // void function
    } else if (rets.size() == 1) {
        Type const * retTypeName = rets[0].get()->type();
         retType = getType(retTypeName);
    } else {
        std::cout << "ret " << rets.size() << std::endl;
        showStackTrace();
        // todo
    }
    
    jobject funEntity = visitCall(_node, retType, _node.isConstructor());
 
    jclass sfet = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/FunctionEntity");
    jmethodID feaq = jniEnv->GetMethodID(sfet, "addQualifier", "(Lcom/ibm/wala/cast/tree/CAstQualifier;)V");
    if (_node.stateMutability() == StateMutability::Pure) {
        jniEnv->CallVoidMethod(funEntity, feaq, cast.PURE);
    } else if (_node.stateMutability() == StateMutability::View) {
        jniEnv->CallVoidMethod(funEntity, feaq, cast.CONST);
    }
    std::cout << "got here 1" << std::endl;
    
    context = new CodeContext(funEntity, context);

    std::cout << "got here 2" << std::endl;
    
    if (_node.isImplemented()) {
        std::cout << _node.name() << std::endl;
        _node.body().accept(*this);
    }
    
   return false;
}

void Translator::endVisit(const FunctionDefinition &_node) {
    jobject funEntity = context->entity();
    if (_node.isImplemented()) {
        jobject ast = last();
        ASTPointer<ParameterList> retp = _node.returnParameterList();
        std::vector<jobject> retvals;
        const ParameterList &ret = *retp.get();
        std::vector<ASTPointer<VariableDeclaration>> const& retps = ret.parameters();
        int i = 0;
        for (std::vector<ASTPointer<VariableDeclaration>>::const_iterator t=retps.begin();
             t != retps.end();
             ++t, i++)
        {
            if (t->get()->name().c_str() != NULL && strlen(t->get()->name().c_str()) > 0) {
                jobject type = getType(t->get()->type());
                retvals.push_back(cast.makeNode(cast.VAR, cast.makeConstant(t->get()->name().c_str())));
                jobject symbol = cast.makeSymbol(t->get()->name().c_str(), type, false);
                ast = cast.makeNode(cast.BLOCK_STMT,
                                    record(cast.makeNode(cast.DECL_STMT, cast.makeConstant(symbol)), t->get()->location()),
                                    ast);
            }
        }
        
        if (retvals.size() > 0) {
            i = 0;
            int len = retvals.size();
            jclass cnc = jniEnv->FindClass("com/ibm/wala/cast/tree/CAstNode");
            jobjectArray args = jniEnv->NewObjectArray(len, cnc, NULL);
            for (std::vector<jobject>::const_iterator t=retvals.begin();
                 t != retvals.end();
                 ++t, i++)
            {
                jniEnv->SetObjectArrayElement(args, i, *t);
            }
            
            ast = cast.makeNode(cast.BLOCK_STMT, ast, cast.makeNode(cast.RETURN, args));
        }
        
        jclass ace = jniEnv->FindClass("com/ibm/wala/cast/ir/translator/AbstractCodeEntity");
        jmethodID aceSetAst = jniEnv->GetMethodID(ace, "setAst", "(Lcom/ibm/wala/cast/tree/CAstNode;)V");
        jniEnv->CallVoidMethod(funEntity, aceSetAst, ast);
    }
    
    context = context->parent();
    
    jstring funName = jniEnv->NewStringUTF(_node.isConstructor()? "<init>": _node.name().c_str());
    context->registerFunction(funName, funEntity);
 }

jobjectArray Translator::getCAstTypes(const std::vector<ASTPointer<VariableDeclaration>>& ts) {
        jobjectArray result = jniEnv->NewObjectArray(ts.size(), jniEnv->FindClass("com/ibm/wala/cast/tree/CAstType"), NULL);
        int i = 0;
        for (std::vector<ASTPointer<VariableDeclaration>>::const_iterator t=ts.begin();
             t != ts.end();
             ++t, i++)
        {
            jobject pt = getType(t->get()->type());
            jniEnv->SetObjectArrayElement(result, i, pt);
        }
        
        return result;
}

jobject Translator::getSelfType() {
    jobject methodType = cast.getEntityType(context->entity());
    jclass mtc = jniEnv->FindClass("com/ibm/wala/cast/tree/CAstType$Method");
    jmethodID gdc = jniEnv->GetMethodID(mtc, "getDeclaringType", "()Lcom/ibm/wala/cast/tree/CAstType;");
    return jniEnv->CallObjectMethod(methodType, gdc);
}

jobject Translator::getSolidityFunctionType(const char *name, jobjectArray params, jobjectArray returns, bool event) {
    jclass sfc = jniEnv->FindClass("com/certora/wala/cast/solidity/loader/FunctionType");
    jmethodID sfctor = jniEnv->GetStaticMethodID(sfc, "findOrCreate", "(Ljava/lang/String;Lcom/ibm/wala/cast/tree/CAstType;[Lcom/ibm/wala/cast/tree/CAstType;[Lcom/ibm/wala/cast/tree/CAstType;)Lcom/certora/wala/cast/solidity/loader/FunctionType;");
    return jniEnv->CallStaticObjectMethod(sfc, sfctor, jniEnv->NewStringUTF(name), getSelfType(), returns, params);
}

jobject Translator::getSolidityFunctionType(const CallableDeclaration* var, bool event) {
    jobjectArray ps = getCAstTypes(var->parameters());
    jobjectArray rs = var->returnParameters().size() > 0? getCAstTypes(var->returnParameters()): NULL;
    const char *nm = var->name().c_str();
    return getSolidityFunctionType(nm, ps, rs, event);
}

jobject Translator::getSelfPtr() {
    jobject thisPtr = cast.makeNode(cast.THIS);
    jobject methodType = cast.getEntityType(context->entity());
    cast.setAstNodeType(context->entity(), thisPtr, methodType);
    jobject selfPtr = cast.makeNode(cast.OBJECT_REF, thisPtr, cast.makeConstant("self"));
    cast.setAstNodeType(context->entity(), selfPtr, getSelfType());
    return selfPtr;
}

bool Translator::visit(const Identifier &_node) {
    if (VariableDeclaration const* var = dynamic_cast<VariableDeclaration const*>(_node.annotation().referencedDeclaration)) {
        if (var->isStateVariable()) {
            jobject selfPtr = getSelfPtr();
              ret(record(cast.makeNode(cast.OBJECT_REF, selfPtr, cast.makeConstant(_node.name().c_str())),   _node.location(), _node.annotation().type));
            return false;
        } else if (var->isLocalVariable()) {
            ret(record(cast.makeNode(cast.VAR, cast.makeConstant(_node.name().c_str())), _node.location(), _node.annotation().type));
            return false;
        }
                
    } else if (FunctionDefinition const* var = dynamic_cast<FunctionDefinition const*>(_node.annotation().referencedDeclaration)) {
        jobject fun = getSolidityFunctionType(var->name().c_str(), getCAstTypes(var->parameters()), getCAstTypes(var->returnParameters()), false);
        jobject selfPtr = getSelfPtr();
        jobject retVal = record(cast.makeNode(cast.OBJECT_REF, selfPtr, cast.makeConstant(_node.name().c_str())), _node.location());
        cast.setAstNodeType(context->entity(), retVal, fun);
        ret(retVal);
        return false;

    } else if (CallableDeclaration const* var = dynamic_cast<CallableDeclaration const*>(_node.annotation().referencedDeclaration)) {
        jobject fun = getSolidityFunctionType(var->name().c_str(), getCAstTypes(var->parameters()), NULL, true);
        jobject selfPtr = getSelfPtr();
        jobject retVal = record(cast.makeNode(cast.OBJECT_REF, selfPtr, cast.makeConstant(_node.name().c_str())), _node.location());
        cast.setAstNodeType(context->entity(), retVal, fun);
        ret(retVal);
        return false;

    } else if (MagicVariableDeclaration const* var = dynamic_cast<MagicVariableDeclaration const*>(_node.annotation().referencedDeclaration)) {
        ret(record(cast.makeNode(cast.PRIMITIVE, cast.makeConstant(_node.name().c_str())), _node.location(), var->type()));
        return false;
        
    } else if (ContractDefinition const* var = dynamic_cast<ContractDefinition const*>(_node.annotation().referencedDeclaration)) {
        const Type *ct = ((TypeType*)var->type())->actualType();
        ret(record(cast.makeNode(cast.TYPE_LITERAL_EXPR, cast.makeConstant(ct->toString(true).c_str())), _node.location(), var->type()));
        return false;
        
    } else if (StructDefinition const* var = dynamic_cast<StructDefinition const*>(_node.annotation().referencedDeclaration)) {
         const Type *ct = ((TypeType*)var->type())->actualType();
         ret(record(cast.makeNode(cast.TYPE_LITERAL_EXPR, cast.makeConstant(ct->toString(true).c_str())), _node.location(), var->type()));
         return false;
    }

    
    std::cout << "returning empty" << std::endl;
    ret(cast.makeNode(cast.EMPTY));
    return true;
}

bool Translator::visit(const IdentifierPath &_node) {
    return visitNode(_node);
}

bool Translator::visit(const IfStatement &_node) {
    _node.condition().accept(*this);
    jobject cond = last();
    
    _node.trueStatement().accept(*this);
    jobject then = last();

    if (_node.falseStatement() != NULL) {
        _node.falseStatement()->accept(*this);
        jobject otherwise = last();
        
        ret(record(cast.makeNode(cast.IF_STMT, cond, then, otherwise), _node.location()));
    } else {
        ret(record(cast.makeNode(cast.IF_STMT, cond, then), _node.location()));
    }
    
    return false;
}

bool Translator::visit(const ImportDirective &_node) {
    // handled by the ConpilerStack resolving imports
    return false;
}

bool Translator::visit(const IndexAccess &_node) {
    _node.baseExpression().accept(*this);
    jobject obj = last();
    
    _node.indexExpression()->accept(*this);
    jobject idx = last();

    const Type *eltType = _node.annotation().type;
    
    jobject ref = cast.makeNode(cast.ARRAY_REF, obj, cast.makeConstant(getType(eltType)), idx);
    
    ret(record(ref, _node.location(), eltType));
    return false;
}

bool Translator::visit(const InheritanceSpecifier &_node) {
    
    const Declaration *d = _node.name().annotation().referencedDeclaration;
    std::cout << d << std::endl;
    const Type *st = ((TypeType*)d->type())->actualType();
    std::cout << st << std::endl;
    std::cout << "super: " << st->toString(true) << std::endl;
    context->addSuperclass(st->toString(true));

                           /*
    std::string typeName = "";
    const std::vector<ASTString> names = _node.name().path();
    for (std::vector<ASTString>::const_iterator t = names.begin();
         t != names.end();
         ++t)
    {
        typeName += t->data();
    }

    context->addSuperclass(typeName);
    */
                           
    return false;
}

bool Translator::visit(const InlineAssembly &_node) {
    solidity::yul::AST const& ast = _node.operations();
    ret(cast.makeNode(cast.EMPTY));
    return false;
}

bool Translator::visit(const Literal &_node) {
    Type const* type = _node.annotation().type;
    switch (type->category())
    {
        case Type::Category::RationalNumber:
        case Type::Category::Bool:
        case Type::Category::Address:
            ret(cast.makeConstant((long)type->literalValue(&_node)));
            break;
        case Type::Category::StringLiteral:
            ret(cast.makeConstant(_node.value().c_str()));
            break;
        default:
            ret(cast.makeNode(cast.EMPTY));
    }
    return false;
}

bool Translator::visit(const Mapping &_node) {
    return visitNode(_node);
}

bool Translator::visit(const MemberAccess &_node) {
    std::cout << "***" << typeid(_node.annotation().referencedDeclaration).name() << std::endl;

    _node.expression().accept(*this);
    jobject obj = last();
    
    jobject elt = cast.makeConstant( _node.memberName().c_str() );
    jobject ref = cast.makeNode(cast.OBJECT_REF, obj, elt);
   if (FunctionDefinition const* var = dynamic_cast<FunctionDefinition const*>(_node.annotation().referencedDeclaration)) {
       std::cout << "got here" << var->name() << std::endl;
        jobject fun = getSolidityFunctionType(var, false);
       cast.setAstNodeType(context->entity(), ref, fun);
       ret(record(ref, _node.location()));
    } else {
        ret(record(ref, _node.location(), _node.annotation().type));
    }
    return false;
}

bool Translator::visit(const ModifierDefinition &_node) {
    jobject funEntity = visitCall(_node, NULL, false);

    context = new CodeContext(funEntity, context);

   _node.body().accept(*this);
   
   return false;
}

void Translator::endVisit(const ModifierDefinition &_node) {
    int i = 0;
    jobject ast = last();
    jobject funEntity = context->entity();
    
    jclass ace = jniEnv->FindClass("com/ibm/wala/cast/ir/translator/AbstractCodeEntity");
    jmethodID aceSetAst = jniEnv->GetMethodID(ace, "setAst", "(Lcom/ibm/wala/cast/tree/CAstNode;)V");
    jniEnv->CallVoidMethod(funEntity, aceSetAst, ast);
    
    context = context->parent();
    
    jstring funName = jniEnv->NewStringUTF(_node.name().c_str());
    context->registerFunction(funName, funEntity);
    
    showStackTrace();
}

bool Translator::visit(const ModifierInvocation &_node) {
    return visitNode(_node);
}

bool Translator::visit(const ParameterList &_node) {
    return visitNode(_node);
}

bool Translator::visit(const PragmaDirective &_node) {
    return false;
}

bool Translator::visit(const Return &_node) {
    if (_node.expression() != NULL) {
        _node.expression()->accept(*this);
        jobject val = last();
        ret(record(cast.makeNode(cast.RETURN, val), _node.location()));
    } else {
        ret(record(cast.makeNode(cast.RETURN), _node.location()));
    }
    return false;
}

bool Translator::visit(const RevertStatement &_node) {
    _node.errorCall().accept(*this);
    ret(record(cast.makeNode(cast.THROW, last()), _node.location()));
    return false;
}

bool Translator::visit(const StructDefinition &_node) {
    context = new VariableContainerContext(context);
    return true;
}

void Translator::endVisit(const StructDefinition &_node) {
    
    jclass sCls = jniEnv->FindClass("java/util/HashSet");
    jmethodID sCtor = jniEnv->GetMethodID(sCls, "<init>", "()V");
    jmethodID add = jniEnv->GetMethodID(sCls, "add", "(Ljava/lang/Object;)Z");
    jobject entitiesSet = jniEnv->NewObject(sCls, sCtor);
    std::map<jstring, jobject>& fields = context->variables();
    for (std::map<jstring,jobject>::iterator t=fields.begin();
         t != fields.end();
         ++t)
    {
        jniEnv->CallBooleanMethod(entitiesSet, add, t->second);
    }

    jclass ctCls = jniEnv->FindClass("com/certora/wala/cast/solidity/loader/StructType");
    jmethodID ctCtor = jniEnv->GetMethodID(ctCls, "<init>", "(Ljava/lang/String;)V");
    jstring entityName = jniEnv->NewStringUTF(((TypeType*)_node.type())->actualType()->toString(true).c_str());

    jobject structType = jniEnv->NewObject(ctCls, ctCtor, entityName);
    types[_node.name()] = structType;

    jclass seCls = jniEnv->FindClass("com/certora/wala/cast/solidity/tree/ContractEntity");
    jmethodID seCtor = jniEnv->GetMethodID(seCls, "<init>", "(Lcom/ibm/wala/cast/tree/CAstType$Class;Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;Ljava/util/Set;)V");
    jobject structEntity = jniEnv->NewObject(seCls, seCtor, structType, makePosition(_node.location()), makePosition(_node.nameLocation()), entitiesSet);
    
    context = context->parent();
    
    cast.addChildEntity(context->entity(), NULL, structEntity);
}

bool Translator::visit(const StructuredDocumentation &_node) {
    return false;
}

bool Translator::visit(const TryStatement &_node) {
    _node.externalCall().accept(*this);
    jobject call = last();
    jobject stmt = call;
    
    TryCatchClause const *sc = _node.successClause();
    if (sc != NULL) {
        ParameterList const *ps = sc->parameters();
        
        if (ps != NULL) {
            std::vector<ASTPointer<VariableDeclaration>> const& params = ps->parameters();
            for (std::vector<ASTPointer<VariableDeclaration>>::const_iterator t=params.begin();
                 t != params.end();
                 ++t)
            {
                jobject symbol = cast.makeSymbol(t->get()->name().c_str(), getType(t->get()->type()));
                call = cast.makeNode(cast.BLOCK_EXPR, cast.makeNode(cast.DECL_STMT, cast.makeConstant(symbol)), call);
            }
            
            if (ps->parameters().size() == 1) {
                call = cast.makeNode(cast.ASSIGN,
                    cast.makeNode(cast.VAR, cast.makeConstant(ps->parameters()[0]->name().c_str())),
                    call);
            } else {
                
            }
        }
        sc->block().accept(*this);
        jobject tryBlock = last();
        stmt = cast.makeNode(cast.BLOCK_STMT, call, tryBlock);
    }
    
    if (_node.panicClause() != NULL) {
        _node.panicClause()->accept(*this);
        stmt = cast.makeNode(cast.TRY, stmt, last());
    }
    
    if (_node.errorClause() != NULL) {
        _node.errorClause()->accept(*this);
        stmt = cast.makeNode(cast.TRY, stmt, last());
    }
 
    if (_node.fallbackClause() != NULL) {
        _node.fallbackClause()->accept(*this);
        stmt = cast.makeNode(cast.TRY, stmt, last());
    }

    ret(record(stmt, _node.location()));
    
    return false;
}

bool Translator::visit(const TryCatchClause &_node) {
    int i = 0;
    _node.block().accept(*this);
    jobject body = last();
    if (_node.parameters() != NULL) {
        std::vector<ASTPointer<VariableDeclaration>> const& params = _node.parameters()->parameters();
        jobjectArray elts = jniEnv->NewObjectArray(params.size() + 1, jniEnv->FindClass("com/ibm/wala/cast/tree/CAstNode"), NULL);
        for (std::vector<ASTPointer<VariableDeclaration>>::const_iterator t=params.begin();
             t != params.end();
             ++t, i++)
        {
            jniEnv->SetObjectArrayElement(elts, i,
                                          cast.makeNode(cast.ASSIGN,
                                                        cast.makeNode(cast.VAR, cast.makeConstant(t->get()->name().c_str())),
                                                        cast.makeNode(cast.OBJECT_REF, cast.makeNode(cast.VAR, cast.makeConstant("e")), cast.makeConstant(t->get()->name().c_str()))));
        }
        
        jniEnv->SetObjectArrayElement(elts, i, body);
        
        ret(record(cast.makeNode(cast.CATCH, cast.makeConstant("e"), cast.makeNode(cast.BLOCK_STMT, elts)), _node.location()));
    } else {
        ret(record(cast.makeNode(cast.CATCH, cast.makeConstant("e"), cast.makeNode(cast.BLOCK_STMT, body)), _node.location()));
    }
    
    return false;
}

bool Translator::visit(const TupleExpression &_node) {
    if (_node.components().size() == 1) {
        _node.components().at(0)->accept(*this);
        return false;
    } else {
        return visitNode(_node);
    }
}

bool Translator::visit(const UnaryOperation &_node) {
    _node.subExpression().accept(*this);
    jobject expr = last();

    jobject op = translateOpcode(cast, _node.getOperator());
    
    expr = cast.makeNode(cast.UNARY_EXPR, op, expr);
    ret(record(expr, _node.location(), _node.annotation().type));
    
    return false;
}

bool Translator::visit(const UserDefinedTypeName &_node) {
    return visitNode(_node);
}

bool Translator::visit(const UserDefinedValueTypeDefinition &_node) {
    Type const* solType = _node.type();
    jobject castType = getType(solType);
    
    std::string name = _node.name();
    
    std::cout << "****" << name << castType << std::endl;
    
    return false;
}

bool Translator::visit(const UsingForDirective &_node) {
    return false;
}

bool Translator::visit(const VariableDeclaration &_node) {
    showStackTrace();
    
    jobject type = getType(_node.type());
    
    jobject loc = makePosition(_node.location());
    
    const char *name = _node.name().c_str();
    
    bool isFinal = _node.isConstant();
    
     if (_node.isStateVariable() || _node.isStructMember()) {
        jobject jname = cast.makeConstant(name);
        jobject loc = makePosition(_node.location());
        jobject nameLoc = makePosition(_node.nameLocation());
        jobject field = cast.makeFieldEntity(context->entity(), jname, type, false, loc, nameLoc, NULL);
        context->registerVariable(jniEnv->NewStringUTF(name), field);
        
    } else {
        jobject symbol = cast.makeSymbol(name, type, isFinal);
        
        jobject value = NULL;
        if (_node.value() != NULL) {
            _node.value()->accept(*this);
            value = last();
        }

        if (value != NULL) {
            ret(record(cast.makeNode(cast.DECL_STMT, cast.makeConstant(symbol), value), _node.location(), _node.type()));
        } else {
            ret(record(cast.makeNode(cast.DECL_STMT, cast.makeConstant(symbol)), _node.location(), _node.type()));
        }
    }
     
    return false;
}

bool Translator::visit(const VariableDeclarationStatement &_node) {
    jobject val = NULL;
    if (_node.initialValue()) {
        _node.initialValue()->accept(*this);
        val = last();
    }
    
    int i = 0;
    const std::vector<ASTPointer<VariableDeclaration>> names = _node.declarations();
    jobjectArray elts = jniEnv->NewObjectArray(names.size(), jniEnv->FindClass("com/ibm/wala/cast/tree/CAstNode"), NULL);
    for (std::vector<ASTPointer<VariableDeclaration>>::const_iterator t = names.begin();
         t != names.end();
         ++t, ++i)
    {
        if (t->get()) {
            t->get()->accept(*this);
            jobject v = last();
            jniEnv->SetObjectArrayElement(elts, i, v);
        } else {
            jniEnv->SetObjectArrayElement(elts, i, cast.makeNode(cast.EMPTY));
        }
    }
    
    if (val != NULL) {
        ret(record(cast.makeNode(cast.BLOCK_STMT, val, elts), _node.location()));\
    }  else {
        ret(record(cast.makeNode(cast.BLOCK_STMT, elts), _node.location()));
    }
    
    return false;
}
