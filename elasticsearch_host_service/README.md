# Elasticsearch + Kibana Host Service Installer

Installer nay trien khai Elasticsearch va Kibana dang host service tren EC2,
doc lap voi bo cai Kubernetes trong `k8s_auto/`.

Mac dinh:

- 3 node Elasticsearch.
- Moi node co roles `master,data`.
- Khong cai client node, exporter, hay thanh phan phu khac.
- Kibana chay tren host trong group `kibana`.
- Cau hinh phien ban, cluster name, port, heap, data/log path duoc lay theo tinh
  than cau hinh Elasticsearch hien co trong `k8s_auto`.

## Cau truc

- `inventory.ini`: khai bao 3 EC2 Elasticsearch node va host Kibana.
- `group_vars/elk.yml`: bien cai dat.
- `playbook.yml`: entry point.
- `roles/elasticsearch_host_service/`: cai Elasticsearch systemd service.
- `roles/kibana_host_service/`: cai Kibana systemd service.

## Chay cai dat

Cap nhat `inventory.ini` bang private IP/SSH user cua EC2, sau do chay:

```bash
cd elasticsearch_host_service
ansible-playbook -i inventory.ini playbook.yml --syntax-check
ansible-playbook -i inventory.ini playbook.yml
```

## Kiem tra

Tren node Elasticsearch dau tien:

```bash
curl -k -u elastic:'123456a@' https://127.0.0.1:9200/_cluster/health?pretty
systemctl status elasticsearch
```

Tren host Kibana:

```bash
systemctl status kibana
curl -I http://127.0.0.1:5601/kibana
```

## Luu y EC2

Mo security group giua 3 node Elasticsearch cho TCP `9200` va `9300`.
Mo TCP `5601` den nguon quan tri can truy cap Kibana. Nen dung private IP cho
`elk_ip` de traffic cluster di trong VPC.
