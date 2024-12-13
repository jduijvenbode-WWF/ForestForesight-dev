import argparse
import os

class ResourceNotFoundError(Exception):
    pass

class RasterNotExistError(Exception):
    pass

class RasterNotSupportedError(Exception):
    pass

class TemplateNotFoundError(Exception):
    pass

def process_raster(image_path, output_path, country, date, upload, overwrite):
    if not is_single_band_continuous_image(image_path):
        raise RasterNotSupportedError(f'Raster Not Supported: {image_path}')

    project = arcpy.mp.ArcGISProject(template)
    active_map = project.listMaps()[0]

    # Add raster layer to the map
    lyr = arcpy.management.MakeRasterLayer(image_path, 'image')[0]
    lyr = arcpy.ApplySymbologyFromLayer_management(lyr, temp_lyr)[0]

    print(f"Processing {image_path}")
    print(lyr.symbology.colorizer.stretchType)
    active_map.addLayer(lyr)

    arcpy.management.CreateMapTilePackage(
        in_map=active_map,
        service_type="ONLINE",
        output_file=output_path,
        format_type="PNG8",
        level_of_detail=13,
        service_file=None,
        summary="Map Tile",
        tags="",
        extent="DEFAULT",
        compression_quality=75,
        package_type="tpkx",
        min_level_of_detail=1,
        create_multiple_packages="CREATE_SINGLE_PACKAGE",
    )
    
    if upload:
        arcpy.management.SharePackage(
            in_package=output_path,
            username="",
            password='',
            summary=f"Predictions of Forest Foresight for {country} for {date}",
            tags="ForestForesight",
            credits="ForestForesight WWF-NL",
            public="MYGROUPS",
            groups="'Forest Foresight'",
            organization="EVERYBODY",
            publish_web_layer="TRUE",
            portal_folder=""
        )
    
    if overwrite and upload:
        layer_name = os.path.splitext(os.path.basename(output_path))[0]
        arcpy.server.ReplaceWebLayer(
            target_layer=f"https://tiles.arcgis.com/tiles/RTK5Unh1Z71JKIiR/arcgis/rest/services/{layer_name}/MapServer",
            archive_layer_name=f"{layer_name}_archive",
            update_layer=f"https://tiles.arcgis.com/tiles/RTK5Unh1Z71JKIiR/arcgis/rest/services/{layer_name[0:(len(layer_name)-11)]}/MapServer",
            replace_item_info="TRUE",
            create_new_item="FALSE"
        )

ws = os.path.dirname(__file__)
template = os.path.join(ws, r'temps\template.aprx')
temp_lyr = os.path.join(ws, r"temps\lyr.lyrx")

if not os.path.exists(template) or not os.path.exists(temp_lyr):
    raise TemplateNotFoundError('Template Not Found (folder named temps in same location as python script)')
    
parser = argparse.ArgumentParser(description='Map tile package script')
parser.add_argument('input_folder', type=str, help='Input folder containing TIF files')
parser.add_argument('country', type=str, help='name of country')
parser.add_argument('date', type=str, help='date of processing')
parser.add_argument('upload', type=str, help='whether the tile package should be uploaded')
parser.add_argument('overwrite', type=str, help='whether a previous version should be overwritten')

args = parser.parse_args()
input_folder = args.input_folder
country = args.country
date = args.date
upload = int(args.upload)
overwrite = int(args.overwrite)

if not os.path.exists(input_folder):
    raise ResourceNotFoundError("Input folder does not exist")

import arcpy

def is_single_band_continuous_image(raster_path):
    if not arcpy.Exists(raster_path):
        raise RasterNotExistError(f"Raster dataset does not exist: {raster_path}")
        
    try:
        raster = arcpy.Raster(raster_path)
        # Check if the raster has only one band
        if raster.bandCount == 1:
            # Check if the pixel type is continuous
            if raster.pixelType.lower() in ['f32', 'f64', 'u32', 's32', 'u16', 's16']:
                return True
    except Exception as e:
        raise RasterNotSupportedError(f'Raster Not Supported: {raster_path}')
    return False

# Process all TIF files in the input folder
for filename in os.listdir(input_folder):
    if filename.lower().endswith('.tif'):
        input_path = os.path.join(input_folder, filename)
        output_filename = os.path.splitext(filename)[0] + '.tpkx'
        output_path = os.path.join(input_folder, output_filename)
        
        try:
            process_raster(input_path, output_path, country, date, upload, overwrite)
            print(f"Successfully processed {filename}")
        except Exception as e:
            print(f"Error processing {filename}: {str(e)}")
            continue