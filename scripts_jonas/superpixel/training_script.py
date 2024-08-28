import rasterio
from rasterio.windows import Window
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import argparse
from datetime import datetime, timedelta

# Define the neural network architecture (same as in the processing script)
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

# Custom dataset for loading and preprocessing raster data
class DeforestationDataset(Dataset):
    def __init__(self, input_file, ground_truth_file, reference_date):
        self.input_src = rasterio.open(input_file)
        self.ground_truth_src = rasterio.open(ground_truth_file)
        self.reference_date = reference_date
        self.num_blocks_x = self.input_src.width // 40
        self.num_blocks_y = self.input_src.height // 40

    def __len__(self):
        return self.num_blocks_x * self.num_blocks_y

    def __getitem__(self, idx):
        x = idx % self.num_blocks_x
        y = idx // self.num_blocks_x

        # Read 40x40 block from input
        window = Window(x*40, y*40, 40, 40)
        input_block = self.input_src.read(1, window=window)

        # Preprocess input
        confidence = input_block // 10000
        date = input_block % 10000
        days_since_reference = date - self.reference_date
        
        # Normalize inputs
        confidence = confidence / 100.0
        days_since_reference = days_since_reference / 365.0
        
        # Prepare input tensor
        input_tensor = torch.tensor(np.stack([confidence, days_since_reference], axis=0), dtype=torch.float32)

        # Read and preprocess ground truth
        ground_truth_block = self.ground_truth_src.read(1, window=window)
        future_deforestation = np.any((ground_truth_block % 10000 > date) & (ground_truth_block % 10000 <= date + 180))
        
        return input_tensor, torch.tensor([float(future_deforestation)], dtype=torch.float32)

    def close(self):
        self.input_src.close()
        self.ground_truth_src.close()

def train_model(input_file, ground_truth_file, reference_date, output_model_path, epochs=10, batch_size=32):
    # Initialize dataset and dataloader
    dataset = DeforestationDataset(input_file, ground_truth_file, reference_date)
    dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    # Initialize model, loss function, and optimizer
    model = DeforestationNet()
    criterion = nn.BCEWithLogitsLoss()
    optimizer = optim.Adam(model.parameters())

    # Training loop
    for epoch in range(epochs):
        running_loss = 0.0
        for i, (inputs, labels) in enumerate(dataloader):
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

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

    train_model(args.input_image, args.ground_truth_image, days_since_2015, 
                args.output_model, epochs=args.epochs, batch_size=args.batch_size)