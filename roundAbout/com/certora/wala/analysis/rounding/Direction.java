package com.certora.wala.analysis.rounding;

public enum Direction {
	Inconsistent {
		@Override
		public Direction meet(Direction d) {
			return Inconsistent;
		}

		@Override
		public Direction flip() {
			return Inconsistent;
		}

		@Override
		public Direction combine(Direction d) {
			return Inconsistent;
		}
	},
	Either {
		@Override
		public Direction meet(Direction d) {
			if (d == Inconsistent) {
				return Inconsistent;
			} else {
				return Either;
			}
		}

		@Override
		public Direction flip() {
			return Either;
		}

		@Override
		public Direction combine(Direction d) {
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
		public Direction meet(Direction d) {
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
		public Direction flip() {
			return Neither;
		}

		@Override
		public Direction combine(Direction d) {
			return d;
		}
	},
	Up {
		@Override
		public Direction meet(Direction d) {
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
		public Direction flip() {
			return Down;
		}

		@Override
		public Direction combine(Direction d) {
			if (d == Up || d == Neither) {
				return Up;
			} else {
				return Inconsistent;
			}
		}
	},
	Down {
		@Override
		public Direction meet(Direction d) {
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
		public Direction flip() {
			return Up;
		}

		@Override
		public Direction combine(Direction d) {
			if (d == Down || d == Neither) {
				return Down
						;
			} else {
				return Inconsistent;
			}
		}
	};

	public abstract Direction combine(Direction d);

	public abstract Direction meet(Direction d);

	public abstract Direction flip();
};
