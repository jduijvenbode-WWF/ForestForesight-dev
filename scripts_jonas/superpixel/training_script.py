import rasterio
from rasterio.windows import Window
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import argparse
from datetime import datetime, timedelta

# Define the neural network architecture
class DeforestationNet(nn.Module):
    def __init__(self):
        super(DeforestationNet, self).__init__()
        # First convolutional layer: 2 input channels (confidence and date), 32 output channels
        self.conv1 = nn.Conv2d(2, 32, kernel_size=3, padding=1)
        # Second convolutional layer: 32 input channels, 64 output channels
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        # First fully connected layer: 64 * 40 * 40 input features, 128 output features
        self.fc1 = nn.Linear(64 * 40 * 40, 128)
        # Output layer: 128 input features, 1 output (probability of deforestation)
        self.fc2 = nn.Linear(128, 1)

    def forward(self, x):
        # Apply first convolutional layer followed by ReLU activation
        x = torch.relu(self.conv1(x))
        # Apply second convolutional layer followed by ReLU activation
        x = torch.relu(self.conv2(x))
        # Flatten the output for the fully connected layer
        x = x.view(-1, 64 * 40 * 40)
        # Apply first fully connected layer followed by ReLU activation
        x = torch.relu(self.fc1(x))
        # Apply output layer (no activation, as we'll use BCEWithLogitsLoss)
        x = self.fc2(x)
        return x

# Custom dataset for loading and preprocessing raster data
class DeforestationDataset(Dataset):
    def __init__(self, input_file, ground_truth_file, reference_date):
        # Open the input and ground truth raster files
        self.input_src = rasterio.open(input_file)
        self.ground_truth_src = rasterio.open(ground_truth_file)
        self.reference_date = reference_date
        # Calculate the number of 40x40 blocks in the raster
        self.num_blocks_x = self.input_src.width // 40
        self.num_blocks_y = self.input_src.height // 40

    def __len__(self):
        # The total number of 40x40 blocks in the raster
        return self.num_blocks_x * self.num_blocks_y

    def __getitem__(self, idx):
        # Convert 1D index to 2D coordinates
        x = idx % self.num_blocks_x
        y = idx // self.num_blocks_x

        # Read 40x40 block from input raster
        window = Window(x*40, y*40, 40, 40)
        input_block = self.input_src.read(1, window=window)

        # Preprocess input data
        # Extract confidence (first digit) and date (last 4 digits)
        confidence = input_block // 10000
        date = input_block % 10000
        # Calculate days since reference date
        days_since_reference = date - self.reference_date
        
        # Normalize inputs
        confidence = confidence / 100.0  # Assuming confidence is between 0-100
        days_since_reference = days_since_reference / 365.0  # Normalize to years
        
        # Prepare input tensor: stack confidence and days_since_reference
        input_tensor = torch.tensor(np.stack([confidence, days_since_reference], axis=0), dtype=torch.float32)

        # Read and preprocess ground truth
        ground_truth_block = self.ground_truth_src.read(1, window=window)
        # Check if any deforestation occurs within the next 6 months (180 days)
        future_deforestation = np.any((ground_truth_block % 10000 > date) & (ground_truth_block % 10000 <= date + 180))
        
        # Return input tensor and ground truth label
        return input_tensor, torch.tensor([float(future_deforestation)], dtype=torch.float32)

    def close(self):
        # Close the rasterio files when done
        self.input_src.close()
        self.ground_truth_src.close()

def train_model(input_file, ground_truth_file, reference_date, output_model_path, epochs=10, batch_size=32):
    # Initialize dataset and dataloader
    dataset = DeforestationDataset(input_file, ground_truth_file, reference_date)
    dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    # Initialize model, loss function, and optimizer
    model = DeforestationNet()
    # Binary Cross Entropy with Logits Loss: combines a Sigmoid layer and BCELoss in one single class
    criterion = nn.BCEWithLogitsLoss()
    # Adam optimizer with default learning rate
    optimizer = optim.Adam(model.parameters())

    # Training loop
    for epoch in range(epochs):
        running_loss = 0.0
        for i, (inputs, labels) in enumerate(dataloader):
            # Zero the parameter gradients
            optimizer.zero_grad()
            
            # Forward pass
            outputs = model(inputs)
            # Compute loss
            loss = criterion(outputs, labels)
            # Backward pass and optimize
            loss.backward()
            optimizer.step()

            # Print statistics
            running_loss += loss.item()
            if i % 100 == 99:  # Print every 100 mini-batches
                print(f'[{epoch + 1}, {i + 1:5d}] loss: {running_loss / 100:.3f}')
                running_loss = 0.0

    print('Finished Training')

    # Save the trained model
    torch.save(model.state_dict(), output_model_path)

    # Close the dataset (which closes the rasterio files)
    dataset.close()

if __name__ == "__main__":
    # Set up command-line argument parser
    parser = argparse.ArgumentParser(description="Train AI model for deforestation prediction.")
    parser.add_argument("input_image", help="Path to the input geotiff image")
    parser.add_argument("ground_truth_image", help="Path to the ground truth geotiff image (6 months in future)")
    parser.add_argument("reference_date", help="Reference date in YYYY-MM-DD format")
    parser.add_argument("output_model", help="Path to save the trained model")
    parser.add_argument("--epochs", type=int, default=10, help="Number of training epochs")
    parser.add_argument("--batch_size", type=int, default=32, help="Batch size for training")
    args = parser.parse_args()

    # Convert reference date to days since 2015-01-01
    reference_date = datetime.strptime(args.reference_date, "%Y-%m-%d")
    days_since_2015 = (reference_date - datetime(2015, 1, 1)).days

    # Train the model
    train_model(args.input_image, args.ground_truth_image, days_since_2015, 
                args.output_model, epochs=args.epochs, batch_size=args.batch_size)