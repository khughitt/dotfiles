<!-- conditionsInclude.xslt

This XSLT is used to translate an XML response from the www.google.com/ig/ XML API.

This style sheet parses raw WEATHER CONDITION data into something useful, e.g.

	++ Works in conjunction with the weather.xslt & conditions.xslt files
	++ Determines which current weather conditions icons to use in Conky
	++ Last Update: 26-NOV-2011

NOTE:   ++ You may need to modify this style sheet, as the Google Weather API format changes.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
    <xsl:output method="text" disable-output-escaping="yes" encoding="utf-8"/>
    <xsl:template name="get-condition-symbol">
        <xsl:param name="condition"/>
        <xsl:choose>
            <xsl:when test="contains($condition,'Clear')">
               <xsl:text>a</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Dust')">
               <xsl:text>7</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Flurries')">
               <xsl:text>8</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Fog')">
               <xsl:text>9</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Freezing Drizzle')">
               <xsl:text>y</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Hail')">
               <xsl:text>w</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Haze')">
               <xsl:text>0</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Icy')">
               <xsl:text>r</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Mist')">
               <xsl:text>9</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Overcast')">
               <xsl:text>e</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Sleet')">
               <xsl:text>y</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Smoke')">
               <xsl:text>7</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Windy')">
               <xsl:text>6</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Mostly Sunny')">
               <xsl:text>b</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Partly Sunny')">
               <xsl:text>b</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Sunny')">
               <xsl:text>a</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Mostly Cloudy')">
               <xsl:text>d</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Partly Cloudy')">
               <xsl:text>c</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Cloudy')">
               <xsl:text>c</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Chance of Snow')">
               <xsl:text>o</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Light Snow')">
               <xsl:text>w</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Light snow')">
               <xsl:text>w</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Rain and Snow')">
               <xsl:text>x</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Snow Showers')">
               <xsl:text>v</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Snow')">
               <xsl:text>q</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Light Rain')">
               <xsl:text>h</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Light rain')">
               <xsl:text>h</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Chance of Rain')">
               <xsl:text>g</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Rain')">
               <xsl:text>v</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Scattered Showers')">
               <xsl:text>s</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Showers')">
               <xsl:text>s</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Chance of Storm')">
               <xsl:text>s</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Chance of TStorm')">
               <xsl:text>k</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Scattered Thunderstorms')">
               <xsl:text>k</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Thunderstorm')">
               <xsl:text>n</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'Storm')">
               <xsl:text>v</xsl:text>
            </xsl:when>
            <xsl:when test="contains($condition,'')">
               <xsl:text>-</xsl:text>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>Something else</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
