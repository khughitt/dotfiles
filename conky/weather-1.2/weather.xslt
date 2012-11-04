<!--  weather.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet shows the CURRENT WEATHER CONDITIONS in the Conky Weather Section, e.g.

        ++ Location
        ++ Humidity
        ++ Wind

NOTE:   ++ Change the wording and spacing, as necessary.  Specify CITY or POSTAL CODE (as noted below)!!!
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" > 
	<xsl:output method="text" disable-output-escaping="yes"/>
    <xsl:template match="xml_api_reply">
		<xsl:apply-templates select="weather"/>
	</xsl:template>
 	
    <xsl:template match="weather">
        <xsl:variable name="new-line"><xsl:text>&#10;</xsl:text></xsl:variable><!-- Sets line feed variable -->
        <xsl:text>       Location: </xsl:text><!-- 7 spaces before "Location:" 1 space after. Add/subtract spaces for proper alignment) -->
            <xsl:value-of select="forecast_information/city/@data" /><!-- /city/ (Google API chooses the city's name) /postal_code/ (city's name is determined by .conkyrc script) --> 
            <xsl:value-of select="$new-line" /><!-- Line feed -->
        <xsl:text>       </xsl:text><xsl:value-of select="current_conditions/humidity/@data" /><!-- 7 spaces before "Humidity:" (wording is determined by Google API) Add/subtract spaces for proper alignment -->
            <xsl:value-of select="$new-line" /><!-- Line feed -->
        <xsl:text>       </xsl:text><xsl:value-of select="current_conditions/wind_condition/@data" /><!-- 7 spaces before "Wind:" (wording is determined by Google API) Add/subtract spaces for proper alignment -->
    </xsl:template>
</xsl:stylesheet>
