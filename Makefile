ifeq (,$(wildcard marker))
MARKER:=    funky
else
MARKER:=    $(shell cat marker)
endif

BACKEND:=   $(shell find server -type f -name \*.clj -print)
VENOM:=     $(subst server/,venom/$(MARKER)/,$(BACKEND))
VENOM_B64:= $(patsubst %,%.b64,$(VENOM))

venom: venom/unrepl/blob.clj $(VENOM_B64)

marker: $(BACKEND)
	clj -i fang.clj -e '(marker)'

%.clj.b64: %.clj
	base64 '$<' >'$@'

actions_poisoned.clj $(VENOM): actions.clj fang.clj $(BACKEND)
	clj -i fang.clj -e '(main)'

venom/unrepl/blob.clj: actions_poisoned.clj
	clj -m unrepl.make-blob venom/unrepl/blob.clj actions_poisoned.clj

clean:
	rm -r venom
	rm actions_poisoned.clj
	rm marker

.PHONY: venom clean
