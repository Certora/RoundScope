package com.certora.wala.cast.solidity.translator;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import com.certora.wala.cast.solidity.loader.FunctionType;
import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.tree.SolidityMappingType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.ir.ssa.AstInstructionFactory;
import com.ibm.wala.cast.ir.translator.AstTranslator;
import com.ibm.wala.cast.loader.AstMethod.DebuggingInformation;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstNodeTypeMap;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.impl.CAstSymbolImpl;
import com.ibm.wala.cast.types.AstMethodReference;
import com.ibm.wala.cfg.AbstractCFG;
import com.ibm.wala.cfg.IBasicBlock;
import com.ibm.wala.classLoader.CallSiteReference;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.classLoader.NewSiteReference;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.shrike.shrikeBT.IInvokeInstruction.Dispatch;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SymbolTable;
import com.ibm.wala.types.Descriptor;
import com.ibm.wala.types.FieldReference;
import com.ibm.wala.types.MethodReference;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.TypeReference;

public class SolidityAstTranslator extends AstTranslator {
	private final AstInstructionFactory insts; 
	
	public SolidityAstTranslator(IClassLoader loader) {
		super(loader);
		this.insts = (AstInstructionFactory) loader.getLanguage().instructionFactory();
	}

	@Override
	protected String composeEntityName(WalkContext parent, CAstEntity f) {
		if (parent.top().getKind() == CAstEntity.FILE_ENTITY) {
			return f.getName();
		} else {
			if (f.getKind() == CAstEntity.FUNCTION_ENTITY &&  ((FunctionType)f.getType()).getDeclaringType() != null) {
				if (f.getType() instanceof FunctionType) {
					return ((FunctionType)f.getType()).getDeclaringType().getName() + "." + f.getType().getName();
				} else {
					return f.getType().getName();
				}
			} else {
				String myName = parent.top().getName();
				return (myName.contains("/")? myName.substring(myName.lastIndexOf('/')+1): myName) + "/" + f.getName();
			}
		}
	}

