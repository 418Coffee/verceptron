# Verceptron – a perceptron written in V

<p align="center">
  <img src="https://github.com/418Coffee/verceptron/blob/main/example-visualisation.gif">
</p>

## Table of contents

- [Quickstart](#quickstart)
- [General Information](#general-information)
- [Known Limitations](#known-limitations)
- [References](#references)
- [Further Reading](further-reading)
- [Contributing](#contributing)
- [License](#license)

## Quickstart

1. Clone the repository:

```shell
git clone https://github.com/418Coffee/verceptron.git
cd verceptron/
```

2. You may edit same configuration variables in [`verceptron.v`](https://github.com/418Coffee/verceptron/blob/main/verceptron.v).
3. Train and test the model by running:

```shell
v run .
```

4. Or to visualise the model you may run (requires ffmpeg to be installed and added to PATH):

```shell
./visualise.sh
```

## General Information

A perceptron is essentially the simplest neural "network", consisting of a single neuron. It was invented in 1943 by McCulloch and Pitts. The first implementation of a perceptron was built in 1958 by Rosenblatt. Rosenblatt created a perceptron that was designed to classify two sets of images from a 20x20 array of cadmium sulfide photocells. It was proven by Albert Novikoff that a perceptron always converges when trained with a linearly separated data set.

This program is similair to the perceptron built by Rosenblatt, it consists of a 20x20 input grid and is trained to determine between rectangles and circles.

## Known Limitations

Single-layer perceptrons are only capable of learning linearly separable patterns. Furthermore, Marvin Minsky and Seymour Papert proved that a single layer perceptron was uncapable to learn an XOR function. The perceptron is guaranteed to converge on a solution when trained with a linearly separable training set, but there may be many solutions for the given training set, each with different quality. It is difficult to determine whether the converged on solution is the best or not.

## References

- [THE PERCEPTRON: A PROBABILISTIC MODEL FOR
  INFORMATION STORAGE AND ORGANIZATION
  IN THE BRAIN](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.335.3398&rep=rep1&type=pdf) - F. Rosenblatt
- [ON CONVERGENCE PROOFS FOR PERCEPTRONS](https://cs.uwaterloo.ca/~y328yu/classics/novikoff.pdf) - A. Novikoff
- [Future Computers Will Be Radically Different](https://www.youtube.com/watch?v=GVsUOuSjvcg) - Veritasium

## Further Reading

- [Perceptron](https://en.wikipedia.org/wiki/Perceptron)
- [Support-vector Machine](https://en.wikipedia.org/wiki/Support-vector_machine)
- Perceptrons - Marvin Minsky, Seymour Papert

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
