#kubectl --kubeconfig /home/vt_admin/.kube/config.admin create ns fluentbit
kubectl --kubeconfig /home/vt_admin/.kube/config.admin apply -f ./service-account.yaml
kubectl --kubeconfig /home/vt_admin/.kube/config.admin create cm fluent-bit-ocs-config -n fluentbit --from-file=config/fluent-bit.conf --from-file=config/input.conf --from-file=config/output.conf --from-file=config/parsers.conf --from-file=config/multiline.conf --from-file=config/filter.conf --dry-run=client -o yaml > cm.yaml
kubectl --kubeconfig /home/vt_admin/.kube/config.admin apply -f ./cm.yaml
kubectl --kubeconfig /home/vt_admin/.kube/config.admin label --overwrite cm fluent-bit-ocs-config -n fluentbit k8s-app=fluent-bit-ocs
kubectl --kubeconfig /home/vt_admin/.kube/config.admin apply -f ./fluent-bit.yaml
kubectl --kubeconfig /home/vt_admin/.kube/config.admin apply -f ./service-nodeport.yaml