	@Override
	protected void doPrologue(WalkContext context) {
		int v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.msg)));
		context.currentScope().declare(new CAstSymbolImpl("msg", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.LoadMetadataInstruction(context.cfg().getCurrentInstruction(), v, SolidityTypes.codeBody, MethodReference.findOrCreate(SolidityTypes.root, "getType", "(Lroot;)LCodeBody;")));
		context.currentScope().declare(new CAstSymbolImpl("type", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.abi)));
		context.currentScope().declare(new CAstSymbolImpl("abi", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.abi)));
		context.currentScope().declare(new CAstSymbolImpl("mulmod", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.block)));
		context.currentScope().declare(new CAstSymbolImpl("block", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.function)));
		context.currentScope().declare(new CAstSymbolImpl("require", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.function)));
		context.currentScope().declare(new CAstSymbolImpl("keccak256", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.function)));
		context.currentScope().declare(new CAstSymbolImpl("ecrecover", CAstType.DYNAMIC), v);

		v = context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.function)));
		context.currentScope().declare(new CAstSymbolImpl("revert", CAstType.DYNAMIC), v);

		context.currentScope().allocateTempValue();
		context.cfg().addInstruction(insts.NewInstruction(context.cfg().getCurrentInstruction(), v, NewSiteReference.make(context.cfg().getCurrentInstruction(), SolidityTypes.msg)));
		context.currentScope().declare(new CAstSymbolImpl("tx", CAstType.DYNAMIC), v);

	}

	@Override
	protected void declareFunction(CAstEntity N, WalkContext context) {
		assert N.getKind() == CAstEntity.FUNCTION_ENTITY;
		if (N.getName().contains("hasRole")) {
			System.err.println(N);
		}
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
		if (N.getName().contains("hasRole")) {
			System.err.println(N);
		}
		String clsName = composeEntityName(definingContext, N);
		((SolidityLoader)loader).defineFunctionBody(clsName, N, definingContext, cfg, symtab, hasCatchBlock, catchTypes, hasMonitorOp, lexicalInfo, debugInfo);
	}

	@Override
	protected boolean defineType(CAstEntity type, WalkContext wc) {
		String typeNameStr = composeEntityName(wc, type);
		TypeName typeName = TypeName.findOrCreate("L" + typeNameStr);
		IClass cls;
		if (! type.getType().getSupertypes().isEmpty()) {
			Set<TypeName> supers = type.getType().getSupertypes().stream().map(ct -> TypeName.findOrCreate("L" + ct.getName())).collect(Collectors.toSet());
			cls = ((SolidityLoader)loader).defineType(type, typeName, supers);
		} else {
			cls = ((SolidityLoader)loader).defineType(type, typeName, Collections.emptySet());
		}
		return true;
	}

	@Override
	public void doArrayRead(WalkContext context, int result, int arrayValue, CAstNode arrayRef, int[] dimValues) {
		CAstType t = context.top().getNodeTypeMap().getNodeType(arrayRef.getChild(0));
		TypeReference eltType;
		if (t instanceof SolidityMappingType) {
			CAstType eltCAstType = ((SolidityMappingType)t).getReturnType();
			eltType =  SolidityCAstType.getIRType(eltCAstType);
		} else {
			eltType = SolidityTypes.bytes;
		}
		int instNum = context.cfg().getCurrentInstruction();
		context.cfg().addInstruction(insts.ArrayLoadInstruction(instNum, result, arrayValue, dimValues[0], eltType));
	}

	@Override
	public void doArrayWrite(WalkContext context, int arrayValue, CAstNode arrayRef, int[] dimValues, int rval) {
		CAstType t = context.top().getNodeTypeMap().getNodeType(arrayRef.getChild(0));
		TypeReference eltType;
		if (t instanceof SolidityMappingType) {
			CAstType eltCAstType = ((SolidityMappingType)t).getReturnType();
			eltType =  SolidityCAstType.getIRType(eltCAstType);
		} else {
			eltType = SolidityTypes.bytes;
		}
		context.cfg().addInstruction(insts.ArrayStoreInstruction(context.cfg().getCurrentInstruction(), arrayValue, dimValues[0], rval, eltType));
	}
	
	@Override
	protected void doCall(WalkContext context, CAstNode call, int result, int exception, CAstNode name, int receiver,
			int[] arguments) {
		if (call.getChild(0).getKind() == CAstNode.TYPE_LITERAL_EXPR) {
			String typeName = (String) call.getChild(0).getChild(0).getValue();
			TypeReference type = SolidityCAstType.getIRType(SolidityCAstType.get(typeName));
			if (type != null) {
				context.cfg().addInstruction(insts.CheckCastInstruction(context.cfg().getCurrentInstruction(), result, arguments[0], type, true));
			} else {
				context.cfg().addInstruction(insts.AssignInstruction(context.cfg().getCurrentInstruction(), result, arguments[0]));
			}
		} else if (call.getChild(0).getKind() == CAstNode.PRIMITIVE &&
				"type".equals(call.getChild(0).getChild(0).getValue()) &&
				call.getChild(2).getKind() == CAstNode.TYPE_LITERAL_EXPR) {
			context.cfg().addInstruction(insts.LoadMetadataInstruction(context.cfg().getCurrentInstruction(), result, SolidityTypes.root, TypeReference.findOrCreate(SolidityTypes.solidity, (String)call.getChild(2).getChild(0).getValue())));
		} else if (call.getChild(0).getKind() == CAstNode.PRIMITIVE &&
				"revert".equals(call.getChild(0).getChild(0).getValue())) {
			context.cfg().addInstruction(insts.ThrowInstruction(context.cfg().getCurrentInstruction(), arguments[0]));

		} else {
			int argsAndSelf[] = new int[ arguments.length + 1 ];
			argsAndSelf[0] = receiver;
			System.arraycopy(arguments, 0, argsAndSelf, 1, arguments.length);

			CAstType recCAstType = context.top().getNodeTypeMap().getNodeType(call.getChild(0));
			MethodReference m;
			if (! (recCAstType instanceof FunctionType)) {
				TypeReference retType = SolidityCAstType.getIRType(recCAstType);
				TypeName[] argTypes = new TypeName[ arguments.length ];
				for(int i = 0; i < argTypes.length; i++) {
					argTypes[i] = SolidityTypes.root.getName();
					}
				Descriptor d = Descriptor.findOrCreate(argTypes, retType.getName());
				m = MethodReference.findOrCreate(SolidityTypes.root, AstMethodReference.fnAtom, d);
			} else {
				m = ((SolidityLoader)loader).getReference((FunctionType) recCAstType);
			}
			CallSiteReference csr = CallSiteReference.make(context.cfg().getCurrentInstruction(), m, Dispatch.VIRTUAL);
			context.cfg().addInstruction(insts.InvokeInstruction(context.cfg().getCurrentInstruction(), m.getReturnType() == TypeReference.Void? -1: result, argsAndSelf, context.currentScope().allocateTempValue(), csr, null));			
		}
	}

	@Override
	protected void doFieldRead(WalkContext context, int result, int receiver, CAstNode elt, CAstNode parent) {
		CAstEntity code = context.top();
		CAstNodeTypeMap typeMap = code.getNodeTypeMap();
		CAstType objCAstType = typeMap.getNodeType(parent.getChild(0));
		CAstType eltCAstType = typeMap.getNodeType(parent);	
		TypeReference objType = objCAstType==null? SolidityTypes.root: SolidityCAstType.getIRType(objCAstType);
		TypeReference eltType = eltCAstType==null? SolidityTypes.root: SolidityCAstType.getIRType(eltCAstType);
		if (eltCAstType instanceof FunctionType) {
			TypeReference t = TypeReference.findOrCreate(SolidityTypes.solidity, eltType.getName());
			NewSiteReference ns = NewSiteReference.make(context.cfg().getCurrentInstruction(), t);
			context.cfg().addInstruction(insts.NewInstruction(ns.getProgramCounter(), result, ns));
			FieldReference self = FieldReference.findOrCreate(t, Atom.findOrCreateUnicodeAtom("self"), objType);
			context.cfg().addInstruction(insts.PutInstruction(context.cfg().getCurrentInstruction(), result, receiver, self));
		} else {
			context.cfg().addInstruction(insts.GetInstruction(context.cfg().getCurrentInstruction(), result, receiver, FieldReference.findOrCreate(objType, Atom.findOrCreateUnicodeAtom(elt.getValue().toString()), eltType)));
		}
	}

	@Override
	protected void doFieldWrite(WalkContext context, int receiver, CAstNode elt, CAstNode parent, int rval) {
		CAstEntity code = context.top();
		CAstNodeTypeMap typeMap = code.getNodeTypeMap();
		CAstType objCAstType = typeMap.getNodeType(parent.getChild(0));
		CAstType eltCAstType = typeMap.getNodeType(parent);	
		TypeReference objType = objCAstType==null? SolidityTypes.root: SolidityCAstType.getIRType(objCAstType);
		TypeReference eltType = eltCAstType==null? SolidityTypes.root: SolidityCAstType.getIRType(eltCAstType);
		context.cfg().addInstruction(insts.PutInstruction(context.cfg().getCurrentInstruction(), receiver, rval, FieldReference.findOrCreate(objType, Atom.findOrCreateUnicodeAtom((String)elt.getValue()), eltType)));
	}
	
	@Override
	protected void doNewObject(WalkContext context, CAstNode newNode, int result, Object type, int[] arguments) {
		// TODO Auto-generated method stub

	}

	@Override
	protected void doPrimitive(int resultVal, WalkContext context, CAstNode primitiveCall) {
		String name = (String)primitiveCall.getChild(0).getValue();
		context.cfg().addInstruction(
			insts.AssignInstruction(context.cfg().getCurrentInstruction(), 
				resultVal, 
				"this".equals(name) || "super".equals(name)? 1:  context.currentScope().lookup(name).valueNumber()));
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
		return SolidityCAstType.getIRType(type);
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
