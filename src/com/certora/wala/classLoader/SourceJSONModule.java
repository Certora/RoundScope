package com.certora.wala.classLoader;

import org.json.JSONObject;

import com.ibm.wala.classLoader.SourceModule;

public interface SourceJSONModule extends SourceModule {

	JSONObject getJSON();
	 
}
