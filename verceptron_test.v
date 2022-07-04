module main

struct VectorTest {
	a Vector
	b Vector
}

struct DotProduct {
	VectorTest
	result u8
}

struct Addition {
	VectorTest
	result Vector
}

fn test_dot_product() {
	test_cases := [
		DotProduct{
			a: Vector{
				e: [][]u8{len: 1, init: [u8(1), 2, 3]}
			}
			b: Vector{
				e: [][]u8{len: 1, init: [u8(1), 2, 3]}
			}
			result: 1 * 1 + 2 * 2 + 3 * 3
		},
		DotProduct{
			a: Vector{
				e: [][]u8{len: 2, init: [u8(1), 2, 3]}
			}
			b: Vector{
				e: [][]u8{len: 2, init: [u8(1), 2, 3]}
			}
			result: (1 * 1 + 2 * 2 + 3 * 3) * 2
		},
	]
	for test in test_cases {
		assert test.a * test.b == test.result
	}
}

fn test_addition() {
	test_cases := [
		Addition{
			a: Vector{
				e: [][]u8{len: 1, init: [u8(1), 2, 3]}
			}
			b: Vector{
				e: [][]u8{len: 1, init: [u8(1), 2, 3]}
			}
			result: Vector{
				e: [][]u8{len: 1, init: [u8(1 + 1), 2 + 2, 3 + 3]}
			}
		},
		Addition{
			a: Vector{
				e: [][]u8{len: 2, init: [u8(1), 2, 3]}
			}
			b: Vector{
				e: [][]u8{len: 2, init: [u8(1), 2, 3]}
			}
			result: Vector{
				e: [][]u8{len: 2, init: [u8(2), 4, 6]}
			}
		},
	]
	for test in test_cases {
		assert (test.a + test.b) == test.result
	}
}
