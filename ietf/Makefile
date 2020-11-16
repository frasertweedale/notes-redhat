DOCS = $(basename $(shell ls *.md))

all: $(addprefix output/,$(addsuffix /.done,$(DOCS)))

output/%/.done: %.md %-displayref.xml tweak.xsl
	mkdir -p $(dir $@)
	mmark $< | xsltproc tweak.xsl - > $(dir $@)/$(addsuffix .xml,$(basename $<))
	cp $(word 2,$^) $(dir $@)/displayreference.xml
	( \
		cd $(dir $@) ; \
		NAME=$$(xmllint $(addsuffix .xml,$(basename $<)) --xpath "string(/rfc/@docName)") ; \
		echo $$NAME ; \
		xml2rfc $(addsuffix .xml,$(basename $<)) --out $$NAME.xml --expand ; \
		rm $(addsuffix .xml,$(basename $<)) ; \
		xml2rfc $$NAME.xml --out $$NAME.txt --text ; \
		xml2rfc $$NAME.xml --out $$NAME.html --html ; \
	)
	touch $@
