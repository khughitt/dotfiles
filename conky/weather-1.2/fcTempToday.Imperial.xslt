<!--  fcTempToday.Imperial.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet shows the FORECAST TEMP FOR TODAY in the Conky Weather Section, e.g.

        ++ Fetches & shows the Min/Max Temps for the current day in the Conky Header

NOTE:   ++ Enable the following line, in the weather.sh file, for Imperial Stats:

        # cURL the Google Weather API (Imperial - Fahrenheit)
        CURLURL="http://www.google.com/ig/api?weather=${LOCID}&hl=en"

        ++ Change the lettering and spacing, as necessary (as noted below).
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
	<xsl:output method="text" disable-output-escaping="yes"/>
    <xsl:template match="xml_api_reply">
		<xsl:apply-templates select="weather"/>
	</xsl:template>

    <xsl:template match="weather">
        <xsl:variable name="new-line"><xsl:text>&#10;</xsl:text></xsl:variable><!-- Sets line feed variable -->
        <xsl:text>                                                                    </xsl:text><!-- 68 spaces. Add/subtract spaces for proper Today's High Temp alignment -->
            <xsl:value-of select="forecast_conditions/high/@data" /><!-- Fetches today's high temp -->
            <xsl:text>ºF</xsl:text><!-- F (for Fahrenheit) -->
        <xsl:value-of select="$new-line" /><!-- Line feed -->
        <xsl:text>                                                                    </xsl:text><!-- 68 spaces. Add/subtract spaces for proper Today's Low Temp alignment -->
            <xsl:value-of select="forecast_conditions/low/@data" /><!-- Fetches today's low temp -->
            <xsl:text>ºF</xsl:text><!-- F (for Fahrenheit) -->
    </xsl:template>
</xsl:stylesheet>
