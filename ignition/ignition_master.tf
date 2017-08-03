data "template_file" "master-get-ssl" {
  template = "${file("resources/get-ssl.service")}"

  vars {
    ssl_tar_url = "s3://${var.ssl_s3_bucket}/certs/k8s-worker.tar"
  }
}

data "ignition_systemd_unit" "master-get-ssl" {
  name    = "get-ssl.service"
  content = "${data.template_file.master-get-ssl.rendered}"
}

data "template_file" "master-kubelet" {
  template = "${file("resources/master-kubelet.service")}"

  vars {
    kubelet_image_url = "${var.hyperkube_image_url}"
    kubelet_image_tag = "${var.hyperkube_image_tag}"
    cloud_provider    = "${var.cloud_provider}"
    cluster_dns       = "${var.cluster_dns}"
  }
}

data "ignition_systemd_unit" "master-kubelet" {
  name    = "kubelet.service"
  content = "${data.template_file.master-kubelet.rendered}"
}

data "template_file" "master-kube-proxy" {
  template = "${file("resources/master-kube-proxy.yaml")}"

  vars {
    hyperkube_image_url = "${var.hyperkube_image_url}"
    hyperkube_image_tag = "${var.hyperkube_image_tag}"
  }
}

data "ignition_file" "master-kube-proxy" {
  mode       = 644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-proxy.yaml"

  content {
    content = "${data.template_file.master-kube-proxy.rendered}"
  }
}

data "ignition_file" "master-kubeconfig" {
  mode       = 644
  filesystem = "root"
  path       = "/var/lib/kubelet/kubeconfig"

  content {
    content = "${file("resources/master-kubeconfig")}"
  }
}

data "template_file" "kube-apiserver" {
  template = "${file("resources/kube-apiserver.yaml")}"

  vars {
    hyperkube_image_url   = "${var.hyperkube_image_url}"
    hyperkube_image_tag   = "${var.hyperkube_image_tag}"
    etcd_endpoints        = "${join(",", formatlist("https://%s:2379", var.etcd_endpoints))}"
    service_network       = "${var.service_network}"
    master_instance_count = "${var.master_instance_count}"
    cloud_provider        = "${var.cloud_provider}"
    oidc_issuer_url       = "${var.oidc_issuer_url}"
    oidc_client_id        = "${var.oidc_client_id}"
  }
}

data "ignition_file" "kube-apiserver" {
  mode       = 644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-apiserver.yaml"

  content {
    content = "${data.template_file.kube-apiserver.rendered}"
  }
}

data "template_file" "kube-controller-manager" {
  template = "${file("resources/kube-controller-manager.yaml")}"

  vars {
    hyperkube_image_url = "${var.hyperkube_image_url}"
    hyperkube_image_tag = "${var.hyperkube_image_tag}"
    cloud_provider      = "${var.cloud_provider}"
    pod_network         = "${var.pod_network}"
  }
}

data "ignition_file" "kube-controller-manager" {
  mode       = 644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-controller-manager.yaml"

  content {
    content = "${data.template_file.kube-controller-manager.rendered}"
  }
}

data "template_file" "kube-scheduler" {
  template = "${file("resources/kube-scheduler.yaml")}"

  vars {
    hyperkube_image_url = "${var.hyperkube_image_url}"
    hyperkube_image_tag = "${var.hyperkube_image_tag}"
  }
}

data "ignition_file" "kube-scheduler" {
  mode       = 644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-scheduler.yaml"

  content {
    content = "${data.template_file.kube-scheduler.rendered}"
  }
}

data "ignition_file" "master-prom-machine-role" {
  mode       = 644
  filesystem = "root"
  path       = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"master\"} 1"
  }
}

data "ignition_config" "master" {
  files = [
    "${data.ignition_file.s3-iam-get.id}",
    "${data.ignition_file.master-prom-machine-role.id}",
    "${data.ignition_file.master-kubeconfig.id}",
    "${data.ignition_file.master-kube-proxy.id}",
    "${data.ignition_file.kube-apiserver.id}",
    "${data.ignition_file.kube-scheduler.id}",
    "${data.ignition_file.kube-controller-manager.id}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.update-engine.id}",
    "${data.ignition_systemd_unit.locksmithd.id}",
    "${data.ignition_systemd_unit.master-get-ssl.id}",
    "${data.ignition_systemd_unit.master-kubelet.id}",
  ]
}
