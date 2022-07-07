module main

import os
import rand
import rand.seed
import math
import stbi

const (
	width               = 20
	height              = 20
	resolution          = width * height // 400 pixels

	min_width           = int(math.ceil(f32(width) * 0.1))
	min_height          = int(math.ceil(f32(height) * 0.1))
	min_radius          = (width + height) / width

	max_rounds          = 50_000
	training_size       = 10
	test_size           = training_size
	bias                = 1

	ppm_scalar          = 25
	ppm_color_intensity = 255
	ppm_range           = 5
	ppm_folder          = 'data'
)

// Vector is an n-dimensional vector chunked in to a 2-dimensional array.
struct Vector {
mut:
	e [][]i8
}

fn (v Vector) save_as_ppm(path string) ? {
	mut f := os.create(path)?
	f.writeln('P6\n${width * ppm_scalar} ${height * ppm_scalar} $ppm_color_intensity')?
	for y := 0; y < height * ppm_scalar; y++ {
		for x := 0; x < width * ppm_scalar; x++ {
			s := f32((v.e[y / ppm_scalar][x / ppm_scalar] + ppm_range)) / (2.0 * ppm_range)
			pixel := [u8(math.floor(ppm_color_intensity * s)),
				u8(math.floor(ppm_color_intensity * (1 - s))),
				u8(math.floor(ppm_color_intensity * (1 - s)))]
			f.write(pixel)?
		}
	}
	f.close()
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
			line << png_input_value(Pixel([data[i], data[i + 1], data[i + 2], data[i + 3]]!))
		} $else {
			// This causes issues on macos:
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

// fit_circle returns modified copies of cx and cy that are adjusted to fit into width and height with respect to r.
// For expected correct results: r*2 MUST NOT be >= width OR >= height
fn fit_circle(cx int, cy int, r int, width int, height int) (int, int) {
	mut acx := cx
	mut acy := cy
	if cx + r >= width { // overlaps on east side
		acx -= (r + cx + 1) - width
	} else if cx - r <= 0 { // overlaps on west side
		acx += r - cx
	}
	if cy - r <= 0 { // overlaps on north side
		acy += r - cy
	} else if cy + r >= height { // overlaps on south side
		acy -= (r + cy + 1) - height
	}
	return acx, acy
}

fn rand_circle(width int, height int) ?Vector {
	mut circle := Vector{
		e: [][]i8{len: height, init: []i8{len: width}}
	}
	// int_in_range's interval is [a, b) so to "correct" it to [a, b] we do [a, b+1)
	mut cy := rand.int_in_range(0, height - min_height + 1)?
	mut cx := rand.int_in_range(0, width - min_width + 1)?
	mut r := rand.int_in_range(min_radius, int(math.floor((width + height) / 4)))?
	cx, cy = fit_circle(cx, cy, r, width, height)
	fill_circle(mut circle, cx, cy, r, 1)
	return circle
}

// train_model adjusts weights until all tests are correctly identified OR testing took over max_rounds rounds.
// Returned is the amount of times the weights were adjusted and how many rounds of adjusting it took to correctly identify all tests respectively.
// If save_weights is true weights is saved in the ppm_folder folder after each adjustment.
fn train_model(mut weights Vector, training_size int, save_weights bool) ?(int, int) {
	mut correctly_identified := 0
	mut adjustments := 0
	mut round := 1

	mut test_circles := []Vector{cap: training_size}
	mut test_rectangles := []Vector{cap: training_size}
	for _ in 0 .. training_size {
		test_circles << rand_circle(width, height)?
		test_rectangles << rand_rect(width, height)?
	}
	// Each round we test one random circle and one random rectangle
	// We loop until the weights converge and correctly identify the test data set.
	for correctly_identified < training_size * 2 {
		correctly_identified = 0
		mut adj := 0
		for i := 0; i < training_size; i++ {
			circle := test_circles[i]
			mut output := (circle * weights) > bias
			if output {
				correctly_identified++
			} else {
				weights = weights + circle // can't use +=
				if save_weights {
					weights.save_as_ppm('$ppm_folder/weights-${adjustments:05}.ppm')?
				}
				adj++
				adjustments++
			}
			rectangle := test_rectangles[i]
			output = (rectangle * weights) > bias
			if output {
				weights = weights - rectangle // can't use -=
				if save_weights {
					weights.save_as_ppm('$ppm_folder/weights-${adjustments:05}.ppm')?
				}
				adj++
				adjustments++
			} else {
				correctly_identified++
			}
		}
		println('round $round: $adj adjustments')
		if round == max_rounds {
			return error('failed to converge after $round rounds')
		}
		round++
	}
	return adjustments, round
}

// test_model tests the accuray of weights in a series of tests with the size of test_size.
// Returned is the rate of success of identifying the test cases.
fn test_model(weights Vector, test_size int) ?f64 {
	mut correctly_identified := f32(0)
	mut test_circles := []Vector{cap: training_size}
	mut test_rectangles := []Vector{cap: training_size}
	for _ in 0 .. training_size {
		test_circles << rand_circle(width, height)?
		test_rectangles << rand_rect(width, height)?
	}
	for i := 0; i < test_size; i++ {
		circle := test_circles[i]
		mut output := (circle * weights) > bias
		if output {
			correctly_identified++
		}
		rectangle := test_rectangles[i]
		output = (rectangle * weights) > bias
		if !output {
			correctly_identified++
		}
	}
	return correctly_identified / (test_size * 2)
}

fn main() {
	if !os.is_dir(ppm_folder) {
		os.mkdir(ppm_folder, os.MkdirParams{})?
	}

	seed := seed.time_seed_array(2)
	rand.seed(seed)
	println('seed: $seed')

	mut save_weights := false
	if $env('SAVE_WEIGHTS') == '1' {
		save_weights = true
	}

	mut weights := create_weights(width, height)
	success_rate_untrained := test_model(weights, training_size)?
	println('success rate of untrained model: ${success_rate_untrained:.2f}')
	adjustments, rounds := train_model(mut weights, training_size, save_weights) or {
		panic('err: $err')
	}
	println('converged, made $adjustments adjustments over $rounds rounds')
	success_rate_trained := test_model(weights, training_size)?
	println('success rate of trained model: ${success_rate_trained:.2f}')

	// println('testing on rectangle.png')
	// img := stbi.load('rectangle.png')?
	// input_config := load_inputs_from_png(img)?
	// img.free()?
	// output := (input_config.inputs * weights)
	// if output > bias {
	// 	println('FAILED: $output > $bias')
	// } else {
	// 	println('SUCCESS: $output')
	// }
}
