venom:
	clj -FIXME poison_fang.clj -e '(main)'
	find venom -type f -name \*.clj -exec base64 '{}' '{}.b64' \;
	mkdir venom/unrepl
	lein unrepl-make-blob venom/unrepl/blob.clj actions_poisoned.clj

.PHONY: venom
