#:vimpire.nails
{:doc-lookup
 (vimpire.nails/doc-lookup #unrepl/param :nspace #unrepl/param :sym)

 :find-doc
 (vimpire.nails/find-doc #unrepl/param :query)

 :javadoc-path
 (vimpire.nails/javadoc-path #unrepl/param :nspace #unrepl/param :sym)

 :source-lookup
 (vimpire.nails/source-lookup #unrepl/param :nspace #unrepl/param :sym)

 :source-location
 (vimpire.nails/source-location #unrepl/param :nspace #unrepl/param :sym)

 :meta-lookup
 (vimpire.nails/meta-lookup #unrepl/param :nspace #unrepl/param :sym)

 :dynamic-highlighting
 (vimpire.nails/dynamic-highlighting #unrepl/param :nspace)

 :namespace-of-file
 (vimpire.nails/namespace-of-file #unrepl/param :content)

 :namespace-info
 (vimpire.nails/namespace-info #unrepl/param :content)

 :macro-expand
 (vimpire.nails/macro-expand #unrepl/param :nspace #unrepl/param :form #unrepl/param :one?)

 :check-syntax
 (vimpire.nails/check-syntax #unrepl/param :nspace #unrepl/param :content)

 :run-tests
 (vimpire.nails/run-tests #unrepl/param :nspace #unrepl/param :all?)

 :pprint-exception
 (vimpire.pprint/pprint-exception #unrepl/param :ex)}
