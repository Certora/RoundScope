package com.certora.roundAbout;

import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;

import com.github.erosb.jsonsKema.JsonParser;
import com.github.erosb.jsonsKema.Schema;
import com.github.erosb.jsonsKema.SchemaLoader;
import com.github.erosb.jsonsKema.ValidationFailure;
import com.github.erosb.jsonsKema.Validator;

public class AnalysisRunner {
	private static final String JGF_SCHEMA_RESOURCE = "/schemas/json-graph-schema_v2.json";
	private static final Schema JGF_SCHEMA = loadSchema();

	private static Schema loadSchema() {
		try (InputStream schemaStream = AnalysisRunner.class.getResourceAsStream(JGF_SCHEMA_RESOURCE)) {
			if (schemaStream == null) {
				throw new IllegalStateException("Missing bundled schema resource " + JGF_SCHEMA_RESOURCE);
			}
			return new SchemaLoader(new JsonParser(schemaStream).parse()).load();
		} catch (IOException e) {
			throw new IllegalStateException("Failed to load bundled schema resource " + JGF_SCHEMA_RESOURCE, e);
		}
	}

	protected static void validateJSON(String outFile) throws FileNotFoundException {
		Validator validator = Validator.forSchema(JGF_SCHEMA);
		ValidationFailure failure = validator.validate(new JsonParser(new FileReader(outFile)).parse());
		if (failure != null) {
			System.err.println(failure);
		}
	}

}
