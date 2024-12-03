from setuptools import setup, find_packages

setup(
    name="ryton",
    version="1.0",
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        'rich',
        'numba',
        'numpy',
        'Cython',
        'ray',
        'dask',
        'pyfiglet'
    ],
    entry_points={
        'console_scripts': [
            'ryton=ryton_launcher:main',
        ],
    }
)
