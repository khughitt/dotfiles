<!-- conditionsTempBig.Imperial.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet shows the CURRENT TEMPERATURE (big format) in the Conky Weather Section, e.g.

	++ Fetches & shows the current temperature for use in the Conky header

NOTE:   ++ Enable the following line, in the weather.sh file, for Imperial Stats:

        # cURL the Google Weather API (Imperial - Fahrenheit)
        CURLURL="http://www.google.com/ig/api?weather=${LOCID}&hl=en"
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" > 
	<xsl:output method="text" disable-output-escaping="yes"/>
    <xsl:template match="xml_api_reply">
		<xsl:apply-templates select="weather"/>
	</xsl:template>
 	
    <xsl:template match="weather">
        <xsl:value-of select="tmp" /><xsl:value-of select="current_conditions/temp_f/@data" /><!-- /temp_f/ (for Fahrenheit) -->
        <xsl:text>ºF</xsl:text><!-- F (for Fahrenheit) -->
    </xsl:template>
</xsl:stylesheet>
