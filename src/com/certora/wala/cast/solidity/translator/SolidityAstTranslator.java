package com.certora.wala.cast.solidity.translator;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import com.certora.wala.cast.solidity.loader.SolidityLoader;
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
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SymbolTable;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;

public class SolidityAstTranslator extends AstTranslator {
	private final Map<CAstType,IClass> types = HashMapFactory.make();
	
	public SolidityAstTranslator(IClassLoader loader) {
		super(loader);
	}

	@Override
	protected String composeEntityName(WalkContext parent, CAstEntity f) {
		String myName = parent.top().getName();
		return (myName.contains("/")? myName.substring(myName.lastIndexOf('/')+1): myName) + "/" + f.getName();
	}

	@Override
	protected void declareFunction(CAstEntity N, WalkContext context) {
		// noop

	}

	@Override
	protected TypeReference defaultCatchType() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	protected void defineField(CAstEntity topEntity, WalkContext context, CAstEntity fieldEntity) {
		// noop
	}

	@Override
	protected void defineFunction(CAstEntity N, WalkContext definingContext,
			AbstractCFG<SSAInstruction, ? extends IBasicBlock<SSAInstruction>> cfg, SymbolTable symtab,
			boolean hasCatchBlock, Map<IBasicBlock<SSAInstruction>, Set<TypeReference>> catchTypes,
			boolean hasMonitorOp, AstLexicalInformation lexicalInfo, DebuggingInformation debugInfo) {
		// TODO Auto-generated method stub

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
		// TODO Auto-generated method stub

	}

	@Override
	public void doArrayWrite(WalkContext context, int arrayValue, CAstNode arrayRef, int[] dimValues, int rval) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doCall(WalkContext context, CAstNode call, int result, int exception, CAstNode name, int receiver,
			int[] arguments) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doFieldRead(WalkContext context, int result, int receiver, CAstNode elt, CAstNode parent) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doFieldWrite(WalkContext context, int receiver, CAstNode elt, CAstNode parent, int rval) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doMaterializeFunction(CAstNode node, WalkContext context, int result, int exception, CAstEntity fn) {
		// TODO Auto-generated method stub

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
	protected CAstType exceptionType() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	protected Position[] getParameterPositions(CAstEntity e) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	protected TypeReference makeType(CAstType type) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	protected CAstType topType() {
		// TODO Auto-generated method stub
		return null;
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
