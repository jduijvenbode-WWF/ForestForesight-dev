#!/bin/bash

# Define the name of your Conda environment
ENV_NAME="deforestation_ai"

# Create a new Conda environment
conda create -n $ENV_NAME python=3.8 -y

# Activate the environment
conda activate $ENV_NAME

# Install packages using pip
pip install numpy==1.21.0
pip install rasterio==1.2.10
pip install torch==1.9.0+cpu torchvision==0.10.0+cpu -f https://download.pytorch.org/whl/torch_stable.html
pip install argparse==1.4.0

# Verify the installations
python -c "import numpy; print(f'NumPy version: {numpy.__version__}')"
python -c "import rasterio; print(f'Rasterio version: {rasterio.__version__}')"
python -c "import torch; print(f'PyTorch version: {torch.__version__}')"
python -c "import argparse; print(f'Argparse version: {argparse.__version__}')"

echo "Environment setup complete. To activate this environment, use:"
echo "conda activate $ENV_NAME"
