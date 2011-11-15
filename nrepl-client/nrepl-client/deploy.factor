USING: tools.deploy.config ;
H{
    { deploy-name "nrepl-client" }
    { deploy-ui? f }
    { deploy-c-types? f }
    { deploy-console? t }
    { deploy-unicode? t }
    { "stop-after-last-window?" t }
    { deploy-io 3 }
    { deploy-reflection 3 }
    { deploy-word-props? f }
    { deploy-math? t }
    { deploy-threads? t }
    { deploy-word-defs? f }
}
