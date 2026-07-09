# Bộ cài Harbor bằng Ansible

Thư mục này cài Harbor trên nhiều máy bằng Ansible. Bộ cài hỗ trợ:

- Cài Harbor độc lập trên từng node.
- Tạo CA và certificate dùng chung.
- Cấu hình Docker tin cậy certificate của các registry.
- Tùy chọn HA bằng HAProxy, Keepalived và VIP.
- Tạo replication policy giữa các Harbor node khi bật HA.
- Tạo các project public và nạp bộ container image ban đầu.

## Cấu trúc

```text
inventory.ini                  Danh sách node Harbor
group_vars/all.yml             Cấu hình dùng chung
playbook.yml                   Playbook duy nhất của bộ cài
roles/certs                    Tạo certificate trên node primary
roles/harbor                   Cài đặt và cấu hình Harbor
roles/haproxy                  Cấu hình cân bằng tải
roles/keepalived               Cấu hình VIP
roles/replications             Tạo project và replication policy
roles/images                   Nạp, đổi tag và đẩy image lên Harbor
```

`playbook.yml` chỉ có một play chạy trên nhóm `HARBOR`. Role `certs` được giới
hạn bằng `when` và chỉ chạy trên node khai báo bởi `primary_harbor_node`.

## Yêu cầu

Máy chạy Ansible cần:

- Ansible và SSH client.
- Kết nối SSH tới tất cả node bằng tài khoản có quyền `become`.

Các node Harbor cần:

- Hệ điều hành sử dụng `yum`.
- Repository cung cấp `docker-ce`, `docker-ce-cli`, HAProxy và Keepalived.
- Đủ dung lượng cho `docker_data_root` và `harbor_data_volume`.
- Các port cấu hình trong `group_vars/all.yml` được mở giữa các node.

## Khôi phục các file dung lượng lớn

Repository này không chứa các file cài đặt và image dung lượng lớn. Trước khi
chạy playbook, đặt đúng file vào các đường dẫn sau:

```text
roles/harbor/files/docker-compose
roles/harbor/files/harbor-offline-installer-v2.14.1.tgz
roles/images/files/images.tar.gz
```

File `docker-compose` phải có thể thực thi. Bộ Harbor offline phải đúng tên
`harbor-offline-installer-v2.14.1.tgz`, vì role đang tham chiếu trực tiếp tên
này.

## Cấu hình inventory

Mỗi node có một alias ổn định và địa chỉ kết nối nằm trong `ansible_host`:

```ini
[HARBOR]
harbor01 ansible_host=172.20.3.117 ansible_user=root ansible_password='change-me'
harbor02 ansible_host=172.20.3.126 ansible_user=root ansible_password='change-me'
harbor03 ansible_host=172.20.3.57  ansible_user=root ansible_password='change-me'
```

Không khai báo lại các IP thành những host riêng trong cùng group, nếu không
Ansible sẽ coi ba alias và ba IP là sáu host khác nhau.

Nên dùng SSH key hoặc Ansible Vault thay vì lưu mật khẩu thật trong repository.

## Cấu hình chung

Chỉnh `group_vars/all.yml` trước khi cài:

- `primary_harbor_node`: alias node tạo certificate, ví dụ `harbor01`.
- `harbor_domain`: tên miền truy cập Harbor.
- `http_port`, `https_port`: port trực tiếp trên từng node.
- `harbor_data_volume`: nơi lưu dữ liệu Harbor.
- `docker_data_root`: nơi lưu dữ liệu Docker.
- `harbor_user`, `harbor_password`, `database_password`: thông tin xác thực.
- `public_projects`: danh sách project public cần tạo.

Để bật HA:

```yaml
setup_ha: true
harbor_haip: "172.20.3.155"
https_vip_port: 8018
keepalived_interface: "eth0"
```

VIP phải chưa được sử dụng, thuộc cùng subnet với các node và interface phải
tồn tại trên tất cả node.

## Kiểm tra trước khi chạy

Chạy từ thư mục `harbor_auto_without_images`:

```bash
ansible-inventory -i inventory.ini --graph
ansible -i inventory.ini HARBOR -m ping
ansible-playbook -i inventory.ini playbook.yml --syntax-check
ansible-playbook -i inventory.ini playbook.yml --list-hosts
ansible-playbook -i inventory.ini playbook.yml --list-tasks
```

Kết quả inventory đúng phải chỉ có `harbor01`, `harbor02` và `harbor03`.

## Cài đặt

Sau khi đã kiểm tra cấu hình và khôi phục đủ các file dung lượng lớn:

```bash
ansible-playbook -i inventory.ini playbook.yml
```

Khi `setup_ha: false`, truy cập từng node qua:

```text
https://<IP-node>:<https_port>
```

Khi `setup_ha: true`, truy cập qua:

```text
https://<harbor_domain>:<https_vip_port>
```

DNS của `harbor_domain` phải trỏ tới `harbor_haip`.

## Cảnh báo khi chạy lại

Role `harbor` hiện không phải luồng nâng cấp tại chỗ. Mỗi lần chạy đầy đủ,
playbook sẽ:

1. Dừng Docker Compose hiện tại.
2. Xóa `harbor_install_dir`.
3. Xóa toàn bộ `harbor_data_volume`.
4. Cài lại Harbor và nạp lại image.

Với cấu hình mặc định, `/opt/harbor` và `/u01/harbor` sẽ bị xóa. Hãy sao lưu
dữ liệu và chỉ chạy trên đúng node mục tiêu. Không dùng playbook này để thử kết
nối hoặc kiểm tra inventory.

Ngoài ra, role tạo project và replication hiện kỳ vọng API trả mã `201`; chạy
lại trên môi trường đã có sẵn project hoặc policy có thể thất bại do đối tượng
đã tồn tại.
