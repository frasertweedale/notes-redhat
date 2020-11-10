<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="/rfc">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="sortRefs">true</xsl:attribute>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="/rfc/back/*[1]" xmlns:xi="http://www.w3.org/2001/XInclude">
        <xsl:element name="xi:include">
            <xsl:attribute name="href">displayreference.xml</xsl:attribute>
            <xsl:attribute name="xpointer">xpointer(//displayreference)</xsl:attribute>
        </xsl:element>
        <xsl:text>&#xa;</xsl:text>
        <xsl:copy-of select="."/>
    </xsl:template>
</xsl:stylesheet>
