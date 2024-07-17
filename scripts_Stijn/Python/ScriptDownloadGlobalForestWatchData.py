import requests

def download_file(url, filename):
    print(f"Attempting to download: {url}")  # Log the URL being accessed
    response = requests.get(url)
    if response.status_code == 200:
        with open(filename, 'wb') as file:
            file.write(response.content)
        print(f"File downloaded successfully: {filename}")
    else:
        print(f"Failed to download file: {filename}. Status code: {response.status_code}")

def generate_filenames_and_urls():
    latitudes = range(30, -31, -10)  # From 30 to -30 with a step of -10
    longitudes = list(range(-180, 180, 10)) + [170]  # From -180 to 170 with a step of 10

    base_url = 'https://storage.googleapis.com/earthenginepartners-hansen/GFC-2023-v1.11/Hansen_GFC-2023-v1.11_lossyear_'
    directory = 'C:/Users/admin/Documents/Newdatasets/Forest Mask 2023/'

    for lat in latitudes:
        lat_prefix = f"{abs(lat)}N" if lat >= 0 else f"{abs(lat)}S"
        for lon in longitudes:
            lon_prefix = f"{abs(lon):03}W" if lon < 0 else f"{abs(lon):03}E"
            filename = f"{directory}Hansen_GFC-2023-v1.11_lossyear_{lat_prefix}_{lon_prefix}.tif"
            url = f"{base_url}{lat_prefix}_{lon_prefix}.tif"
            download_file(url, filename)

# Call the function to start the download process
generate_filenames_and_urls()



