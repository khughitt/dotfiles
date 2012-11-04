<!-- currentConditionBig.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet shows the CURRENT WEATHER TEMPERATURE (big format) in the Conky Weather Section, e.g.

        ++ Determines the current weather condition, for use in the Conky Weather header

NOTE:   ++ You probably won't need to modify anything in this style sheet.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" > 
	<xsl:output method="text" disable-output-escaping="yes"/>
    <xsl:template match="xml_api_reply">
		<xsl:apply-templates select="weather"/>
	</xsl:template>
 	
    <xsl:template match="weather">
        <xsl:value-of select="current_conditions/condition/@data" /><!-- Fetches current conditions from Google API -->
    </xsl:template>
</xsl:stylesheet>
