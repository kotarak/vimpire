PROJECT := gorilla

SRCDIR  := src
DISTDIR := classes

CLJSRC  != find ${SRCDIR} -type f -name \*.clj
DIRS    != cd ${SRCDIR} && find * -type d

VERSION != shtool version -d short version.txt
JAR     := ${PROJECT}.jar
TGZ     := ${PROJECT}-${VERSION}.tar.gz

all: jar

release: jar tarball

jar: ${JAR}

tarball: ${TGZ}

test: jar
	env CLASSPATH=${JAR}:$${CLASSPATH} prove t

clean:
	rm -rf ${DISTDIR} ${JAR} ${TGZ}

compile: ${CLJSRC} ${DISTDIR}
	env CLASSPATH=${SRCDIR}:${DISTDIR}:$${CLASSPATH}\
		java clojure.lang.Script compile.clj

bump-version:
	shtool version -l txt -n ${PROJECT} -i v version.txt

bump-revision:
	shtool version -l txt -n ${PROJECT} -i r version.txt

bump-level:
	shtool version -l txt -n ${PROJECT} -i l version.txt

${JAR}: compile
	cp README.txt ${DISTDIR}
	cp LICENSE ${DISTDIR}
	jar cf ${JAR} -C ${DISTDIR} .

${TGZ}:
	shtool tarball -c "gzip -9" -o ${TGZ} \
		-e '\.DS_Store,${DISTDIR},\.hg,\.tar\.gz' .

${DISTDIR}:
	shtool mkdir -p ${DISTDIR}
	@for dir in ${DIRS}; do \
		echo shtool mkdir -p ${DISTDIR}/$${dir}; \
		shtool mkdir -p ${DISTDIR}/$${dir}; \
	done

.PHONY: all release jar tarball test clean compile
