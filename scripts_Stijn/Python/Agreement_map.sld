<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor xmlns="http://www.opengis.net/sld" version="1.0.0" xmlns:gml="http://www.opengis.net/gml" xmlns:sld="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc">
  <UserLayer>
    <sld:LayerFeatureConstraints>
      <sld:FeatureTypeConstraint/>
    </sld:LayerFeatureConstraints>
    <sld:UserStyle>
      <sld:Name>CroplandAgreement_noRGB1000.tif</sld:Name>
      <sld:FeatureTypeStyle>
        <sld:Rule>
          <sld:RasterSymbolizer>
            <sld:ChannelSelection>
              <sld:GrayChannel>
                <sld:SourceChannelName>1</sld:SourceChannelName>
              </sld:GrayChannel>
            </sld:ChannelSelection>
            <sld:ColorMap type="values">
              <sld:ColorMapEntry quantity="0" color="#f0f0f0" label="No cropland for all layers"/>
              <sld:ColorMapEntry quantity="1" color="#ff1201" label="1 layer depicts cropland"/>
              <sld:ColorMapEntry quantity="2" color="#ffaa00" label="2 layers depict cropland"/>
              <sld:ColorMapEntry quantity="3" color="#ffff00" label="3 layers depict cropland"/>
              <sld:ColorMapEntry quantity="4" color="#85faff" label="4 layers depict cropland"/>
              <sld:ColorMapEntry quantity="5" color="#00c5ff" label="5 layers depict cropland"/>
              <sld:ColorMapEntry quantity="6" color="#005ce6" label="6 layers depict cropland"/>
            </sld:ColorMap>
          </sld:RasterSymbolizer>
        </sld:Rule>
      </sld:FeatureTypeStyle>
    </sld:UserStyle>
  </UserLayer>
</StyledLayerDescriptor>
