DOCS = $(basename $(shell ls *.md))

all: $(addprefix output/,$(DOCS))

%.xml: %.md tweak.xsl
	mmark $< | xsltproc tweak.xsl - > $@

output/%: %.xml
	$(eval NAME=$(shell xmllint $< --xpath "string(/rfc/@docName)"))
	mkdir -p $@
	cp $< $@/$(NAME).xml
	xml2rfc $< --out $@/$(NAME).txt --text
	xml2rfc $< --out $@/$(NAME).html --html
	touch $@
