module main

import rand
import rand.seed
import math
import stbi

const (
	width         = 20
	height        = 20
	resolution    = width * height // 400 pixels

	min_width     = int(math.ceil(f32(width) * 0.1))
	min_height    = int(math.ceil(f32(height) * 0.1))
	min_radius    = (width + height) / width

	max_rounds    = 50_000
	training_size = 8
	bias          = 20
)

struct Vector {
mut:
	e [][]i8
}

struct PngConfig {
	channels int

	inputs Vector
}

type Pixel = [4]u8

fn png_sigmoid(x int) i8 {
	return i8(1 / (1 + math.pow(math.e, -(f64(x) - 637.5))))
}

fn png_input_value(p Pixel) i8 {
	return png_sigmoid((p[0] + p[1] + p[2] + p[3]))
}

fn load_inputs_from_png(image stbi.Image) ?PngConfig {
	// image.ok is always true:
	// https://github.com/vlang/v/blob/master/vlib/stbi/stbi.c.v#L88
	if image.width != width || image.height != height {
		return error('invalid file dimensions: ${image.width}x$image.width, should be ${width}x$height')
	}
	// TODO:
	// clone the bytes AND free the original ones?
	data := unsafe { image.data.vbytes(resolution * image.nr_channels).clone() }
	mut inputs := Vector{
		e: [][]i8{cap: height}
	}
	mut line := []i8{cap: width}
	for i := 0; i < data.len; i += 4 {
		$if macos {
			line << png_input_value(Pixel([data[i], data[i+1], data[i+2], data[i+3]]!))
		} $else {
			// This is causes issues on macos: 
			// https://github.com/418Coffee/verceptron/runs/7198810267?check_suite_focus=true
			line << png_input_value(Pixel([4]u8{init: data[i + it]}))
		}
		
		if line.len == width {
			inputs.e << line
			line = []i8{cap: width}
		}
	}
	return PngConfig{
		channels: image.nr_channels
		inputs: inputs
	}
}

fn create_weights(width int, height int) Vector {
	return Vector{
		e: [][]i8{len: height, init: []i8{len: width}}
	}
}

