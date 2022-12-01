locals {
    access_key          = ""
    secret_key          = ""

    keys_public         = "${file("/Users//.ssh/id_rsa.pub")}"
    keys_private        = "${file("/Users//.ssh/id_rsa")}"

    ami                 = "ami-001c2751d5252c623"
    instance_type       = "t3.medium"

    rancher_install_hostname    = ""
    rancher_install_password    = ""


    count_tools_nodes   = 0 # Default=0, Min=0, Max=x, Note: Wait CP Init Before change it
}