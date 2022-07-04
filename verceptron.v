module main

import rand
import math
import stbi

const (
	width      = 20
	height     = 20
	resolution = width * height // 400 pixels
	bias       = 5
)

struct Vector {
mut:
	e [][]u8
}

struct PngConfig {
	channels int

	inputs Vector
}

type Pixel = [4]u8

fn png_sigmoid(x int) u8 {
	return u8(1 / (1 + math.pow(math.e, -(f64(x) - 637.5))))
}

fn png_input_value(p Pixel) u8 {
	return png_sigmoid((p[0] + p[1] + p[2] + p[3]))
}

// fn load_inputs_from_png(image stbi.Image) ?PngConfig {
// 	// image.ok is always true:
// 	// https://github.com/vlang/v/blob/master/vlib/stbi/stbi.c.v#L88
// 	if image.width != width || image.height != height {
// 		return error('invalid file dimensions, should be 20x20')
// 	}
// 	data := unsafe { image.data.vbytes(resolution * image.nr_channels) }
// 	mut inputs := Vector{
// 		e: [][]u8{cap: height, init: []u8{cap: width}}
// 	}
// 	// for i := 0; i < data.len; i += width*image.nr_channels {
// 	// 	mut line := []u8{cap: width}
// 	// 	for j in 0 .. width {
// 	// 		p := width*image.nr_channels
// 	// 		println('$i $j $p+$j')
// 	// 		line << png_input_value(Pixel([4]u8{init: data[it+i+j..it+i+j]}))
// 	// 	}
// 	// 	inputs.e << line

// 	// 	// for j in 0 .. width {
// 	// 	// 	line <<
// 	// 	// }
// 	// 	// inputs.e << line
// 	// }
// 	// println(inputs.e)

// 	// for i in inputs.e {
// 	// 	for j in i {
// 	// 		j <<
// 	// 	}
// 	// }

// 	return PngConfig{
// 		channels: image.nr_channels
// 		inputs: inputs
// 	}
// }

// fn create_weights(width int, height int) Vector {
// 	return Vector{
// 		e: [][]u8{len: height, init: []u8{len: width}}
// 	}
// }

fn (a Vector) * (b Vector) u8 {
	if a.e.len == 0 || b.e.len == 0 {
		panic('vectors may not be empty')
	} else if a.e.len != b.e.len {
		panic('a.e.len != b.e.len')
	}
	mut accumulator := u8(0)
	for y in 0 .. a.e.len {
		if a.e[y].len != b.e[y].len {
			panic('a.e[$y].len != b.e[$y].len')
		}
		for x in 0 .. a.e[y].len {
			accumulator += a.e[y][x] * b.e[y][x]
		}
	}
	return accumulator
}

fn (a Vector) + (b Vector) Vector {
	if a.e.len == 0 || b.e.len == 0 {
		panic('vectors may not be empty')
	} else if a.e.len != b.e.len {
		panic('a.e.len != b.e.len')
	}
	mut updated := Vector{
		e: [][]u8{len: a.e.len, init: []u8{len: a.e[0].len}}
	}
	for y in 0 .. a.e.len {
		if a.e[y].len != b.e[y].len {
			panic('a.e[$y].len != b.e[$y].len')
		}
		for x in 0 .. a.e[y].len {
			updated.e[y][x] += a.e[y][x] + b.e[y][x]
		}
	}
	return updated
}

// fn rand_rect(width int, height int) ?Vector {
// 	rect := Vector{
// 		e: []u8{cap: width*height}
// 	}
// 	w := rand.int_in_range(0, width)?
// 	h := rand.int_in_range(0, height)?

// }

// fn rand_circle() Vector

// fn main() {
// 	rand.seed([u32(1), u32(1)])
// 	img := stbi.load('verceptron-input.png')?
// 	input_config := load_inputs_from_png(img)?
// 	// mut weights := create_weights(width, height)
// 	// mut dot_product := input_config.inputs * weights
// 	// for dot_product < bias {
// 	// 	weights += input_config.inputs
// 	// 	dot_product = input_config.inputs * weights
// 	// }
// 	// println(weights)
// 	// println(dot_product)
// }
