import tensorflow as tf
from tensorflow import keras
import numpy as np

class NeuralNetWrapper:
    def __init__(self):
        self.model = None

    def create_model(self, layers):
        model = keras.Sequential()
        model.add(keras.layers.Input(shape=(layers[0],)))
        for units in layers[1:-1]:
            model.add(keras.layers.Dense(units, activation='relu'))
        model.add(keras.layers.Dense(layers[-1]))
        self.model = model

    def compile(self, optimizer='adam', loss='mse', metrics=['mae']):
        self.model.compile(optimizer=optimizer, loss=loss, metrics=metrics)

    def train(self, X, y, epochs, batch_size=32, validation_split=0.2):
        return self.model.fit(X, y, epochs=epochs, batch_size=batch_size, validation_split=validation_split)

    def predict(self, X):
        return self.model.predict(X)

    def evaluate(self, X, y):
        return self.model.evaluate(X, y)

    def save(self, filepath):
        self.model.save(filepath)

    def load(self, filepath):
        self.model = keras.models.load_model(filepath)

def create_neural_network(layers):
    nn = NeuralNetWrapper()
    nn.create_model(layers)
    return nn

def compile_network(network, optimizer='adam', loss='mse', metrics=['mae']):
    network.compile(optimizer, loss, metrics)

def train_network(network, X, y, epochs, batch_size=32, validation_split=0.2):
    return network.train(X, y, epochs, batch_size, validation_split)

def predict(network, X):
    return network.predict(X)

def evaluate_network(network, X, y):
    return network.evaluate(X, y)

def save_network(network, filepath):
    network.save(filepath)

def load_network(filepath):
    nn = NeuralNetWrapper()
    nn.load(filepath)
    return nn
