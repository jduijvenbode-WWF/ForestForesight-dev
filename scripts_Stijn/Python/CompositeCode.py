import rasterio
import numpy as np

def read_raster(file_path):
    with rasterio.open(file_path) as src:
        data = src.read(1)
        profile = src.profile
    return data, profile

def calculate_composite_score(dpi_data, uncert_data):
    # Assuming the scores are 1 to 6 for both dpi and uncertainty
    composite_score = dpi_data * (7 - uncert_data)
    return composite_score

def categorize_composite_score(composite_score):
    # Define categories based on example percentiles or fixed thresholds
    categorized_score = np.zeros_like(composite_score, dtype=np.uint8)
    categorized_score[composite_score >= 30] = 6  # Very High
    categorized_score[(composite_score >= 24) & (composite_score < 30)] = 5  # High
    categorized_score[(composite_score >= 18) & (composite_score < 24)] = 4  # Medium High
    categorized_score[(composite_score >= 12) & (composite_score < 18)] = 3  # Medium Low
    categorized_score[(composite_score >= 6) & (composite_score < 12)] = 2  # Low
    categorized_score[(composite_score >= 1) & (composite_score < 6)] = 1  # Very Low
    return categorized_score

def save_raster(data, profile, output_path):
    with rasterio.open(output_path, 'w', **profile) as dst:
        dst.write(data, 1)

# Read input rasters
dpi_data, dpi_profile = read_raster("D:/temp/NewDatasetsStijn/DevelopmentIndex/Clipped2/lulc-development-potential-indices_nmm_dpi_classes_geographic_clipped2.tif")
uncert_data, uncert_profile = read_raster("D:/temp/NewDatasetsStijn/DevelopmentIndex/Clipped2/lulc-development-potential-indices_nmm_uncert_geographic_clipped2.tif")

# Calculate composite score
composite_score = calculate_composite_score(dpi_data, uncert_data)
save_raster(composite_score, dpi_profile, "D:/temp/NewDatasetsStijn/DevelopmentIndex/CompositeScore/composite_score_nmm.tif")

# Categorize composite score
categorized_score = categorize_composite_score(composite_score)
save_raster(categorized_score, dpi_profile, "D:/temp/NewDatasetsStijn/DevelopmentIndex/CompositeScore/categorized_score_nmm.tif")
