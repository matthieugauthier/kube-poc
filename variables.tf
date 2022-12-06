locals {
    access_key          = ""
    secret_key          = ""

    keys_public         = "${file("/Users//.ssh/id_rsa.pub")}"
    keys_private        = "${file("/Users//.ssh/id_rsa")}"

    ami                 = "ami-"
    instance_type       = "t3.medium"

    eip                 = "eipalloc-"

    rancher_install_secret_tls  = ""
    rancher_install_hostname    = ""
    rancher_install_password    = ""

    harbor_install_hostname     = ""

    tls_crt                     = ""
    tls_key                     = ""

    harbor_dns                  = ""
    vault_dns                   = ""
    rancher_dns                 = ""
    argocd_dns                  = ""

    count_tools_nodes   = 0 # Default=0, Min=0, Max=x, Note: Wait CP Init Before change it
}