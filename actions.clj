#:vimpire
{:doc-lookup
 (vimpire.actions/doc-lookup #unrepl/param :nspace #unrepl/param :sym)

 :find-doc
 (vimpire.actions/find-doc #unrepl/param :query)

 :javadoc-path
 (vimpire.actions/javadoc-path #unrepl/param :nspace #unrepl/param :sym)

 :source-lookup
 (vimpire.actions/source-lookup #unrepl/param :nspace #unrepl/param :sym)

 :source-location
 (vimpire.actions/source-location #unrepl/param :nspace #unrepl/param :sym)

 :meta-lookup
 (vimpire.actions/meta-lookup #unrepl/param :nspace #unrepl/param :sym)

 :dynamic-highlighting
 (vimpire.actions/dynamic-highlighting #unrepl/param :nspace)

 :namespace-of-file
 (vimpire.actions/namespace-of-file #unrepl/param :content)

 :namespace-info
 (vimpire.actions/namespace-info #unrepl/param :content)

 :macro-expand
 (vimpire.actions/macro-expand #unrepl/param :nspace
                               #unrepl/param :form
                               #unrepl/param :one?)

 :check-syntax
 (vimpire.actions/check-syntax #unrepl/param :nspace #unrepl/param :content)

 :run-tests
 (vimpire.actions/run-tests #unrepl/param :nspace #unrepl/param :all?)}
