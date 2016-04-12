#!/bin/env python

'''
reference : https://github.com/aymericdamien/TensorFlow-Examples/blob/master/examples/3%20-%20Neural%20Networks/recurrent_network.py
'''

import tensorflow as tf
from tensorflow.examples.tutorials.mnist import input_data
from tensorflow.models.rnn import rnn, rnn_cell
import numpy as np

def weight_variable(shape):
	initial = tf.truncated_normal(shape, stddev=0.1)
	return tf.Variable(initial)

def bias_variable(shape):
	initial = tf.constant(0.1, shape=shape)
	return tf.Variable(initial)

mnist = input_data.read_data_sets("./MNIST_data/", one_hot=True)

learning_rate = 0.001
training_iters = 100000
batch_size = 128
display_step = 10

n_input = 28   # row length of 28 x 28 image
n_steps = 28   # 28 time steps
n_hidden = 128 # hidden layer size
n_classes = 10 # output classes

x = tf.placeholder("float", [None, n_steps, n_input])
y_ = tf.placeholder("float", [None, n_classes])

# LSTM layer

# 2 x n_hidden length (state & cell)
istate = tf.placeholder("float", [None, 2*n_hidden])
weights = {
	'hidden' : weight_variable([n_input, n_hidden]),
	'out' : weight_variable([n_hidden, n_classes])
}
biases = {
	'hidden' : bias_variable([n_hidden]),
	'out': bias_variable([n_classes])
}

def RNN(_X, _istate, _weights, _biases):
	# input shape: (batch_size, n_steps, n_input)
	_X = tf.transpose(_X, [1, 0, 2])  # permute n_steps and batch_size
	# Reshape to prepare input to hidden activation
	_X = tf.reshape(_X, [-1, n_input]) # (n_steps*batch_size, n_input)
	# Linear activation
	_X = tf.matmul(_X, _weights['hidden']) + _biases['hidden']

	# Define a lstm cell with tensorflow
	lstm_cell = rnn_cell.BasicLSTMCell(n_hidden, forget_bias=1.0)
	# Split data because rnn cell needs a list of inputs for the RNN inner loop
	_X = tf.split(0, n_steps, _X) # n_steps * (batch_size, n_hidden)

	# Get lstm cell output
	outputs, states = rnn.rnn(lstm_cell, _X, initial_state=_istate)

	# Linear activation
	# Get inner loop last output
	return tf.matmul(outputs[-1], _weights['out']) + _biases['out']

y = RNN(x, istate, weights, biases)

# training
cost = tf.reduce_mean(tf.nn.softmax_cross_entropy_with_logits(y, y_)) # Softmax loss
optimizer = tf.train.AdamOptimizer(learning_rate=learning_rate).minimize(cost) # Adam Optimizer
correct_prediction = tf.equal(tf.argmax(y,1), tf.argmax(y_,1))
accuracy = tf.reduce_mean(tf.cast(correct_prediction, tf.float32))
NUM_THREADS = 5
sess = tf.Session(config=tf.ConfigProto(intra_op_parallelism_threads=NUM_THREADS,inter_op_parallelism_threads=NUM_THREADS,log_device_placement=True))
init = tf.initialize_all_variables()
sess.run(init)

step = 1
while step * batch_size < training_iters :
	batch_xs, batch_ys = mnist.train.next_batch(batch_size)
	# [batch_size, 28 x 28] -> [batch_size, n_steps, n_input]
	batch_xs = batch_xs.reshape((batch_size, n_steps, n_input))
	sess.run(optimizer, feed_dict={x: batch_xs, y_: batch_ys, istate: np.zeros((batch_size, 2*n_hidden))})
	if step % display_step == 0 :
		acc = sess.run(accuracy, feed_dict={x: batch_xs, y_: batch_ys, istate: np.zeros((batch_size, 2*n_hidden))})
		loss = sess.run(cost, feed_dict={x: batch_xs, y_: batch_ys, istate: np.zeros((batch_size, 2*n_hidden))})
		print "step : " + str(step*batch_size) + ", Minibatch Loss= " + "{:.6f}".format(loss) + ", Training Accuracy= " + "{:.5f}".format(acc)
	step += 1

# inference
test_len = 256
test_data = mnist.test.images[:test_len].reshape((-1, n_steps, n_input))
test_label = mnist.test.labels[:test_len]
print "test accuracy : ", sess.run(accuracy, feed_dict={x: test_data, y_: test_label, istate: np.zeros((test_len, 2*n_hidden))})
