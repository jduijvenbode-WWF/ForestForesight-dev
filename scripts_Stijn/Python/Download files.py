import requests
import os

def download_tiles(base_url, lat_range, lon_range, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)  # Create the output directory if it doesn't exist

    for lat in lat_range:
        for lon in lon_range:
            lat_prefix = f"{abs(lat)}{'N' if lat >= 0 else 'S'}"
            lon_prefix = f"{abs(lon):03d}{'E' if lon >= 0 else 'W'}"
            filename = f"Hansen_GFC-2023-v1.11_lossyear_{lat_prefix}_{lon_prefix}.tif"
            url = f"{base_url}/{filename}"
            response = requests.get(url, stream=True)
            
            if response.status_code == 200:
                output_path = os.path.join(output_dir, filename)
                with open(output_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                print(f"Downloaded {filename}")
            else:
                print(f"Failed to download {filename}")

# URL and path configuration
base_url = "https://storage.googleapis.com/earthenginepartners-hansen/GFC-2023-v1.11"
lat_range = list(range(30, -31, -10))  # 30N to 30S
lon_range = list(range(-180, 181, 10))  # 180W to 180E
output_dir = "C:/Users/admin/Documents/Newdatasets/Forest Mask 2023/download lossyear"

# Download tiles
download_tiles(base_url, lat_range, lon_range, output_dir)

