package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.certora.wala.cast.solidity.jni.SolidityJNIBridge;
import com.certora.wala.cast.solidity.util.Configuration;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.tree.CAst;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.ModuleEntry;
import com.ibm.wala.classLoader.SourceFileModule;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.util.collections.Pair;

public class SolidityJNILoader extends SolidityLoader {
	SolidityJNIBridge solidityCode;
	private final File confFile;
	private final Map<String, File> includePath;

	public SolidityJNILoader(File confFile, Map<String, File> includePath, IClassHierarchy cha, IClassLoader parent) {
		super(cha, parent);
		this.confFile = confFile;
		this.includePath = includePath;
		this.solidityCode = new SolidityJNIBridge(this);
	}

	public Pair<File,String> getFile(String b) {
		File f = null;
		String v = null;
		try {
			if ((f = new File(b)).exists()) {
				v = new String(Files.readAllBytes(Paths.get(new File(b).toURI())), "UTF-8");
			} else {
				f = Configuration.getFile(confFile.getParentFile(), b);
				if (f != null) {
					v = new String(Files.readAllBytes(Paths.get(f.toURI())), "UTF-8");													
				} else {
					outer: for(Map.Entry<String,File> e : includePath.entrySet()) {
						if (b.startsWith(e.getKey() + "/")) {
							f = new File(e.getValue(), b.substring(e.getKey().length() + 1));
							if (f.exists()) {
								v = new String(Files.readAllBytes(Paths.get(f.toURI())), "UTF-8");							
								break outer;
							}
						}
					}
				}
			}
		} catch (IOException e) {
			assert false : e;
		}
		return Pair.make(f, v);
	}

	@Override
	protected TranslatorToCAst getTranslatorToCAst(CAst ast, ModuleEntry M, List<Module> modules) throws IOException {
		SourceFileModule f = (SourceFileModule) M;
		return solidityCode.new SolidityFileTranslator(f.logicalFileName());
	}

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

		List<Module> newModules;
		List<String> loadedFiles = solidityCode.files();
		if (loadedFiles.size() > modules.size()) {
			newModules =  new ArrayList<>();
		
			outer: for (String f : loadedFiles) {
				for(Module m : modules) {
					SourceFileModule sfm = (SourceFileModule)m;
					if (sfm.getFile().equals(new File(f))) {
						newModules.add(m);
						continue outer;
					}
				}
			
				File resolvedFile = getFile(f).fst;
				assert resolvedFile.exists();
				newModules.add(new SourceFileModule(resolvedFile, f, null));
			}
		} else {
			newModules = modules;
		}
		
		System.err.println("file: " + newModules);
		
		super.init(newModules);
	}

}
