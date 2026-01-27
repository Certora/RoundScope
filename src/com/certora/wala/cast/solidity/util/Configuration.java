package com.certora.wala.cast.solidity.util;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.util.Collection;
import java.util.Collections;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;

import com.certora.certoraprover.cvl.Ast;
import com.certora.certoraprover.cvl.Lexer;
import com.certora.certoraprover.cvl.ParserCVL;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.SourceFileModule;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.Pair;

import java_cup.runtime.ComplexSymbolFactory;
import spec.CVLSource;
import spec.EVMConfig;
import spec.VMConfig;

public class Configuration {

	public interface Conf {
		Ast getRules();
		Collection<Module> getFiles();
		public Map<Pair<Atom,TypeReference>,TypeReference> getLink();
		Map<String, File> getIncludePath();
	}
	
	public static File getFile(File stem, String suffix) {
		File file = new File(stem, suffix);
		while (!file.exists() && stem != null) {
			stem = stem.getParentFile();
			file = new File(stem, suffix);
		}
		return stem==null? null: file;
	}
	
	public static Conf getConf(File configFile) throws FileNotFoundException {
		JSONTokener conf = new JSONTokener(new FileReader(configFile));
		JSONObject cf = (JSONObject) conf.nextValue();
		
		String spec = cf.getString("verify");
		if (spec.contains(":")) {
			spec = spec.substring(spec.lastIndexOf(':')+1, spec.length());
		}
		File stem = configFile.getParentFile();
		File rulesFile = getFile(stem, spec);

		return new Conf() {

			@Override
			public Ast getRules() {
				ComplexSymbolFactory y = new ComplexSymbolFactory();
				VMConfig c = EVMConfig.INSTANCE;
				CVLSource.File f = new CVLSource.File(rulesFile.getAbsolutePath(), rulesFile.getAbsolutePath(), false);
				Lexer x = f.lexer(y, c, f.getName());
				return ParserCVL.parse_with_errors(x, y, f.getOrigpath(), false).force();
			}

			@Override
			public Collection<Module> getFiles() {
				Map<String,Module> result = HashMapFactory.make();
				JSONArray files = cf.getJSONArray("files");
				for(int i = 0; i < files.length(); i++) {
					String f = files.getString(i);
					if (f.contains(":")) {
						f = f.substring(0, f.lastIndexOf(':'));
					}
					if (! result.containsKey(f)) {
						File m = getFile(configFile.getParentFile(), f);
						result.put(f, new SourceFileModule(m, m.getAbsolutePath(), null));
					}
				}
				
				
				return result.values();
			}

			@Override
			public Map<Pair<Atom,TypeReference>,TypeReference> getLink() {
				Map<Pair<Atom,TypeReference>,TypeReference> result = HashMapFactory.make();
				JSONArray map = cf.getJSONArray("link");
				for(int i =  0; i < map.length(); i++) {
					String elt = map.getString(i);
					String[] elts = elt.split("[:=]");
					result.put(
						Pair.make(Atom.findOrCreateUnicodeAtom(elts[1]),
								  TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + elts[0])),
						TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + elts[2]));
				}
				return result;
			}

			@Override
			public Map<String,File> getIncludePath() {
				if (cf.has("packages") ) {
					Map<String,File> result = HashMapFactory.make();
					JSONArray packages = cf.getJSONArray("packages");
					for(int i =  0; i < packages.length(); i++) {
						String elt = packages.getString(i);
						String[] elts = elt.split("[=]");
						result.put(elts[0], getFile(configFile.getParentFile(), elts[1]));
					}
					return result;
				} else {
					return Collections.emptyMap();
				}
			}
			
		};
	}
}
