<!-- conditionsTempBig.Metric.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet shows the CURRENT TEMPERATURE (big format) in the Conky Weather Section. e.g.

        ++ Fetches & shows the current temperature for use in the Conky header

NOTE:   ++ Enable the following line, in the weather.sh file, for Metric Stats:	

        # cURL the Google Weather API (Metric - Celsius)
        CURLURL="http://www.google.com/ig/api?weather=${LOCID}&hl=en-gb"

        ++ Change the lettering and spacing, as necessary (as noted below).
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" > 
	<xsl:output method="text" disable-output-escaping="yes"/>
    <xsl:template match="xml_api_reply">
		<xsl:apply-templates select="weather"/>
	</xsl:template>
 	
    <xsl:template match="weather">
        <xsl:variable name="new-line"><xsl:text>&#10;</xsl:text></xsl:variable><!-- Sets line feed variable -->
        <xsl:value-of select="$new-line" /><!-- Line feed -->
            <xsl:text>     </xsl:text><!-- 5 spaces. Add/subtract spaces for proper Current Temp alignment -->
        <xsl:value-of select="tmp" /><xsl:value-of select="current_conditions/temp_c/@data" /><!-- /temp_c/ (for Celsius) -->
            <xsl:text>ºC</xsl:text><!-- C (for Celsius) -->
    </xsl:template>
</xsl:stylesheet>
