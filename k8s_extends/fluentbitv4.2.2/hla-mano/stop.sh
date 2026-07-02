kubectl --kubeconfig /home/vt_admin/.kube/config.admin delete -f ./service-account.yaml
kubectl --kubeconfig /home/vt_admin/.kube/config.admin delete -f ./cm.yaml
kubectl --kubeconfig /home/vt_admin/.kube/config.admin delete -f ./fluent-bit.yaml
kubectl --kubeconfig /home/vt_admin/.kube/config.admin delete -f ./service-nodeport.yaml
#kubectl --kubeconfig /home/vt_admin/.kube/config.admin delete ns fluentbit
