package com.certora.wala.cast.solidity.json;

public interface JsonNodeTypeOnlyVisitor<R> extends JsonNodeTypeVisitor<R, Void> {

	default Class<Void> context() {
		return Void.class;
	}
}