fn (a Vector) * (b Vector) i8 {
	if a.e.len == 0 || b.e.len == 0 {
		panic('vectors may not be empty')
	} else if a.e.len != b.e.len {
		panic('a.e.len != b.e.len: $a.e.len != $b.e.len')
	}
	mut accumulator := i8(0)
	for y in 0 .. a.e.len {
		if a.e[y].len != b.e[y].len {
			panic('a.e[$y].len=${a.e[y].len} != b.e[$y].len=${b.e[y].len}')
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
		panic('a.e.len=$a.e.len != b.e.len=$b.e.len')
	}
	mut updated := Vector{
		e: [][]i8{len: a.e.len, init: []i8{cap: a.e[0].len}}
	}
	for y in 0 .. a.e.len {
		if a.e[y].len != b.e[y].len {
			panic('a.e[$y].len=${a.e[y].len} != b.e[$y].len=${b.e[y].len}')
		}
		for x in 0 .. a.e[y].len {
			updated.e[y] << a.e[y][x] + b.e[y][x]
		}
	}
	return updated
}

fn (a Vector) - (b Vector) Vector {
	if a.e.len == 0 || b.e.len == 0 {
		panic('vectors may not be empty')
	} else if a.e.len != b.e.len {
		panic('a.e.len=$a.e.len != b.e.len=$b.e.len')
	}
	mut updated := Vector{
		e: [][]i8{len: a.e.len, init: []i8{cap: a.e[0].len}}
	}
	for y in 0 .. a.e.len {
		if a.e[y].len != b.e[y].len {
			panic('a.e[$y].len=${a.e[y].len} != b.e[$y].len=${b.e[y].len}')
		}
		for x in 0 .. a.e[y].len {
			updated.e[y] << a.e[y][x] - b.e[y][x]
		}
	}
	return updated
}

fn clampi(x int, a int, b int) int {
	if x < a {
		return a
	}
	if x > b {
		return b
	}
	return x
}

fn fill_rect(mut vector Vector, x int, y int, w int, h int, value i8) {
	if w < 0 || h < 0 {
		panic('w=$w < 0 || h=$h < 0')
	}
	x0 := clampi(x, 0, width - 1)
	y0 := clampi(y, 0, height - 1)
	x1 := clampi(x0 + w - 1, 0, width - 1)
	y1 := clampi(y0 + h - 1, 0, height - 1)
	for yy := y0; yy <= y1; yy++ {
		for xx := x0; xx <= x1; xx++ {
			vector.e[yy][xx] = value
		}
	}
}

fn fill_circle(mut vector Vector, cx int, cy int, r int, value i8) {
	if r < 0 {
		panic('r=$r < 0')
	}
	x0 := clampi(cx - r, 0, width - 1)
	y0 := clampi(cy - r, 0, height - 1)
	x1 := clampi(cx + r, 0, width - 1)
	y1 := clampi(cy + r, 0, height - 1)
	for yy := y0; yy <= y1; yy++ {
		for xx := x0; xx <= x1; xx++ {
			dx := xx - cx
			dy := yy - cy
			if dx * dx + dy * dy <= r * r {
				vector.e[yy][xx] = value
			}
		}
	}
}

fn rand_rect(width int, height int) ?Vector {
	mut rect := Vector{
		e: [][]i8{len: height, init: []i8{len: width}}
	}
	// int_in_range's interval is [a, b) so to "correct" it to [a, b] we do [a, b+1)
	y := rand.int_in_range(0, height - min_height + 1)?
	x := rand.int_in_range(0, width - min_width + 1)?
	mut h := height - y
	mut w := width - x
	if h <= min_height {
		h = min_height
	} else {
		h = rand.int_in_range(min_height, h)?
	}
	if w <= min_width {
		w = min_width
	} else {
		w = rand.int_in_range(min_width, w)?
	}
	fill_rect(mut rect, x, y, w, h, 1)
	return rect
}

fn rand_circle(width int, height int) ?Vector {
	mut circle := Vector{
		e: [][]i8{len: height, init: []i8{len: width}}
	}
	// int_in_range's interval is [a, b) so to "correct" it to [a, b] we do [a, b+1)
	cy := rand.int_in_range(0, height - min_height + 1)?
	cx := rand.int_in_range(0, width - min_width + 1)?
	mut r := math.max_i32
	if r > cx {
		r = cx
	}
	if r > cy {
		r = cy
	}
	if r > width - cx {
		r = width - cx
	}
	if r > height - cy {
		r = height - cx
	}
	if r <= min_radius {
		r = min_radius
	} else {
		r = rand.int_in_range(min_radius, r)?
	}
	// println("cx:$cx cy:$cy r:$r")
	fill_circle(mut circle, cx, cy, r, 1)
	return circle
}

fn main() {
	// rand.seed([u32(1), u32(2)])
	println('seed: $seed.time_seed_64()')

	mut weights := create_weights(width, height)
	mut correctly_identified := 0
	mut round := 1
	for correctly_identified < training_size * 2 {
		correctly_identified = 0
		for i := 0; i < training_size; i++ {
			circle := rand_circle(width, height)?
			mut output := (circle * weights) > bias
			if output {
				correctly_identified++
			} else {
				weights += circle
			}
			rect := rand_rect(width, height)?
			output = (rect * weights) > bias
			if output {
				weights -= rect
			} else {
				correctly_identified++
			}
		}
		if round % 1000 == 0 {
			println('round $round: $correctly_identified correctly identified')
		}
		if round == max_rounds {
			println('failed to converge after $round rounds')
			return
		}
		round++
	}
	println('converged after $round rounds')
	println(weights)
	println('testing on rectangle.png')
	img := stbi.load('rectangle.png')?
	input_config := load_inputs_from_png(img)?
	output := (input_config.inputs * weights)
	if output > bias {
		println('FAILED: $output > $bias')
	} else {
		println('SUCCESS: $output')
	}
}
