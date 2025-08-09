.PHONY: png svg

svg: build.svg
png: build.png

%.png: %.dot
	dot $< -Tpng > $@

%.svg: %.dot
	dot $< -Tsvg > $@

