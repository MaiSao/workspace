#!/bin/bash

# Định nghĩa biến
USER_NAME="vt-admin"
CLUSTER_ROLE="vt-admin-role"
NAMESPACE="default"
KUBECONFIG_FILE="kubeconfig-$USER_NAME.yaml"
SECRET_NAME="${USER_NAME}-token"

# Bước 1: Tạo Service Account
echo "ð��¹ Tạo Service Account: $USER_NAME..."
kubectl create serviceaccount $USER_NAME --namespace $NAMESPACE

# Bước 2: Tạo Secret cho Service Account (dành cho Kubernetes v1.24+)
echo "ð��¹ Tạo Secret để lấy Token cho Service Account..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: "$USER_NAME"
type: kubernetes.io/service-account-token
EOF

# Đợi Secret được tạo
echo "⏳ Chờ Secret sẵn sàng..."
sleep 2

# Bước 3: Tạo ClusterRole chỉ có quyền đọc
echo "ð��¹ Tạo ClusterRole: $CLUSTER_ROLE..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: $CLUSTER_ROLE
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
EOF

# Bước 4: Gán Role cho Service Account
echo "ð��¹ Gán ClusterRole cho Service Account..."
kubectl create clusterrolebinding ${USER_NAME}-binding \
  --clusterrole=$CLUSTER_ROLE \
  --serviceaccount=$NAMESPACE:$USER_NAME

# Bước 5: Lấy Token của Service Account
echo "ð��¹ Lấy Token của Service Account..."
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)

# Bước 6: Lấy thông tin cụm Kubernetes
echo "ð��¹ Lấy thông tin cụm Kubernetes..."
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Bước 7: Lấy CA Certificate của cụm
echo "ð��¹ Lấy CA Certificate..."
CA_CRT=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 --decode | base64 | tr -d '\n')

# Bước 8: Tạo file kubeconfig
echo "ð��¹ Tạo file kubeconfig: $KUBECONFIG_FILE..."
cat <<EOF > $KUBECONFIG_FILE
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER_NAME
  cluster:
    server: $SERVER
    certificate-authority-data: $CA_CRT
contexts:
- name: readonly-context
  context:
    cluster: $CLUSTER_NAME
    user: $USER_NAME
current-context: readonly-context
users:
- name: $USER_NAME
  user:
    token: $TOKEN
EOF

# Hoàn thành
echo "✅ Hoàn thành! Kubeconfig đã được tạo tại: $KUBECONFIG_FILE"
echo "Sử dụng lệnh sau để truy vấn Kubernetes với user chỉ có quyền đọc:"
