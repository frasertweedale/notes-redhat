<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:str="http://exslt.org/strings"
>
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <!-- Add sortRefs="true" attribute to <rfc> -->
    <xsl:template match="/rfc">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="sortRefs">true</xsl:attribute>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <!-- Add displayreference nodes as first children of <back> -->
    <xsl:template match="/rfc/back/*[1]" xmlns:xi="http://www.w3.org/2001/XInclude">
        <xsl:element name="xi:include">
            <xsl:attribute name="href">displayreference.xml</xsl:attribute>
            <xsl:attribute name="xpointer">xpointer(//displayreference)</xsl:attribute>
        </xsl:element>
        <xsl:text>&#xa;</xsl:text>
        <xsl:copy-of select="."/>
    </xsl:template>

    <!-- Remove empty <date/> elems from <reference> elems -->
    <xsl:template match="//reference/front/date[not(@year)][not(@month)][not(@day)]">
    </xsl:template>

    <!-- Fix I-D targets in <xref> nodes -->
    <xsl:template match="//xref/@target[starts-with(string(), 'I-D')]">
        <xsl:attribute name="target">
            <xsl:value-of select="str:replace(str:replace(string(), 'draft-', ''), concat('-', str:split(string(), '-')[last()]), '')" />
        </xsl:attribute>
    </xsl:template>
</xsl:stylesheet>
