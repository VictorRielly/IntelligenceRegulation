"""
Setup file for Computation Identification package.
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="computation-identification",
    version="0.1.0",
    author="Intelligence Regulation Project",
    description="Package for identifying and verifying AI model computations using sequential hashing",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=find_packages(),
    python_requires=">=3.8",
    install_requires=[
        "torch>=2.0.0",
        "transformers>=4.30.0",
        "accelerate>=0.20.0",
        "numpy>=1.17",
    ],
    entry_points={
        "console_scripts": [
            "computation-chat=ComputationIdentification.main:main",
        ],
    },
)

