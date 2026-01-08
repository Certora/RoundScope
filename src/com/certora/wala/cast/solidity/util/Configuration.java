package com.certora.wala.cast.solidity.util;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.util.Collection;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;

import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.SourceFileModule;
import com.ibm.wala.util.collections.HashMapFactory;

public class Configuration {

	public static Collection<Module> getFiles(File configurationFile) throws FileNotFoundException {
		Map<String,Module> result = HashMapFactory.make();
		JSONTokener conf = new JSONTokener(new FileReader(configurationFile));
		JSONObject cf = (JSONObject) conf.nextValue();
		JSONArray files = cf.getJSONArray("files");
		for(int i = 0; i < files.length(); i++) {
			String f = files.getString(i);
			if (f.contains(":")) {
				f = f.substring(0, f.lastIndexOf(':'));
			}
			if (! result.containsKey(f)) {
				File m = new File(configurationFile.getParent(), f);
				result.put(f, new SourceFileModule(m, m.getAbsolutePath(), null));
			}
		}
		return result.values();
	}
}
