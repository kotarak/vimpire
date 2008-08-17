all:
	@echo "Available Targets:"
	@echo " - bump-version"
	@echo " - bump-revision"
	@echo " - bump-level"
	@echo " - tarball"

.PHONY: bump-version bump-revision bump-level tarball

bump-version:
	shtool version -l txt -n vimclojure -i v version.txt

bump-revision:
	shtool version -l txt -n vimclojure -i i version.txt

bump-level:
	shtool version -l txt -n vimclojure -i l version.txt

V	!= shtool version -l txt -d short version.txt
TARBALL := vimclojure-${V}.tar.gz

tarball:
	@if [ -e ${TARBALL} ]; then \
		echo "rm ${TARBALL}"; \
		rm ${TARBALL}; \
	fi
	shtool tarball -e '\.hg,\.hgignore,\.DS_Store,Makefile' -c 'gzip -9' \
		-o ${TARBALL} .
