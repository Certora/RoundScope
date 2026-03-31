package com.certora.roundAbout;

import java.io.FileNotFoundException;
import java.io.FileReader;

import com.github.erosb.jsonsKema.JsonParser;
import com.github.erosb.jsonsKema.Schema;
import com.github.erosb.jsonsKema.SchemaLoader;
import com.github.erosb.jsonsKema.ValidationFailure;
import com.github.erosb.jsonsKema.Validator;

public class AnalysisRunner {

	protected static void validateJSON(String outFile) throws FileNotFoundException {
		Schema schema = SchemaLoader.forURL("https://raw.githubusercontent.com/jsongraph/json-graph-specification/refs/heads/master/json-graph-schema_v2.json").load();
		Validator validator = Validator.forSchema(schema);
		ValidationFailure failure = validator.validate(new JsonParser(new FileReader(outFile)).parse());
		if (failure != null) {
			System.err.println(failure);
		}
	}

}
