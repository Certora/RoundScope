package com.certora.wala.cast.solidity.loader;

import java.io.IOException;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.certora.wala.cast.solidity.jni.SolidityJNIBridge;
import com.certora.wala.cast.solidity.translator.SolidityAstTranslator;
import com.certora.wala.cast.solidity.tree.EventEntity;
import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.analysis.typeInference.PrimitiveType;
import com.ibm.wala.cast.ir.ssa.AstInstructionFactory;
import com.ibm.wala.cast.ir.translator.AstTranslator.AstLexicalInformation;
import com.ibm.wala.cast.ir.translator.AstTranslator.WalkContext;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.ir.translator.TranslatorToIR;
import com.ibm.wala.cast.java.loader.JavaSourceLoaderImpl;
import com.ibm.wala.cast.loader.AstClass;
import com.ibm.wala.cast.loader.AstField;
import com.ibm.wala.cast.loader.AstFunctionClass;
import com.ibm.wala.cast.loader.AstMethod.DebuggingInformation;
import com.ibm.wala.cast.loader.CAstAbstractModuleLoader;
import com.ibm.wala.cast.tree.CAst;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cfg.AbstractCFG;
import com.ibm.wala.cfg.IBasicBlock;
import com.ibm.wala.cfg.InducedCFG;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.classLoader.IField;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.classLoader.IMethod.SourcePosition;
import com.ibm.wala.classLoader.JavaLanguage;
import com.ibm.wala.classLoader.Language;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.ModuleEntry;
import com.ibm.wala.classLoader.SourceFileModule;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.ipa.callgraph.AnalysisOptions;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.Context;
import com.ibm.wala.ipa.callgraph.IAnalysisCacheView;
import com.ibm.wala.ipa.callgraph.impl.AbstractRootMethod;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKey;
import com.ibm.wala.ipa.callgraph.propagation.PointerAnalysis;
import com.ibm.wala.ipa.callgraph.propagation.PointerKey;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ipa.modref.ExtendedHeapModel;
import com.ibm.wala.ipa.modref.ModRef.ModVisitor;
import com.ibm.wala.ipa.modref.ModRef.RefVisitor;
import com.ibm.wala.shrike.shrikeCT.InvalidClassFileException;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SSAInstructionFactory;
import com.ibm.wala.ssa.SymbolTable;
import com.ibm.wala.types.ClassLoaderReference;
import com.ibm.wala.types.Descriptor;
import com.ibm.wala.types.FieldReference;
import com.ibm.wala.types.MethodReference;
import com.ibm.wala.types.Selector;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.types.annotations.Annotation;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.Pair;

public class SolidityLoader extends CAstAbstractModuleLoader {
	SolidityJNIBridge solidityCode = new SolidityJNIBridge();

	private final IClass root = new CoreClass(SolidityTypes.root.getName(), null, this, null);

	private final IClass codeBody = new CoreClass(SolidityTypes.codeBody.getName(), root.getName(), this,
			null);

	private final IClass msg = new CoreClass(SolidityTypes.msg.getName(), root.getName(), this,
			null);

	private final IClass function = new CoreClass(SolidityTypes.function.getName(), codeBody.getName(), this,
			null);

	private final IClass event = new CoreClass(SolidityTypes.event.getName(), codeBody.getName(), this,
			null);

	@Override
	public void init(List<Module> modules) {
		for (Module m : modules) {
			assert m instanceof SourceFileModule;
		}

		int i = 0;
		String[] files = new String[modules.size() * 2];
		for (Module m : modules) {
			SourceFileModule f = (SourceFileModule) m;
			files[i++] = f.getAbsolutePath();
			files[i++] = f.getName();
		}

		solidityCode.loadFiles(files);

		super.init(modules);
	}

	public SolidityLoader(IClassHierarchy cha, IClassLoader parent) {
		super(cha, parent);
	}

	@Override
	public SSAInstructionFactory getInstructionFactory() {
		return getLanguage().instructionFactory();
	}

