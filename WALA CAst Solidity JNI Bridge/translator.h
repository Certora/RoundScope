//
//  translator.h
//  WALA CAst Solidity
//
//  Created by Julian Dolby on 12/19/25.
//

#include "solidityBridge.h"
#include <jni.h>

#include "CAstWrapper.h"

using namespace solidity::frontend;

extern std::map<std::string, jobject> types;

class DelegatingContext {
private:
    DelegatingContext *_parent;
    
protected:
    DelegatingContext(DelegatingContext *parent) : _parent(parent) { }
    
public:
    virtual DelegatingContext *parent() { return _parent; }
    
    virtual jobject type() {
        return parent()->type();
    }
    
    virtual jobject entity() {
        return parent()->entity();
    }
    virtual void addSuperclass(std::string superType) {
        parent()->addSuperclass(superType);
    }
    
    virtual jobject& superClasses() {
        return parent()->superClasses();
    }
    
    virtual void registerFunction(jstring name, jobject fun) {
        parent()->registerFunction(name, fun);
    }
    
    virtual void registerVariable(jstring name, jobject var) {
        parent()->registerVariable(name, var);
    }
    
    virtual std::map<jstring, jobject>& functions() {
        return parent()->functions();
    }
    
    virtual std::map<jstring, jobject>& variables() {
        return parent()->variables();
    }
};

class EntityContext : public virtual DelegatingContext {
private:
    jobject _entity;
    
public:
    EntityContext(jobject entity, DelegatingContext *parent) : _entity(entity), DelegatingContext(parent) { }
    
    virtual jobject entity() {
        return _entity;
    }
    
};

class FunctionContainerContext : public virtual DelegatingContext {
private:
    std::map<jstring, jobject> functionContainer;
 
public:
    FunctionContainerContext(DelegatingContext *parent) : DelegatingContext(parent) { }
    
    virtual void registerFunction(jstring name, jobject fun) {
        functionContainer[name] = fun;
    }
    
    virtual std::map<jstring, jobject>& functions() {
        return functionContainer;
    }
};

class VariableContainerContext  : public virtual DelegatingContext {
private:
    std::map<jstring, jobject> variableContainer;
 
public:
    VariableContainerContext(DelegatingContext *parent) : DelegatingContext(parent) { }
    
    virtual void registerVariable(jstring name, jobject fun) {
        variableContainer[name] = fun;
    }
    
    virtual std::map<jstring, jobject>& variables() {
        return variableContainer;
    }
};

class RootContext : virtual public EntityContext, virtual public DelegatingContext  {
public:
    RootContext(jobject entity) : EntityContext(entity, NULL), DelegatingContext(NULL) { }
};

class Translator : public ASTConstVisitor {
private:
    JNIEnv *jniEnv;
    CAstWrapper cast;
    const char *fileName;
    jobject xlator;
    
    DelegatingContext *context;
    
    jobject tree;
    
    void ret(jobject v) {
        tree = v;
    }
    
    int level;
    
    void indent() {
        for(int i = 0; i < level; i++) {
            std::cout << " ";
        }
    }
    
    jobject print(jobject v) {
        jclass obj = jniEnv->FindClass("java/lang/Object");
        jmethodID toString = jniEnv->GetMethodID(obj, "toString", "()Ljava/lang/String;");
        std::cout << jniEnv->GetStringUTFChars((jstring)jniEnv->CallObjectMethod(v, toString), 0);
        return v;
    }
    
    jobject makePosition(const solidity::frontend::ASTNode::SourceLocation& loc) {
        jclass type = jniEnv->GetObjectClass(xlator);
        jmethodID mp = jniEnv->GetMethodID(type, "makePosition", "(Ljava/lang/String;II)Lcom/ibm/wala/cast/tree/CAstSourcePositionMap$Position;");
        return jniEnv->CallObjectMethod(xlator, mp, jniEnv->NewStringUTF(fileName), loc.start, loc.end);
    }
    
    jobject record(jobject castNode, const solidity::frontend::ASTNode::SourceLocation& loc, Type const* type) {
        cast.setAstNodeType(context->entity(), castNode, getType(type));
        return record(castNode, loc);
    }
    
    jobject record(jobject castNode, const solidity::frontend::ASTNode::SourceLocation& loc) {
        cast.setAstNodeLocation(context->entity(), castNode, makePosition(loc));
        return castNode;
    }
    
    jobject getType(std::string type);
    jobject getType(Type const* type);

    jobjectArray getCAstTypes(const std::vector<ASTPointer<VariableDeclaration>>&);
    jobject getSolidityFunctionType(const char *, jobjectArray, jobjectArray, bool);
    jobject getSolidityFunctionType(const CallableDeclaration*, bool);
    jobject visitCall(const CallableDeclaration &, jobject, bool);
    
public:
    jobject last() {
        return tree;
    }

    Translator(const char *fileName, JNIEnv *env, Exceptions& ex, jobject xlator, jobject fileEntity) :
        fileName(fileName), cast(env, ex, xlator), jniEnv(env), xlator(xlator), level(0), context(new RootContext(fileEntity)) { }
    
    virtual bool visitNode(ASTNode const&) override;
    virtual void endVisitNode(ASTNode const&_node) override;

    virtual bool visit(const Assignment &_node) override;
    virtual bool visit(const BinaryOperation &_node) override;
    virtual bool visit(const Block &_node) override;
    virtual bool visit(const ContractDefinition &_node) override;
    virtual void endVisit(const ContractDefinition &_node) override;
    virtual bool visit(const ElementaryTypeName &_node) override;
    virtual bool visit(const ElementaryTypeNameExpression &_node) override;
    virtual bool visit(const EmitStatement &_node) override;
    virtual bool visit(const EventDefinition &_node) override;
    virtual bool visit(const ExpressionStatement &_node) override;
    virtual bool visit(const FunctionCall &_node) override;
    virtual bool visit(const FunctionDefinition &_node) override;
    virtual void endVisit(const FunctionDefinition &_node) override;
    virtual bool visit(const Identifier &_node) override;
    virtual bool visit(const IdentifierPath &_node) override;
    virtual bool visit(const IfStatement &_node) override;
    virtual bool visit(const ImportDirective &_node) override;
    virtual bool visit(const IndexAccess &_node) override;
    virtual bool visit(const InheritanceSpecifier &_node) override;
    virtual bool visit(const Literal &_node) override;
    virtual bool visit(const Mapping &_node) override;
    virtual bool visit(const MemberAccess &_node) override;
    virtual bool visit(const ModifierInvocation &_node) override;
    virtual bool visit(const ParameterList &_node) override;
    virtual bool visit(const Return &_node) override;
    virtual bool visit(const SourceUnit &_node) override;
    virtual bool visit(const TupleExpression &_node) override;
    virtual bool visit(const UserDefinedTypeName &_node) override;
    virtual bool visit(const VariableDeclaration &_node) override;
    virtual bool visit(const VariableDeclarationStatement &_node) override;

};
