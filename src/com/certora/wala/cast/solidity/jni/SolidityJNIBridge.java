package com.certora.wala.cast.solidity.jni;

import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.io.Reader;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Collection;
import java.util.List;

import com.ibm.wala.cast.ir.translator.AbstractEntity;
import com.ibm.wala.cast.ir.translator.NativeBridge;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst.Error;
import com.ibm.wala.cast.tree.CAstControlFlowMap;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstNodeTypeMap;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstSourcePositionMap;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.impl.CAstImpl;
import com.ibm.wala.cast.tree.impl.CAstSourcePositionRecorder;
import com.ibm.wala.cast.tree.rewrite.CAstRewriter.CopyKey;
import com.ibm.wala.cast.tree.rewrite.CAstRewriter.RewriteContext;
import com.ibm.wala.cast.tree.rewrite.CAstRewriterFactory;
import com.ibm.wala.classLoader.IMethod.SourcePosition;

public class SolidityJNIBridge extends NativeBridge implements AutoCloseable {	
	private static int ids = 0;

	private final int id = ids++;

	static {
		System.loadLibrary("walacastsolidity");
	}

	public class SolidityFileTranslator extends NativeBridge implements TranslatorToCAst {
		private final int id = SolidityJNIBridge.this.id;
		private final String fileName;
		
		public SolidityFileTranslator(String fileName) {
			super(SolidityJNIBridge.this.Ast);
			this.fileName = fileName;
		}

		final CAstEntity fileEntity = new AbstractEntity() {

			@Override
			public int getKind() {
				return CAstEntity.FILE_ENTITY;
			}

			@Override
			public String getName() {
				return fileName;
			}

			@Override
			public CAstNode getAST() {
				assert false;
				return null;
			}

			@Override
			public int getArgumentCount() {
				assert false;
				return 0;
			}

			@Override
			public CAstNode[] getArgumentDefaults() {
				assert false;
				return null;
			}

			@Override
			public String[] getArgumentNames() {
				return new String[0];
			}

			@Override
			public CAstControlFlowMap getControlFlow() {
				assert false;
				return null;
			}

			@Override
			public Position getNamePosition() {
				assert false;
				return null;
			}

			@Override
			public CAstNodeTypeMap getNodeTypeMap() {
				assert false;
				return null;
			}

			@Override
			public Position getPosition(int arg) {
				assert false;
				return null;
			}

			@Override
			public Collection<CAstQualifier> getQualifiers() {
				assert false;
				return null;
			}

			@Override
			public CAstSourcePositionMap getSourceMap() {
				assert false;
				return null;
			}

			@Override
			public CAstType getType() {
				assert false;
				return null;
			}
		};
		
		public Position makePosition(String fileName, int startOffset, int endOffset) {
			return SolidityJNIBridge.this.makePosition(fileName, startOffset, endOffset);
		}
		
		void record(CAstNode node, Position pos) {
			SolidityJNIBridge.this.record(node, pos);
		}
		
		@Override
		public <C extends RewriteContext<K>, K extends CopyKey<K>> void addRewriter(CAstRewriterFactory<C, K> factory,
				boolean prepend) {
			assert false;
		}

		@Override
		public CAstEntity translateToCAst() throws Error, IOException {
			return translate(fileName);
		}
		
		public native CAstEntity translate(String fileName);
	}
	
	final CAstSourcePositionRecorder posMap = new CAstSourcePositionRecorder();
	
	void record(CAstNode node, Position pos) {
		posMap.setPosition(node, pos);
	}
	
	public Position makePosition(String fileName, int startOffset, int endOffset) {
		return new Position() {
			@Override
			public int getFirstCol() {
				return -1;
			}

			@Override
			public int getFirstLine() {
				return -1;
			}

			@Override
			public int getFirstOffset() {
				return startOffset;
			}

			@Override
			public int getLastCol() {
				return -1;
			}

			@Override
			public int getLastLine() {
				return -1;
			}

			@Override
			public int getLastOffset() {
				return endOffset;
			}

			@Override
			public int compareTo(SourcePosition o) {
				return o.getFirstOffset() - getFirstOffset();
			}

			@Override
			public Reader getReader() throws IOException {
				return new FileReader(fileName);
			}

			@Override
			public URL getURL() {
				try {
					return URI.create("file:" + fileName).toURL();
				} catch (MalformedURLException e) {
					assert false : e;
					return null;
				}
			}
			
			@Override
			public String toString() {
				return "[" + getFirstOffset() + "-" + getLastOffset() + "]";
			}
		};
	}

	public SolidityJNIBridge() {
		super(new CAstImpl());
		init();
	}

	private native void init();

	public native void loadFiles(String[] filesAndNames);

	public native List<String> files();

	public String loadFile(String a, String b) {
		String v = null;
		if (new File(b).exists()) {
			try {
				v = new String(Files.readAllBytes(Paths.get(new File(b).toURI())));
			} catch (IOException e) {
				assert false : e;
			}
		}
		
		return v;
	}
	
	public CAstEntity translateFile(String fileName) throws Error, IOException {
		return new SolidityFileTranslator(fileName).translateToCAst();
	}
	
	@Override
	public native void close() throws Exception;
}