	static final Language solidity = new JavaLanguage() {

		@Override
		public TypeReference[] getArrayInterfaces() {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public Language getBaseLanguage() {
			return null;
		}

		@Override
		public TypeReference getConstantType(Object o) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public Set<Language> getDerivedLanguages() {
			return Collections.emptySet();
		}

		@Override
		public AbstractRootMethod getFakeRootMethod(IClassHierarchy cha, AnalysisOptions options,
				IAnalysisCacheView cache) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public Object getMetadataToken(Object value) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public Atom getName() {
			return SolidityTypes.solidityLanguage;
		}

		@Override
		public TypeReference getPointerType(TypeReference pointee) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public PrimitiveType getPrimitive(TypeReference reference) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public TypeReference getRootType() {
			return SolidityTypes.root;
		}

		@Override
		public TypeReference getStringType() {
			return SolidityTypes.string;
		}

		@Override
		public TypeReference getThrowableType() {
			return TypeReference.JavaLangThrowable;
		}

		@Override
		public Collection<TypeReference> inferInvokeExceptions(MethodReference target, IClassHierarchy cha)
				throws InvalidClassFileException {
			// TODO Auto-generated method stub
			return null;
		}

		private final AstInstructionFactory insts = new JavaSourceLoaderImpl.InstructionFactory();

		@Override
		public AstInstructionFactory instructionFactory() {
			return insts;
		}

		@Override
		public boolean isBooleanType(TypeReference t) {
			return t == SolidityTypes.bool;
		}

		@Override
		public boolean isCharType(TypeReference t) {
			// TODO Auto-generated method stub
			return false;
		}

		@Override
		public boolean isDoubleType(TypeReference t) {
			// TODO Auto-generated method stub
			return false;
		}

		@Override
		public boolean isFloatType(TypeReference t) {
			// TODO Auto-generated method stub
			return false;
		}

		@Override
		public boolean isIntType(TypeReference t) {
			return t == SolidityTypes.uint8 || t == SolidityTypes.uint256;
		}

		@Override
		public boolean isLongType(TypeReference t) {
			return t == SolidityTypes.uint256;
		}

		@Override
		public boolean isMetadataType(TypeReference t) {
			// TODO Auto-generated method stub
			return false;
		}

		@Override
		public boolean isNullType(TypeReference t) {
			// TODO Auto-generated method stub
			return false;
		}

		@Override
		public boolean isStringType(TypeReference t) {
			return t == SolidityTypes.string;
		}

		@Override
		public boolean isVoidType(TypeReference t) {
			// TODO Auto-generated method stub
			return false;
		}

		@Override
		public TypeName lookupPrimitiveType(String name) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public InducedCFG makeInducedCFG(SSAInstruction[] instructions, IMethod method, Context context) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public <T extends InstanceKey> ModVisitor<T, ? extends ExtendedHeapModel> makeModVisitor(CGNode n,
				Collection<PointerKey> result, PointerAnalysis<T> pa, ExtendedHeapModel h,
				boolean ignoreAllocHeapDefs) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public <T extends InstanceKey> RefVisitor<T, ? extends ExtendedHeapModel> makeRefVisitor(CGNode n,
				Collection<PointerKey> result, PointerAnalysis<T> pa, ExtendedHeapModel h) {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public boolean methodsHaveDeclaredParameterTypes() {
			return true;
		}

		@Override
		public boolean modelConstant(Object o) {
			// TODO Auto-generated method stub
			return false;
		}

		@Override
		public void registerDerivedLanguage(Language l) {
			assert false;
		}

	};

	@Override
	public Language getLanguage() {
		return solidity;
	}

	@Override
	public ClassLoaderReference getReference() {
		return SolidityTypes.solidity;
	}

	@Override
	protected TranslatorToCAst getTranslatorToCAst(CAst ast, ModuleEntry M, List<Module> modules) throws IOException {
		SourceFileModule f = (SourceFileModule) M;
		return solidityCode.new SolidityFileTranslator(f.getAbsolutePath());
	}

	@Override
	protected TranslatorToIR initTranslator(Set<Pair<CAstEntity, ModuleEntry>> topLevelEntities) {
		return new SolidityAstTranslator(this);
	}

	@Override
	protected boolean shouldTranslate(CAstEntity entity) {
		return true;
	}

	class SolidityClass extends AstClass {

		protected SolidityClass(Position sourcePosition, TypeName typeName, Map<Atom, IField> declaredFields,
				Map<Selector, IMethod> declaredMethods, Collection<IClass> supers, TypeName superClass) {
			super(sourcePosition, typeName, SolidityLoader.this, (short) 0, declaredFields, declaredMethods);
			this.supers = supers;
			this.superClass = superClass;
		}

		private Collection<IClass> supers;
		private TypeName superClass;

		@Override
		public Collection<Annotation> getAnnotations() {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public IClassHierarchy getClassHierarchy() {
			return cha;
		}

		@Override
		public Collection<IClass> getDirectInterfaces() {
			return supers;
		}

		@Override
		public IClass getSuperclass() {
			return lookupClass(superClass);
		}

		@Override
		public String toString() {
			return getReference().toString();
		}

	}

	private void makeFields(CAstEntity type, IClass newClass, Map<Atom, IField> fields) {
		type.getScopedEntities(null).forEachRemaining(ce -> {
			if (ce.getKind() == CAstEntity.FIELD_ENTITY) {
				TypeReference fieldType = SolidityCAstType.getIRType(ce.getType().getName());
				Atom fieldName = Atom.findOrCreateUnicodeAtom(ce.getName());
				FieldReference fr = FieldReference.findOrCreate(newClass.getReference(), fieldName, fieldType);
				fields.put(fieldName,
						new AstField(fr, Collections.emptyList(), newClass, cha, Collections.emptyList()) {

						});
			} else if (ce.getKind() == CAstEntity.FUNCTION_ENTITY) {
				CAstType.Function ft = (CAstType.Function) ce.getType();
				TypeName[] params = new TypeName[ ft.getArgumentCount() ];
				for(int i = 0; i < ft.getArgumentCount() ; i++) {
					params[i] = SolidityCAstType.getIRType(ft.getArgumentTypes().get(i).getName()).getName();
				}
				TypeName ret = 
					ft.getReturnType() == null? 
						TypeReference.Void.getName(): 
							SolidityCAstType.getIRType(ft.getReturnType().getName()).getName();

				Descriptor d = Descriptor.findOrCreate(params, ret);
				Selector s = new Selector(Atom.findOrCreateUnicodeAtom(ft.getName()), d);
			
				Atom fieldName = Atom.findOrCreateUnicodeAtom(s.toString());
				FieldReference fr = FieldReference.findOrCreate(newClass.getReference(), fieldName, SolidityTypes.function);
				fields.put(fieldName,
						new AstField(fr, Collections.emptyList(), newClass, cha, Collections.emptyList()) {
				
				});
			}
		});
	}

	public IClass defineType(CAstEntity type, TypeName typeName, Set<IClass> supers) {
		Map<Atom, IField> fields = HashMapFactory.make();
		Map<Selector, IMethod> methods = HashMapFactory.make();
		TypeName superClass;
		Collection<IClass> si;
		if (supers.size() == 1) {
			si = Collections.emptyList();
			superClass = supers.iterator().next().getName();
		} else {
			superClass = root.getName();
			si = supers;
		}
		IClass newClass = new SolidityClass(type.getPosition(), typeName, fields, methods, si, superClass);
		types.put(typeName, newClass);
		makeFields(type, newClass, fields);
		return newClass;
	}

	public IClass defineFunctionType(CAstEntity n, String name, WalkContext c) {
		TypeReference fn = TypeReference.findOrCreate(getReference(), 'L' + name);
		if (n instanceof EventEntity) {
			return new AstFunctionClass(fn, this, n.getPosition()) {

				{
					types.put(fn.getName(), this);
				}
				
				@Override
				public Collection<Annotation> getAnnotations() {
					return Collections.emptySet();
				}

				@Override
				public IClassHierarchy getClassHierarchy() {
					return cha;
				}
				
				@Override
				public IClass getSuperclass() {
					return event;
				}

				@Override
				public String toString() {
					return "event " + name;
				}
			};
		} else {
			return new DynamicCodeBody(fn, 
				function.getReference(), this,
				n.getPosition(), n, c);
		}
	}

	public DynamicMethodObject makeCodeBodyCode(AbstractCFG<?, ?> cfg, SymbolTable symtab, boolean hasCatchBlock,
			Map<IBasicBlock<SSAInstruction>, Set<TypeReference>> caughtTypes, boolean hasMonitorOp,
			AstLexicalInformation lexicalInfo, DebuggingInformation debugInfo, IClass C) {
		return new DynamicMethodObject(C, Collections.emptySet(), cfg, symtab, hasCatchBlock, caughtTypes, hasMonitorOp,
				lexicalInfo, debugInfo) {

					@Override
					public int getNumberOfParameters() {
						return super.getNumberOfParameters() + 1;
					}

					@Override
					public SourcePosition getParameterSourcePosition(int paramNum) throws InvalidClassFileException {
						if (paramNum == 0) {
							return null;
						} else {
							return super.getParameterSourcePosition(paramNum-1);
						}
					}

					@Override
					public Position getParameterPosition(int paramIndex) {
						if (paramIndex == 0) {
							return null;
						} else {
							return super.getParameterPosition(paramIndex-1);
						}
					}	
		};
	}

	public IMethod defineFunctionBody(String clsName, CAstEntity n, WalkContext definingContext,
			AbstractCFG<SSAInstruction, ? extends IBasicBlock<SSAInstruction>> cfg, SymbolTable symtab,
			boolean hasCatchBlock, Map<IBasicBlock<SSAInstruction>, Set<TypeReference>> caughtTypes,
			boolean hasMonitorOp, AstLexicalInformation lexicalInfo, DebuggingInformation debugInfo) {
		DynamicCodeBody C = (DynamicCodeBody) lookupClass('L' + clsName, cha);
		assert C != null : clsName;
		return C.setCodeBody(
			makeCodeBodyCode(cfg, symtab, hasCatchBlock, caughtTypes, hasMonitorOp, lexicalInfo, debugInfo, C));
	}
}
