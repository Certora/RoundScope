package com.certora.wala.analysis.rounding;

public enum Direction {
	Inconsistent {
		@Override
		Direction meet(Direction d) {
			return Inconsistent;
		}

		@Override
		Direction flip() {
			return Inconsistent;
		}

		@Override
		Direction combine(Direction d) {
			return Inconsistent;
		}
	},
	Either {
		@Override
		Direction meet(Direction d) {
			if (d == Inconsistent) {
				return Inconsistent;
			} else {
				return Either;
			}
		}

		@Override
		Direction flip() {
			return Either;
		}

		@Override
		Direction combine(Direction d) {
			switch (d) {
			case Neither:
				return Either;
			default:
				return Inconsistent;
			}
		}
	},
	Neither {
		@Override
		Direction meet(Direction d) {
			switch (d) {
			case Neither:
				return Neither;
			case Up:
				return Up;
			case Down:
				return Down;
			case Either:
				return Either;
			case Inconsistent:
				return Inconsistent;
			default:
				return Inconsistent;
			}
		}

		@Override
		Direction flip() {
			return Neither;
		}

		@Override
		Direction combine(Direction d) {
			return d;
		}
	},
	Up {
		@Override
		Direction meet(Direction d) {
			switch (d) {
			case Neither:
				return Up;
			case Up:
				return Up;
			case Down:
				return Either;
			case Either:
				return Either;
			case Inconsistent:
				return Inconsistent;
			default:
				return Inconsistent;
			}
		}

		@Override
		Direction flip() {
			return Down;
		}

		@Override
		Direction combine(Direction d) {
			if (d == Up || d == Neither) {
				return Up;
			} else {
				return Inconsistent;
			}
		}
	},
	Down {
		@Override
		Direction meet(Direction d) {
			switch (d) {
			case Neither:
				return Down;
			case Up:
				return Either;
			case Down:
				return Down;
			case Either:
				return Either;
			case Inconsistent:
				return Inconsistent;
			default:
				return Inconsistent;
			}
		}

		@Override
		Direction flip() {
			return Up;
		}

		@Override
		Direction combine(Direction d) {
			if (d == Down || d == Neither) {
				return Down
						;
			} else {
				return Inconsistent;
			}
		}
	};

	abstract Direction combine(Direction d);

	abstract Direction meet(Direction d);

	abstract Direction flip();
};
