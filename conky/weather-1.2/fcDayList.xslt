<!-- fcDayList.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet shows the FORECAST DAYS-OF-THE-WEEK in the Conky Weather Section.

Adjust the number of empty spaces (as noted below) to align the horizontal spacing of the
forecast days-of-the-week on your desktop.  This works in conjunction with the font size
that you chose to use in your .conkyrc file, and will require some patience to setup.  :)

This is a base adjustment.  Once you get the horizontal alignment into the ballpark, the rest
of the spacing & alignment will handled, as usual, by making adjustments to the Weather Section
in your .conkyrc file.

NOTE:   ++ Use MONO FONTS ONLY for the FORECAST DAYS-OF-THE-WEEK, in your .conkyrc file!
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
    <xsl:output method="text" disable-output-escaping="yes" encoding="utf-8"/>
    <xsl:template match="xml_api_reply">
        <xsl:apply-templates select="weather"/>
    </xsl:template>

    <xsl:template match="weather">
        <xsl:for-each select="forecast_conditions/day_of_week"><!-- Fetches all available Forecasts -->
            <xsl:choose>
                <xsl:when test="position() = 1"><!-- Don't display Today's Forecast. Will be handled elsewhere -->
                    <xsl:text></xsl:text>
                </xsl:when>
                <xsl:when test="position() = 2"><!-- Choose Forecasts for the next three days only -->
                    <xsl:value-of select="@data"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>        </xsl:text><!-- 8 spaces. Add/subtract spaces for proper Forecast Day alignment -->
                    <xsl:value-of select="@data"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
