import matplotlib.pyplot as plt
import numpy as np

class MatPlotUp:
    def __init__(self, ruvix_instance):
        self.ruvix = ruvix_instance

    def create_plot(self):
        fig, ax = plt.subplots()
        return fig, ax

    def plot_line(self, ax, x, y, **kwargs):
        ax.plot(x, y, **kwargs)

    def plot_scatter(self, ax, x, y, **kwargs):
        ax.scatter(x, y, **kwargs)

    def plot_bar(self, ax, x, height, **kwargs):
        ax.bar(x, height, **kwargs)

    def set_title(self, ax, title):
        ax.set_title(title)

    def set_labels(self, ax, xlabel, ylabel):
        ax.set_xlabel(xlabel)
        ax.set_ylabel(ylabel)

    def show_plot(self):
        plt.show()

    def save_plot(self, fig, filename):
        fig.savefig(filename)

def init(ruvix_instance):
    return MatPlotUp(ruvix_instance)
