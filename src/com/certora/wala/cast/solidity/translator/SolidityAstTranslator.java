package com.certora.wala.cast.solidity.translator;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.tree.SolidityMappingType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.ir.translator.AstTranslator;
import com.ibm.wala.cast.loader.AstMethod.DebuggingInformation;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cfg.AbstractCFG;
import com.ibm.wala.cfg.IBasicBlock;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SSAInstructionFactory;
import com.ibm.wala.ssa.SymbolTable;
import com.ibm.wala.types.FieldReference;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;

public class SolidityAstTranslator extends AstTranslator {
	private final Map<CAstType,IClass> types = HashMapFactory.make();

	private final SSAInstructionFactory insts; 
	
	public SolidityAstTranslator(IClassLoader loader) {
		super(loader);
		this.insts = loader.getLanguage().instructionFactory();
	}

	@Override
	protected String composeEntityName(WalkContext parent, CAstEntity f) {
		String myName = parent.top().getName();
		return (myName.contains("/")? myName.substring(myName.lastIndexOf('/')+1): myName) + "/" + f.getName();
	}

	@Override
	protected void declareFunction(CAstEntity N, WalkContext context) {
		assert N.getKind() == CAstEntity.FUNCTION_ENTITY;
		((SolidityLoader)loader).defineFunctionType(N, composeEntityName(context, N), context);
	}

	@Override
	protected TypeReference defaultCatchType() {
		return SolidityTypes.root;
	}

	@Override
	protected void defineField(CAstEntity topEntity, WalkContext context, CAstEntity fieldEntity) {
		// noop, handled by defineType
	}

	@Override
	protected void defineFunction(CAstEntity N, WalkContext definingContext,
			AbstractCFG<SSAInstruction, ? extends IBasicBlock<SSAInstruction>> cfg, SymbolTable symtab,
			boolean hasCatchBlock, Map<IBasicBlock<SSAInstruction>, Set<TypeReference>> catchTypes,
			boolean hasMonitorOp, AstLexicalInformation lexicalInfo, DebuggingInformation debugInfo) {
		String clsName = composeEntityName(definingContext, N);
		((SolidityLoader)loader).defineFunctionBody(clsName, N, definingContext, cfg, symtab, hasCatchBlock, catchTypes, hasMonitorOp, lexicalInfo, debugInfo);
	}

	@Override
	protected boolean defineType(CAstEntity type, WalkContext wc) {
		String typeNameStr = composeEntityName(wc, type);
		TypeName typeName = TypeName.findOrCreate("L" + typeNameStr);
		IClass cls;
		if (! type.getType().getSupertypes().isEmpty()) {
			Set<IClass> supers = type.getType().getSupertypes().stream().map(ct -> types.get(ct)).collect(Collectors.toSet());
			cls = ((SolidityLoader)loader).defineType(type, typeName, supers);
		} else {
			cls = ((SolidityLoader)loader).defineType(type, typeName, Collections.emptySet());
		}
		types.put(type.getType(), cls);
		return true;
	}

	@Override
	public void doArrayRead(WalkContext context, int result, int arrayValue, CAstNode arrayRef, int[] dimValues) {
		CAstType t = context.top().getNodeTypeMap().getNodeType(arrayRef);
		assert t instanceof SolidityMappingType;
		CAstType eltCAstType = ((SolidityMappingType)t).getReturnType();
		TypeReference eltType =  SolidityCAstType.getIRType(eltCAstType.getName());
		context.cfg().addInstruction(insts.ArrayLoadInstruction(context.cfg().getCurrentInstruction(), result, arrayValue, dimValues[0], eltType));
	}

	@Override
	public void doArrayWrite(WalkContext context, int arrayValue, CAstNode arrayRef, int[] dimValues, int rval) {
		CAstType t = context.top().getNodeTypeMap().getNodeType(arrayRef.getChild(0));
		assert t instanceof SolidityMappingType;
		CAstType eltCAstType = ((SolidityMappingType)t).getReturnType();
		TypeReference eltType =  SolidityCAstType.getIRType(eltCAstType.getName());
		context.cfg().addInstruction(insts.ArrayStoreInstruction(context.cfg().getCurrentInstruction(), arrayValue, dimValues[0], rval, eltType));
	}

	@Override
	protected void doCall(WalkContext context, CAstNode call, int result, int exception, CAstNode name, int receiver,
			int[] arguments) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doFieldRead(WalkContext context, int result, int receiver, CAstNode elt, CAstNode parent) {
		CAstEntity contract = getParent(context.top());
		CAstType objCAstType = contract.getType();
		TypeReference objType = SolidityCAstType.getIRType(objCAstType.getName());
		context.cfg().addInstruction(insts.GetInstruction(context.cfg().getCurrentInstruction(), result, receiver, FieldReference.findOrCreate(objType, Atom.findOrCreateUnicodeAtom((String)elt.getValue()), objType)));
	}

	@Override
	protected void doFieldWrite(WalkContext context, int receiver, CAstNode elt, CAstNode parent, int rval) {
		CAstEntity contract = getParent(context.top());
		CAstType objCAstType = contract.getType();
		TypeReference objType = SolidityCAstType.getIRType(objCAstType.getName());
		context.cfg().addInstruction(insts.PutInstruction(context.cfg().getCurrentInstruction(), receiver, rval, FieldReference.findOrCreate(objType, Atom.findOrCreateUnicodeAtom((String)elt.getValue()), objType)));
	}

	@Override
	protected void doNewObject(WalkContext context, CAstNode newNode, int result, Object type, int[] arguments) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doPrimitive(int resultVal, WalkContext context, CAstNode primitiveCall) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doThrow(WalkContext context, int exception) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doMaterializeFunction(CAstNode node, WalkContext context, int result, int exception, CAstEntity fn) {
		assert false;
	}

	@Override
	protected CAstType exceptionType() {
		return SolidityCAstType.get("root");
	}

	@Override
	protected Position[] getParameterPositions(CAstEntity e) {
		int nargs = e.getArgumentCount();
		Position[] args = new Position[nargs];
		for(int i = 0; i < nargs; i++) {
			args[i] = e.getPosition(i);
		}
		return args;
	}

	@Override
	protected TypeReference makeType(CAstType type) {
		return SolidityCAstType.getIRType(type.getName());
	}

	@Override
	protected CAstType topType() {
		return SolidityCAstType.get("root");
	}

	@Override
	protected boolean treatGlobalsAsLexicallyScoped() {
		return false;
	}

	@Override
	protected boolean useDefaultInitValues() {
		return false;
	}

}
