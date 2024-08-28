import rasterio
from rasterio.windows import Window
import numpy as np
import argparse
import os
from datetime import datetime, timedelta
import torch
import torch.nn as nn
import torch.optim as optim

# Define the neural network architecture
class DeforestationNet(nn.Module):
    def __init__(self):
        super(DeforestationNet, self).__init__()
        self.conv1 = nn.Conv2d(2, 32, kernel_size=3, padding=1)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        self.fc1 = nn.Linear(64 * 40 * 40, 128)
        self.fc2 = nn.Linear(128, 1)

    def forward(self, x):
        x = torch.relu(self.conv1(x))
        x = torch.relu(self.conv2(x))
        x = x.view(-1, 64 * 40 * 40)
        x = torch.relu(self.fc1(x))
        x = self.fc2(x)
        return x

def process_block(block, model, reference_date):
    # Separate confidence and date
    confidence = block // 10000
    date = block % 10000
    
    # Convert date to days since reference_date
    days_since_reference = date - reference_date
    
    # Normalize inputs
    confidence = confidence / 100.0  # Assuming confidence is between 0-100
    days_since_reference = days_since_reference / 365.0  # Normalize to years
    
    # Prepare input tensor
    input_tensor = torch.tensor(np.stack([confidence, days_since_reference], axis=0), dtype=torch.float32).unsqueeze(0)
    
    # Process with neural network
    with torch.no_grad():
        output = model(input_tensor)
    
    return output.item()

def process_geotiff(input_file, output_file, reference_date, model_path):
    # Load the trained model
    model = DeforestationNet()
    model.load_state_dict(torch.load(model_path))
    model.eval()

    with rasterio.open(input_file) as src:
        # Get the dimensions of the raster
        width = src.width
        height = src.height

        # Calculate the number of 40x40 blocks
        num_blocks_x = width // 40
        num_blocks_y = height // 40

        # Prepare the output array
        output_data = np.zeros((num_blocks_y, num_blocks_x), dtype=np.float32)

        # Process each 40x40 block
        for y in range(num_blocks_y):
            for x in range(num_blocks_x):
                # Read 40x40 block
                window = Window(x*40, y*40, 40, 40)
                block = src.read(1, window=window)
                
                # Process the block
                result = process_block(block, model, reference_date)
                
                # Store the result
                output_data[y, x] = result

        # Write the output
        transform = src.transform * src.transform.scale(40, 40)
        with rasterio.open(output_file, 'w', driver='GTiff', height=num_blocks_y, width=num_blocks_x,
                           count=1, dtype=np.float32, crs=src.crs, transform=transform) as dst:
            dst.write(output_data, 1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Apply AI processing to a geotiff image.")
    parser.add_argument("input_image", help="Path to the input geotiff image")
    parser.add_argument("output_image", help="Path to the output geotiff image")
    parser.add_argument("reference_date", help="Reference date in YYYY-MM-DD format")
    parser.add_argument("model_path", help="Path to the trained model")
    args = parser.parse_args()

    # Convert reference date to days since 2015-01-01
    reference_date = datetime.strptime(args.reference_date, "%Y-%m-%d")
    days_since_2015 = (reference_date - datetime(2015, 1, 1)).days

    process_geotiff(args.input_image, args.output_image, days_since_2015, args.model_path)