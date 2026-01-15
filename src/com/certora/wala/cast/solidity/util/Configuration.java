package com.certora.wala.cast.solidity.util;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.util.Collection;
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
	}
	
	public static Conf getConf(File configFile) throws FileNotFoundException {
		JSONTokener conf = new JSONTokener(new FileReader(configFile));
		JSONObject cf = (JSONObject) conf.nextValue();
		
		String spec = cf.getString("verify");
		if (spec.contains(":")) {
			spec = spec.substring(spec.lastIndexOf(':')+1, spec.length());
		}
		File rulesFile = new File(configFile.getParent(), spec);
		
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
						File m = new File(configFile.getParent(), f);
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
								  TypeReference.findOrCreate(SolidityTypes.solidity, elts[0])),
						TypeReference.findOrCreate(SolidityTypes.solidity, elts[2]));
				}
				return result;
			}
			
		};
	}
}
