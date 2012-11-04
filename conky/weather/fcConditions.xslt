<!-- fcConditions.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet shows all FORECAST WEATHER CONDITION ICONS in the Conky Weather Section, e.g.
the 3 weather condition icons that are listed in the middle of the 3-day forecast.

The first line (forecast day list) in the 3-day forecast is handled by: fcDayList.xslt

The third line (temperatures) is handled by: FcTemp.Imperial.xslt and/or FcTemp.Metric.xslt

Adjust the number of empty spaces (as noted below) to align the horizontal spacing of the
forecast weather condition icons on your desktop.  This works in conjunction with the font
size that you chose to use in your .conkyrc file, and will require some patience to setup.  :)

This is a base adjustment.  Once you get the horizontal alignment into the ballpark, the rest
of the spacing & alignment will handled, as usual, by making adjustments to the Weather Section
in your .conkyrc file.

NOTE:   ++ Use WEATHER DINGBAT FONTS for the FORECAST WEATHER CONDITION ICONS, in your .conkyrc file!
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
    <xsl:include href="conditionsInclude.xslt"/>
    <xsl:output method="text" disable-output-escaping="yes" encoding="utf-8"/>
    <xsl:template match="xml_api_reply">
        <xsl:apply-templates select="weather"/>
    </xsl:template>

    <xsl:template match="weather">
        <xsl:for-each select="forecast_conditions[position() >= 2]"><!-- Fetches Forecast Conditions for next 3 days -->
           <xsl:call-template name="get-condition-symbol"><!-- Fetches "conditionsInclude.xslt" -->
                <xsl:with-param name="condition"><!-- Loads your "condition" icon parameters -->
                    <xsl:value-of select="condition/@data"/><!-- Fetches forecast conditions from Google API -->
                </xsl:with-param>
            </xsl:call-template>
            <xsl:if test="position() != 3"><!-- Matches your weather icons with Google API data -->
                <xsl:text>  </xsl:text><!-- 2 spaces. Add/subtract spaces for proper Forecast Weather Condition Icon spacing -->
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
