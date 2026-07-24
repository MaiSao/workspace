# Bộ case PAT cho Kubernetes Platform

## 1. Mục tiêu và phạm vi

Tài liệu này chuyển các tiêu chí trong
`PL20_Mau bieu CTKT Kubernetes Platform.xlsx` thành bộ case PAT có thể dùng để:

- nghiệm thu một cụm mới trước khi bàn giao;
- kiểm tra lại sau nâng cấp, thay đổi CNI, storage hoặc control plane;
- chạy health check định kỳ;
- diễn tập HA, khôi phục và sự cố có kiểm soát.

Bản tự động hóa Ansible nằm trong `k8s_pat/playbook.yml` và cấu hình case ở
`k8s_pat/group_vars/pat.yml`. Runner sinh báo cáo Markdown/JSON, đếm case
`PASS`/`FAILED`/`N/A`, ghi lý do và đề xuất xử lý. Những case trong catalog
chưa có command tự động được ghi nhận là `N/A` dạng coverage gap để không bị
bỏ sót khi nghiệm thu.

Bộ case bám PL20 nhưng ưu tiên kiểm chứng hành vi thực tế. Việc một object tồn
tại hoặc một process đang chạy chưa đủ để kết luận nền tảng ổn định.

### Quy ước

| Ký hiệu | Ý nghĩa |
|---|---|
| P0 | Điều kiện chặn nghiệm thu; một case thất bại thì không bàn giao |
| P1 | Bắt buộc xử lý hoặc có ngoại lệ/rủi ro được phê duyệt |
| P2 | Tùy chọn theo tính năng đã triển khai |
| AUTO-RO | Tự động, chỉ đọc, được phép chạy trên production |
| AUTO-SYN | Tự động, tạo tài nguyên thử trong namespace PAT rồi dọn dẹp |
| AUTO-CHAOS | Tự động gây lỗi có kiểm soát; chỉ chạy khi được phê duyệt |
| PROD-RO | Production-safe, chỉ đọc hoặc truy vấn API với tải không đáng kể |
| PROD-SYN | Production-safe có tạo tài nguyên tổng hợp, tải bị giới hạn và tự cleanup |
| HYBRID | Tự động thu thập bằng chứng, con người xác nhận phần ngoài cluster |
| MANUAL | Phụ thuộc hạ tầng, quy trình hoặc hệ thống ngoài cluster |

Mọi case `AUTO-SYN` phải dùng namespace riêng, ví dụ `k8s-pat`, có label
`pat.viettel.vn/run-id`, TTL và bước cleanup. Mọi case `AUTO-CHAOS` mặc định
phải bị khóa bằng biến opt-in và không được chạy đồng thời nhiều failure domain.

## 2. Tiêu chuẩn nghiệm thu chung

- 100% case P0 phải `PASS`; không chấp nhận `SKIP`.
- Case P1 phải `PASS`, hoặc có biên bản ngoại lệ nêu owner, thời hạn xử lý và
  biện pháp giảm thiểu.
- Case P2 chỉ được `SKIP` khi tính năng tương ứng không nằm trong thiết kế.
- Sau mỗi case gây lỗi, cluster phải trở về trạng thái ban đầu trong RTO của
  case; không còn node/pod/PVC/job PAT bị treo.
- Báo cáo phải lưu thời gian UTC, inventory, phiên bản component, câu lệnh,
  stdout/stderr đã khử secret, kết quả, thời lượng và bằng chứng trước/sau.
- Ngưỡng mặc định đề xuất: API availability >= 99,9% trong bài soak; node và
  control-plane recovery <= 5 phút; VIP failover <= 30 giây; mất pod ứng dụng
  không làm gián đoạn request hợp lệ; backup etcd mới nhất <= 24 giờ.

Các ngưỡng trên cần được thay bằng SLA/RTO/RPO đã phê duyệt của hệ thống nếu có.

## 3. Catalog case PAT

### A. Baseline, control plane và health

| ID | P | Chế độ | Ánh xạ PL20 | Bài đo và điều kiện đạt |
|---|---|---|---|---|
| PAT-A01 | P0 | AUTO-RO + HYBRID | II.1.1, II.2.1.1-2.1.4 | Đối chiếu inventory với node/etcd member: >=3 control-plane, số etcd lẻ (3 hoặc 5), >=3 worker; hostname/IP không trùng. Xác minh control-plane và worker nằm trên các failure domain/storage domain theo CTKT. |
| PAT-A02 | P0 | AUTO-RO | II.1.1, II.1.3 | Trên từng node kiểm CPU >=4, RAM >=8 GiB, filesystem chứa container image >=100 GiB; root, `/u01`, inode và dung lượng khả dụng đúng thiết kế. |
| PAT-A03 | P0 | AUTO-RO | I.2.7, I.2.8, II.1.7 | Kiểm OS/kernel được hỗ trợ, swap tắt, thời gian đồng bộ, hostname/DNS đúng, SELinux ở trạng thái đã được thiết kế và tương thích với runtime/CNI. Không dùng kết luận “phải disable SELinux” nếu bản phân phối hỗ trợ enforcing. |
| PAT-A04 | P0 | AUTO-RO | II.1.5, II.1.6, II.4.2.1 | Lấy version API server, controller, scheduler, kubelet, kube-proxy, kubectl. Tất cả control-plane cùng minor/patch; version skew hợp lệ; minor còn được Kubernetes/vendor hỗ trợ. Không kiểm theo ngưỡng cũ `>=1.19`. |
| PAT-A05 | P0 | AUTO-RO | II.1.4, II.3.1.5 | `containerd`, `kubelet`, HAProxy/Keepalived (nếu bật) active và enabled; CRI trả lời; không có restart loop hoặc lỗi mức error lặp lại trong journal 30 phút gần nhất. |
| PAT-A06 | P0 | AUTO-RO | II.2.1.5 | Gọi `/livez`, `/readyz?verbose` qua từng API server và qua endpoint HA. Tất cả check trả `ok`, TLS/SAN hợp lệ, không có HTTP 5xx. |
| PAT-A07 | P0 | AUTO-RO | II.2.1.5 | HAProxy có đủ backend API, mọi backend expected ở trạng thái UP; VIP chỉ nằm trên đúng một master; TCP/API qua VIP hoạt động từ ít nhất hai mạng nguồn được phép. |
| PAT-A08 | P0 | AUTO-RO | II.2.2.3 | Inventory node tồn tại trong cluster, tất cả `Ready`; không có `MemoryPressure`, `DiskPressure`, `PIDPressure`, `NetworkUnavailable`; lease node được cập nhật. |
| PAT-A09 | P0 | AUTO-RO | II.2.1.1 | Số static pod kube-apiserver, controller-manager, scheduler và etcd bằng số control-plane; container Ready, restart count không tăng trong cửa sổ quan sát. |
| PAT-A10 | P0 | AUTO-RO | II.1.2, II.2.1.2 | `etcdctl endpoint health/status --cluster` thành công; member list đúng inventory; chỉ có một leader; revision nhất quán; không alarm; DB size dưới ngưỡng vận hành và storage latency đạt SLA. |
| PAT-A11 | P0 | AUTO-RO | II.3.1.2 | Kiểm hạn toàn bộ CA, API, etcd, front-proxy, kubelet client/server certificate. Không certificate hết hạn trong ngưỡng cảnh báo (mặc định 90 ngày), không CSR Pending/Denied bất thường; exporter/alert rule thực sự phát cảnh báo. |
| PAT-A12 | P0 | AUTO-RO | I.2.4, II.4.1.1 | Audit policy và tham số audit-log có trên mọi API server; file log được ghi, rotate theo size/age/backup; không log nội dung Secret; sink log tập trung nhận được audit event. |
| PAT-A13 | P0 | AUTO-RO | I.1.2, II.4.1.3 | CoreDNS, Calico, kube-proxy, metrics-server và add-on được bật đều rollout thành công; DaemonSet `desired=updated=available`; APIService cần thiết ở trạng thái Available. |
| PAT-A14 | P0 | AUTO-RO | II.3.1.3, II.3.1.4, II.4.2.2 | Kiểm logrotate/journald retention; root, `/var`, `/u01`, imagefs và inode <80%; kubelet image GC có high > low và còn headroom; không log ứng dụng làm đầy phân vùng OS. |
| PAT-A15 | P0 | AUTO-RO + HYBRID | II.2.3.1, II.2.3.2 | Backup etcd gần nhất <=24h, `etcdutl snapshot status` hợp lệ, backup có checksum, được mã hóa/phân quyền và có bản sao ở >=2 storage độc lập; CA/key/cert và manifest quan trọng cũng được backup. |
| PAT-A16 | P1 | AUTO-RO + HYBRID | II.4.1.1-4.1.6 | Xác minh collector, Prometheus-compatible scraper, remote metric storage và dashboard/alert backend sẵn sàng; target control plane, node, CNI, DNS và ứng dụng đều UP; retention đúng thiết kế. |

### B. Functional và workload conformance

| ID | P | Chế độ | Ánh xạ PL20 | Bài đo và điều kiện đạt |
|---|---|---|---|---|
| PAT-B01 | P0 | AUTO-SYN | I.1.2 | Tạo pod DNS trên mỗi worker; phân giải Service cùng namespace, FQDN khác namespace và external domain; kết quả đúng, không timeout/SERVFAIL. |
| PAT-B02 | P0 | AUTO-SYN | I.1, II.1.8 | Tạo pod client/server trên cùng node và khác node; kiểm TCP/UDP/ICMP theo phạm vi cho phép. Tỷ lệ thành công 100%, không trùng Pod IP, route MTU không gây fragmentation bất thường. |
| PAT-B03 | P0 | AUTO-SYN | I.1.1, I.1.3, I-R18, I.2.3 | Tạo namespace/pod test; áp `default-deny` rồi policy allow có chủ đích. Kết nối bị chặn và được mở đúng rule; chứng minh CNI thực thi policy, không chỉ có object NetworkPolicy. |
| PAT-B04 | P1/P2 | AUTO-SYN | I.1 | Khi Multus/Macvlan/SR-IOV bật, tạo pod gắn >=2 network; interface, IP, route, gateway đúng NAD; IP duy nhất; xóa/tạo lại pod không làm rò IP; kiểm failover bond nếu thiết kế có bond. |
| PAT-B05 | P0 | AUTO-SYN | I-R40, I-R41, II.1.9, II.1.10 | Tạo Deployment + ClusterIP Service; kiểm EndpointSlice cập nhật khi pod thay đổi, truy cập qua Service ổn định. Nếu có Ingress/Gateway/LB, kiểm HTTP/HTTPS, TLS, route nội bộ/public tách đúng thiết kế. |
| PAT-B06 | P0 | AUTO-SYN | II.6.3 | Tạo StorageClass/PVC/pod, ghi checksum, xóa và tạo lại pod, đọc lại dữ liệu. PVC Bound trong timeout; dữ liệu giữ nguyên; expansion/snapshot được kiểm nếu CTKT yêu cầu. |
| PAT-B07 | P0 | AUTO-RO | II.2.2.1, II.2.2.2 | Mọi Deployment production có >=2 replica (trừ ngoại lệ), pod được phân tán trên >=2 worker/failure domain bằng anti-affinity hoặc topology spread; PDB không cho phép voluntary disruption làm mất toàn bộ replica. |
| PAT-B08 | P0 | AUTO-RO + AUTO-SYN | I.1.4-I.1.7 | Mọi container ứng dụng có startup/readiness/liveness phù hợp. Readiness failure loại endpoint nhưng không restart container; liveness failure làm restart theo threshold; hai probe không dùng cùng semantics; readiness không phụ thuộc cứng vào external dependency. |
| PAT-B09 | P0 | AUTO-RO | II.4.2.3, II.4.2.4 | Mọi container có CPU/memory requests và limits theo policy; namespace có LimitRange/ResourceQuota khi yêu cầu; kubelet có PID/resource reservation; Java workload có Xms/Xmx phù hợp limit và bằng chứng performance test. |
| PAT-B10 | P0 | AUTO-RO | I-R18, II.5.2, II.6.1, II.6.2 | Không triển khai ứng dụng vào `default`; config thường ở ConfigMap, dữ liệu nhạy cảm ở Secret/Vault; không hard-code secret trong image, command, ConfigMap hoặc manifest; cấu hình tách khỏi application code. |
| PAT-B11 | P1/P2 | AUTO-SYN | II.6.4 | Với workload dùng HPA: metrics API trả dữ liệu; condition `AbleToScale=True`, `ScalingActive=True`; phát tải làm scale-out trong timeout, ngừng tải làm scale-in đúng stabilization window, không vượt min/max. |
| PAT-B12 | P0 | AUTO-SYN | II.4.1.1, II.4.1.2 | Ghi một marker duy nhất từ pod và audit API; marker xuất hiện ở hệ thống log tập trung trong <=60 giây, đủ cluster/namespace/pod/container/node và không lộ secret. |
| PAT-B13 | P0 | AUTO-SYN | II.3.1.2, II.4.1.3-II.4.1.5 | Tạo metric/điều kiện cảnh báo tổng hợp; target được scrape, query trả dữ liệu, alert chuyển Pending -> Firing -> Resolved và tới đúng kênh trong SLA. |
| PAT-B14 | P0 | AUTO-RO + HYBRID | II.1.2, II.2.1.3, II.2.1.4, II.4.1.6, II.6.3 | Stateful production và Prometheus dùng remote CSI/PV theo CTKT; không dùng `hostPath`/local-path cho dữ liệu cần HA; replica/storage nằm ở failure domain độc lập. |
| PAT-B15 | P1 | HYBRID | II.5.6, II.5.7 | Cluster chỉ pull registry/project được phép; account runtime read-only, CI mới được push; anonymous/unapproved push bị từ chối; image dùng digest hoặc tag bất biến và không có Critical CVE chưa được chấp thuận. |

### C. Security và policy enforcement

| ID | P | Chế độ | Ánh xạ PL20 | Bài đo và điều kiện đạt |
|---|---|---|---|---|
| PAT-C01 | P0 | AUTO-RO + AUTO-SYN | I.2.1, I.2.2, II.5.3 | API server dùng Node,RBAC; request không credential tới API protected bị 401/403; service account/user ít quyền không thể đọc Secret hoặc tạo privileged pod; `kubectl auth can-i` khớp ma trận quyền. |
| PAT-C02 | P0 | AUTO-SYN | I.2.3, I.2.5, II.5.4 | Pod Security Admission hoặc Kyverno/Gatekeeper ở trạng thái enforce. Manifest root/privileged/thiếu resource theo policy bị reject; manifest hợp lệ được nhận; webhook failure policy và replica không tạo single point of failure. |
| PAT-C03 | P0 | AUTO-RO | I.2.5, II.5.5 | Workload production đặt `runAsNonRoot`, UID/GID phù hợp, `allowPrivilegeEscalation=false`, drop capability không cần thiết và seccomp profile; ngoại lệ có owner/lý do/thời hạn. |
| PAT-C04 | P1 | AUTO-RO + AUTO-SYN | II.5.8 | Container root filesystem read-only; thư mục cần ghi dùng volume riêng. Ghi vào rootfs bị từ chối, ứng dụng vẫn hoạt động qua volume được cấp. |
| PAT-C05 | P0 | AUTO-RO | II.5.5, II.5.8 | Phát hiện pod dùng privileged, hostPID/IPC/network, hostPath nhạy cảm, hostPort, capability nguy hiểm hoặc service-account token không cần thiết; không có vi phạm ngoài allowlist. |
| PAT-C06 | P0 | AUTO-RO + HYBRID | I.2.1, I.2.6, II.5.1 | So khớp port đang listen với firewall/security-group matrix. API/etcd/kubelet/metrics/NodePort không mở ra nguồn ngoài thiết kế; worker không bị truy cập trực tiếp từ Internet. |
| PAT-C07 | P1/P2 | HYBRID | I-R40, I-R41, II.1.9-II.1.11 | API public đi qua WAF/LB/API Gateway; TLS và route public/internal tách biệt; request chứa payload kiểm thử an toàn bị WAF chặn; không có đường bypass trực tiếp vào worker/NodePort. |
| PAT-C08 | P0 | AUTO-RO + HYBRID | II.5.2, II.5.7 | Quét repo/manifest/runtime env để phát hiện plaintext credential; Secret at-rest encryption/KMS được xác minh nếu CTKT yêu cầu; backup secret/etcd được mã hóa và phân quyền. |
| PAT-C09 | P0 | AUTO-RO | II.1.6, II.4.2.1, II.5.9 | Đối chiếu version và scanner với CVE/deprecation. CVE-2021-25741 phải được xử lý bằng phiên bản đã vá; không vô hiệu `subPath` trên bản mới. Không yêu cầu PSP hay Dynamic Kubelet Configuration trên version đã loại bỏ chúng. |
| PAT-C10 | P0 | AUTO-SYN | I.2.4 | Dùng identity PAT tạo/sửa/xóa ConfigMap rồi truy vấn audit backend. Event có đúng user, verb, resource, namespace, response code và request ID; nội dung nhạy cảm không bị ghi. |

### D. HA, fault tolerance và disaster recovery

| ID | P | Chế độ | Ánh xạ PL20 | Bài đo và điều kiện đạt |
|---|---|---|---|---|
| PAT-D01 | P0 | AUTO-SYN | II.2.2.1-II.2.2.3 | Xóa một pod của Deployment PAT trong lúc phát request. Controller tạo pod thay thế, Service không mất toàn bộ endpoint, request success rate đạt SLA và replica trở lại desired <=2 phút. |
| PAT-D02 | P0 | AUTO-CHAOS | II.2.2.1, II.2.2.2 | Cordon/drain một worker có workload PAT. PDB được tôn trọng, pod chuyển sang node khác, dịch vụ không gián đoạn vượt SLA; uncordon và cleanup thành công. |
| PAT-D03 | P0 | AUTO-CHAOS | II.2.1.4, II.2.2.3 | Tắt/mất kết nối một worker. Cluster vẫn quản trị được, workload HA được reschedule, cảnh báo phát đúng, node phục hồi và trở lại Ready trong RTO. |
| PAT-D04 | P1 | AUTO-CHAOS | II.3.1.5 | Lần lượt restart kubelet rồi containerd trên một worker. Pod hiện hữu/được quản lý phục hồi theo thiết kế; node Ready lại <=5 phút; không orphan container hoặc mất dữ liệu. |
| PAT-D05 | P0 | AUTO-CHAOS | I.1.1-I.1.3 | Xóa một pod Calico/Multus/Whereabouts trên một node. DaemonSet tự hồi phục; kết nối hiện hữu và cấp IP mới không gián đoạn vượt SLA; không rò IP. |
| PAT-D06 | P0 | AUTO-CHAOS | I.1.2 | Xóa một replica CoreDNS trong lúc chạy truy vấn liên tục. DNS success rate đạt SLA, replica hồi phục <=2 phút, không có SERVFAIL kéo dài. |
| PAT-D07 | P0 | AUTO-CHAOS | II.2.1.1, II.2.1.5 | Dừng kubelet hoặc static kube-apiserver trên một control-plane không giữ VIP. API qua VIP vẫn sẵn sàng; HAProxy loại backend lỗi; component phục hồi trong RTO. |
| PAT-D08 | P0 | AUTO-CHAOS | II.2.1.5 | Dừng Keepalived/HAProxy hoặc cô lập node đang giữ VIP theo runbook. VIP chuyển sang master khác <=30 giây, API request tiếp tục đạt SLA, chỉ một node giữ VIP. |
| PAT-D09 | P0 | AUTO-CHAOS | II.2.1.2 | Dừng một etcd member trong cụm 3/5 member. Quorum và API còn hoạt động, leader ổn định/tự bầu lại, alarm đúng; member trở lại healthy và catch-up trong RTO. |
| PAT-D10 | P0 | AUTO-CHAOS | II.2.1.2 | Guard test xác minh automation không cho phép dừng thêm member khi quorum đang suy giảm. Không thực sự phá quorum trên production; bài mất quorum chỉ chạy ở lab clone. |
| PAT-D11 | P0 | AUTO-CHAOS | II.2.1.3, II.2.1.4, II.6.3 | Với remote CSI, gây mất pod/node đang giữ volume; volume detach/attach sang node mới, checksum dữ liệu giữ nguyên và ứng dụng Ready trong RTO. Local RWO không có khả năng này phải được ghi nhận fail/exception. |
| PAT-D12 | P0 | AUTO-CHAOS (lab) | II.2.3.1, II.3.1.1 | Restore snapshot etcd gần nhất vào cluster lab cô lập. Cluster mở API được, object mẫu và checksum đúng, toàn bộ node/add-on phục hồi; đo và đạt RPO/RTO. |
| PAT-D13 | P1 | AUTO-CHAOS (lab) | II.2.3.2, II.3.1.2 | Diễn tập renew certificate trên lab/rolling control-plane; kubeconfig, kubelet và API tiếp tục xác thực; không downtime vượt SLA; alert expiry trở về bình thường. |
| PAT-D14 | P1 | AUTO-CHAOS (lab) | II.3.1.5, III.1.2 | Chạy script join/detach worker và control-plane bằng input hợp lệ/sai. Script idempotent, validate input, log rõ, không phá quorum; node được thêm/xóa sạch và tài liệu đúng thực tế. |
| PAT-D15 | P1 | AUTO-CHAOS (lab) | II.1.5, II.1.6, III.1.1 | Diễn tập nâng một minor/patch theo đúng thứ tự và rollback/restore khi lỗi giả lập. Version skew luôn hợp lệ, workload và dữ liệu giữ nguyên, addon tương thích. |

### E. Performance, capacity và soak

| ID | P | Chế độ | Ánh xạ PL20 | Bài đo và điều kiện đạt |
|---|---|---|---|---|
| PAT-E01 | P0 | AUTO-SYN | II.2.1.5, II.4.1.3 | Phát request API read/write an toàn trong 15-30 phút; đo availability, p95/p99 latency, HTTP 429/5xx. Đạt SLO và không làm tăng etcd alarm/control-plane restart. |
| PAT-E02 | P0 | AUTO-SYN | I.1.2 | Phát DNS query nội bộ/external từ nhiều node; success >=99,9%, p95 theo SLA (đề xuất <=100 ms nội bộ), không SERVFAIL kéo dài, CoreDNS không CPU throttle bất thường. |
| PAT-E03 | P1 | AUTO-SYN | I.1, I.1.1, II.1.8 | Đo throughput, latency, packet loss, MTU giữa pod cùng/khác node và secondary network. Kết quả đạt baseline đã phê duyệt; policy vẫn được thực thi khi có tải. |
| PAT-E04 | P1 | AUTO-SYN | I-R27, II.4.2.2-II.4.2.4, II.6.4 | Tạo burst pod/HPA trong quota PAT; scheduler không có Pending bất thường, IP pool còn headroom, imagefs không đầy, HPA phản ứng đúng và node còn reserve cho system. |
| PAT-E05 | P0 | AUTO-SYN | II.2, II.3, II.4 | Soak tối thiểu 24h với request và churn pod nhỏ: API/DNS/service đạt SLO, không memory leak/restart tăng đều, disk/inode/etcd DB không tăng vô hạn, không alert P0/P1 chưa xử lý. |

### F. Bằng chứng ngoài cluster và tài liệu

| ID | P | Chế độ | Ánh xạ PL20 | Bài đo và điều kiện đạt |
|---|---|---|---|---|
| PAT-F01 | P0 | MANUAL | II.2.1.3, II.2.1.4, III.1.1 | Có sơ đồ as-built đối chiếu được node, rack/zone, switch, storage failure domain, VIP/LB và luồng mạng; thông tin khớp inventory và hệ thống thực. |
| PAT-F02 | P1 | MANUAL | III.1.2 | Runbook VHKT mô tả input/output, quyền, log, rollback cho join/detach, backup/restore, renew cert, upgrade và xử lý sự cố; các lệnh đã được diễn tập. |
| PAT-F03 | P0 | HYBRID | I.2.1, I.2.6, II.5.1 | Export rule firewall/security group và ticket phê duyệt; rule tối thiểu, có owner, nguồn/đích/port rõ, không có `0.0.0.0/0` tới cổng quản trị. |
| PAT-F04 | P1/P2 | HYBRID | I-R40, I-R41, II.1.9-II.1.11 | Cung cấp cấu hình và log chứng minh WAF/API Gateway/Ingress/LB không có đường bypass, route public/internal đúng và HA. |
| PAT-F05 | P1 | HYBRID | II.5.6, II.5.7 | Cung cấp policy registry, RBAC project, immutable tag, retention, scan report và pipeline gate; test account runtime không push được, CI account đúng scope. |

### G. PAT bổ sung dành cho production

Các case dưới đây được thiết kế để chạy trên production mà không chủ động dừng
node hoặc component. `PROD-SYN` phải có giới hạn CPU, memory, thời gian, QPS và
phải dừng ngay nếu health gate của cluster chuyển xấu.

| ID | P | Chế độ | Bài đo và điều kiện đạt |
|---|---|---|---|
| PAT-P01 | P0 | PROD-RO | **Vòng đời version và API:** minor Kubernetes còn được hỗ trợ, patch đáp ứng policy cập nhật, version skew hợp lệ; quét manifest/live object không dùng API đã bị remove ở version đích; có kế hoạch nâng cấp trước EOL. |
| PAT-P02 | P0 | PROD-RO | **Configuration drift:** chuẩn hóa rồi so hash kubelet config, containerd config, audit/encryption config và static-pod manifest giữa các node cùng vai trò; chỉ cho phép trường khác biệt theo node; mọi drift có change record hoặc bị fail. |
| PAT-P03 | P0 | PROD-RO | **CRI, cgroup và kernel:** runtime hỗ trợ CRI v1; kubelet/runtime cùng dùng `systemd` cgroup khi host dùng systemd; IPv4 forwarding, module/sysctl và sandbox image đúng thiết kế; không có cgroup-driver mismatch trong log. |
| PAT-P04 | P0 | PROD-RO | **Swap policy hiện hành:** control-plane không dùng swap. Worker hoặc dùng `NoSwap`, hoặc `LimitedSwap` đã phê duyệt trên cgroup v2, swap được mã hóa/giám sát và system-critical daemon không bị swap; không chấp nhận trạng thái ngoài policy. |
| PAT-P05 | P1 | PROD-RO | **Graceful node shutdown:** kubelet có shutdown grace period khác 0 theo PriorityClass hoặc có runbook thay thế được diễn tập; tổng termination grace không vượt maintenance window; critical pod được ưu tiên và có alert khi node shutdown. |
| PAT-P06 | P0 | PROD-SYN | **API Priority and Fairness:** FlowSchema/PriorityLevelConfiguration hợp lệ; gửi burst QPS thấp, có trần, bằng identity PAT trong khi đo request hệ thống/health. Request quan trọng vẫn đạt SLO, PAT được queue/reject có kiểm soát, API không 5xx hoặc restart. |
| PAT-P07 | P0 | PROD-RO + PROD-SYN | **Admission availability/latency:** webhook có nhiều replica, spread/PDB, timeout nhỏ, scope không chặn namespace hệ thống hoặc dependency của chính nó; đo dry-run/create hợp lệ p95 theo SLO; policy xấu bị reject. Failure-mode của webhook chỉ diễn tập ở staging. |
| PAT-P08 | P0 | PROD-SYN | **Pod Security hiện hành:** namespace ứng dụng enforce tối thiểu `baseline`, namespace nhạy cảm enforce `restricted` hoặc policy tương đương, version được pin/kiểm soát; manifest privileged, root, hostPath và seccomp không hợp lệ bị reject; exemption có allowlist. |
| PAT-P09 | P0 | PROD-RO | **RBAC escalation review:** không user thường thuộc `system:masters`; không wildcard/cluster-admin/bind/escalate/impersonate/nodes-proxy ngoài allowlist; quyền Secret chủ yếu theo namespace; subject không còn tồn tại không giữ binding. |
| PAT-P10 | P0 | PROD-RO + PROD-SYN | **ServiceAccount token:** pod không gọi API đặt `automountServiceAccountToken=false`; workload cần API dùng service account riêng và token projected ngắn hạn, có audience; xóa pod làm bound token mất hiệu lực; không có legacy long-lived token ngoài ngoại lệ. |
| PAT-P11 | P0 | PROD-SYN | **Secret encryption at rest:** tạo canary Secret không chứa dữ liệu thật; đọc trực tiếp key tương ứng từ etcd mà không in plaintext vào report, xác nhận prefix/provider mã hóa và không dùng `identity` làm writer; API vẫn giải mã đúng; cấu hình giống nhau trên mọi API server và có quy trình rotate key. |
| PAT-P12 | P0 | PROD-RO | **API bypass surfaces:** kubelet anonymous/read-only port tắt, port 10250 bị giới hạn nguồn và dùng webhook/x509; quyền `nodes/proxy` tối thiểu; etcd chỉ mTLS từ API/backup; runtime socket và static manifest directory chỉ root có quyền ghi. |
| PAT-P13 | P0 | PROD-SYN | **Network isolation đầy đủ:** trong namespace PAT áp default-deny ingress/egress, cho phép riêng DNS và service đích; chứng minh traffic ngoài allowlist/cross-namespace bị chặn, DNS và traffic hợp lệ vẫn chạy; kiểm cả egress chứ không chỉ ingress. |
| PAT-P14 | P0 | PROD-RO + PROD-SYN | **Placement và voluntary disruption:** topology label tồn tại, replica production trải qua node/zone theo SLO; PDB có `ALLOWED DISRUPTIONS` phù hợp; Eviction API trên workload PAT tôn trọng PDB; không dùng delete trực tiếp để kết luận PDB hoạt động. |
| PAT-P15 | P0 | PROD-SYN | **Rolling update/rollback:** Deployment PAT phục vụ request liên tục trong lúc đổi image digest/config, `maxUnavailable`/`maxSurge` đúng policy; không mất toàn bộ endpoint, rollout đạt timeout, rollback trả lại digest và checksum ban đầu. |
| PAT-P16 | P0/P1 | PROD-SYN | **CSI production:** StorageClass HA dùng CSI, topology và `WaitForFirstConsumer` khi phù hợp; PVC bind/mount/I/O/expand thành công; snapshot rồi restore checksum nếu driver hỗ trợ; không có volume-health abnormal event hoặc capacity mismatch. |
| PAT-P17 | P0 | PROD-RO + PROD-SYN | **Software supply chain:** production không dùng `latest`; image được pin digest hoặc chữ ký/provenance được admission xác minh; registry ngoài allowlist, unsigned image và image vượt ngưỡng CVE bị reject; scan lại image đang chạy theo lịch. |
| PAT-P18 | P1/P2 | PROD-SYN | **North-south traffic:** ưu tiên Gateway API cho triển khai mới; kiểm listener/route/TLS certificate, hostname/path, backend health, timeout và HTTP policy; Host/SNI sai và đường truy cập bypass trực tiếp worker/NodePort bị từ chối. |
| PAT-P19 | P0 | PROD-RO + PROD-SYN | **Node pressure safety:** kube/system reserved, eviction threshold, PriorityClass, ephemeral-storage request/limit và `emptyDir.sizeLimit` đúng policy; tạo workload PAT trong quota nhỏ để xác nhận scheduler/quota; không chủ động làm node MemoryPressure/DiskPressure trên production. |
| PAT-P20 | P0 | PROD-SYN | **Log rotation và backpressure:** phát log có marker với tốc độ/dung lượng bị chặn; marker đến backend, container log rotate theo `containerLogMaxSize/Files`, collector không retry/drop tăng bất thường, node disk không tăng vượt guardrail. |
| PAT-P21 | P0 | PROD-RO + HYBRID | **Backup recoverability:** snapshot etcd mới, checksum/status hợp lệ, mã hóa và off-cluster; lần restore thành công gần nhất ở lab không quá chu kỳ quy định (đề xuất 90 ngày), đo được RPO/RTO và có bằng chứng object/checksum sau restore. |
| PAT-P22 | P0 | PROD-SYN | **Observability blind-spot:** synthetic alert riêng cho API, etcd, kubelet/runtime, DNS, CNI, storage, certificate, backup và workload; mỗi tín hiệu đi tới đúng receiver rồi resolve; target/remote-write/log pipeline failure cũng phải tự phát alert. |

## 4. Ma trận truy vết PL20

| Nhóm tiêu chí PL20 | Case PAT bao phủ |
|---|---|
| I.1, I.1.1-I.1.3, các dòng bổ sung về namespace và Pod CIDR | PAT-B01-B04, PAT-B10, PAT-C02, PAT-D05-D06, PAT-E02-E04 |
| I.1.4-I.1.7 về probe | PAT-B08, PAT-D01, PAT-P15 |
| I.2.1-I.2.8 về access, RBAC, policy, audit, root, firewall, swap, SELinux | PAT-A03, PAT-A12, PAT-C01-C06, PAT-C10, PAT-F03, PAT-P04, PAT-P08-P13 |
| Các dòng bổ sung WAF và API Gateway | PAT-B05, PAT-C07, PAT-F04 |
| II.1.1-II.1.11 về kiến trúc và công nghệ | PAT-A01-A04, PAT-B02, PAT-B05, PAT-B14, PAT-C07, PAT-D15, PAT-P01-P05, PAT-P18 |
| II.2.1.1-II.2.1.5 về HA | PAT-A01, PAT-A06-A10, PAT-B14, PAT-D07-D11 |
| II.2.2.1-II.2.2.3 về fault tolerance | PAT-B07, PAT-D01-D05, PAT-P14-P15 |
| II.2.3.1-II.2.3.2 về backup | PAT-A15, PAT-D12-D13, PAT-P21 |
| II.3.1.1-II.3.1.5 về vận hành | PAT-A11, PAT-A14-A15, PAT-D12-D14, PAT-F02 |
| II.4.1.1-II.4.1.6 về log, metrics, dashboard | PAT-A12, PAT-A16, PAT-B12-B13, PAT-E01-E05, PAT-P20, PAT-P22 |
| II.4.2.1 Dynamic Kubelet Configuration | Không áp dụng trên Kubernetes hiện hành; thay bằng PAT-A04-A05, PAT-P02-P03 và quản lý config qua Ansible/kubeadm |
| II.4.2.2-II.4.2.4 về GC và resource | PAT-A14, PAT-B09, PAT-E04, PAT-P19-P20 |
| II.5.1-II.5.9 về security | PAT-B15, PAT-C01-C10, PAT-F03-F05, PAT-P07-P13, PAT-P17 |
| II.6.1-II.6.4 về config, stateful, HPA | PAT-B06, PAT-B09-B11, PAT-B14, PAT-D11, PAT-P16, PAT-P19 |
| III.1.1-III.1.2 về tài liệu | PAT-D14-D15, PAT-F01-F02 |

## 5. Tiêu chí lỗi thời và tiêu chí thay thế

Khi tiêu chí cũ và tiêu chí thay thế khác nhau, kết quả PAT phải chấm theo cột
“Tiêu chí thay thế”. Giá trị cũ chỉ được giữ để truy vết PL20.

| PL20 cũ | Vấn đề | Tiêu chí thay thế dùng cho production | Case |
|---|---|---|---|
| I.1: pod phải có từ 2 network để dự phòng | Số interface không tự tạo HA; nhiều network còn tăng độ phức tạp và blast radius. | Primary CNI phải HA và pass same/cross-node connectivity. Secondary network chỉ bắt buộc khi CTKT yêu cầu tách traffic; khi có phải test IPAM, route, failover và leak. | PAT-B02-B04, PAT-D05 |
| I.1.1/I.1.3: kiểm tài liệu hoặc object NetworkPolicy | API có thể tồn tại nhưng CNI không thực thi policy. | Chạy negative/positive connectivity test cho default-deny ingress/egress, DNS exception và allowlist cross-namespace. | PAT-B03, PAT-P13 |
| I.1.4/I.1.5: mọi container phải có readiness và liveness | Job, sidecar hoặc container ngắn hạn không phải lúc nào cũng cần cả hai; liveness sai có thể gây cascading failure. | Phân loại workload. Service nhận traffic cần readiness; liveness chỉ dùng khi phát hiện lỗi không tự phục hồi; ứng dụng start chậm dùng startup probe; kiểm hành vi thực tế. | PAT-B08 |
| I.1.6: readiness và liveness không được cùng endpoint | Kubernetes nêu một pattern hợp lệ là cùng endpoint chi phí thấp nhưng liveness có failure threshold cao hơn. | Hai probe phải có semantics và threshold ngăn liveness restart khi ứng dụng chỉ tạm thời NotReady; không cấm tuyệt đối cùng URL. | PAT-B08 |
| I.1.7: readiness không được phụ thuộc external service | Quy tắc tuyệt đối không phù hợp mọi ứng dụng; readiness có thể phản ánh việc tạm thời không thể phục vụ do dependency. | Readiness chỉ fail khi instance không thể nhận traffic; tránh biến một dependency dùng chung thành cascading outage; quyết định dependency nào tham gia readiness phải có SLO/test tải. | PAT-B08, PAT-E05 |
| I-R27: Pod CIDR nên là `/16` | Prefix cố định không phản ánh số node, pod density, block size và dual-stack. | Tính capacity theo max node, max pod/node, CNI allocation block, tăng trưởng và >=20% headroom; synthetic burst không làm cạn/trùng IP. | PAT-E04 |
| I.2.2: RBAC hoặc ABAC | ABAC khó quản trị và không phải lựa chọn mặc định hiện đại; chỉ có RBAC object chưa chứng minh least privilege. | Dùng Node,RBAC và identity provider/webhook theo thiết kế; cấm `system:masters` cho vận hành thường ngày; kiểm wildcard, escalation, impersonation và quyền Secret. | PAT-C01, PAT-P09 |
| I.2.3/I.2.4: policy/audit chỉ cần được bật | “Có cấu hình” không chứng minh enforcement hoặc khả năng truy vết. | Policy phải reject manifest xấu; audit marker phải tới backend với identity/verb/resource đúng, không lộ Secret, retention và alert đạt SLA. | PAT-C02, PAT-C10 |
| I.2.5: bật PodSecurityPolicy | PSP bị loại bỏ từ Kubernetes 1.25. | Pod Security Admission enforce `baseline`/`restricted`, hoặc Kyverno/Gatekeeper tương đương; exemption tối thiểu và negative admission test bắt buộc. | PAT-C02, PAT-P08 |
| I.2.7: luôn disable swap | Kubernetes hiện hỗ trợ `NoSwap` và `LimitedSwap`; control-plane vẫn được khuyến nghị không dùng swap. | Control-plane không swap. Worker theo policy `NoSwap` hoặc `LimitedSwap` đã benchmark, dùng cgroup v2, encrypted swap, metrics và bảo vệ system daemon. | PAT-A03, PAT-P04 |
| I.2.8: luôn disable SELinux | Kubernetes hỗ trợ SELinux security context; yêu cầu tắt tuyệt đối làm giảm hardening. | SELinux ở mode được OS/runtime/CNI hỗ trợ, ưu tiên enforcing; workload/PV/CNI pass functional test và denial không hợp lệ được ghi audit. | PAT-A03, PAT-C03 |
| II.1.1: cố định 4 CPU/8 GiB/100 GiB | Chỉ là floor cũ, không chứng minh đủ capacity hoặc latency. | Sizing theo capacity model và SLO; kiểm allocatable headroom, CPU steal, memory pressure, disk IOPS/latency, inode và tăng trưởng. Floor PL20 chỉ là điều kiện tối thiểu. | PAT-A02, PAT-E04-E05 |
| II.1.6: Kubernetes `>=1.19` | 1.19 đã EOL; số version lớn hơn không đồng nghĩa còn được vá. | Minor phải còn trong support window, chạy patch theo policy, skew hợp lệ, không dùng API removed; upgrade trước EOL và không skip minor với kubeadm. | PAT-A04, PAT-P01 |
| II.1.7: danh sách Ubuntu 16.04, Debian 9, CentOS/RHEL 7... | Nhiều bản trong danh sách đã EOL hoặc không phù hợp runtime mới. | OS/kernel/container runtime phải còn được vendor hỗ trợ, tương thích version Kubernetes/CRI/cgroup; CIS/hardening baseline và patch SLA được đáp ứng. | PAT-A03, PAT-P03 |
| II.1.8: Calico >100 node phải dùng BGP route reflector | Quá phụ thuộc sản phẩm và một ngưỡng cứng; cluster có thể dùng datastore/mode CNI khác. | Theo compatibility/scaling guide của CNI đang dùng; benchmark route convergence, control-plane load, cross-node throughput và failure recovery ở quy mô dự kiến. | PAT-B02, PAT-E03-E04 |
| II.1.9/II.1.10: API Gateway/Ingress | Ingress API đã frozen; Kubernetes khuyến nghị Gateway API cho triển khai mới. | Chấp nhận Ingress hiện hữu còn hỗ trợ; thiết kế mới ưu tiên Gateway API. PAT kiểm controller HA, TLS, route, timeout/policy và không có bypass. | PAT-B05, PAT-P18 |
| II.2.1.1: luôn 3 master, 3 etcd, 3 worker | Ba control-plane/etcd là baseline HA phổ biến, nhưng số worker phải theo failure budget và capacity; topology quan trọng hơn số lượng. | Tối thiểu 3 control-plane và etcd lẻ cho HA; worker/failure domain đủ để mất một domain mà vẫn chạy critical workload và giữ headroom. | PAT-A01, PAT-D07-D10 |
| II.2.2.1/II.2.2.2: mọi Deployment >=2 pod và không cùng worker | Hai pod vẫn có thể cùng zone/rack; một số workload không yêu cầu HA. | Replica count theo SLO; critical workload có topology spread/anti-affinity, PDB và capacity để Eviction API hoạt động khi mất một failure domain. | PAT-B07, PAT-P14 |
| II.2.3: backup tồn tại ở hai storage | Backup có thể hỏng, không mã hóa hoặc không restore được. | Backup có freshness, checksum, encryption, off-cluster/immutable copy; restore định kỳ trên lab và đạt RPO/RTO bằng object/checksum thật. | PAT-A15, PAT-D12, PAT-P21 |
| II.3.1.2: chỉ giám sát certificate expiration | Certificate sống quá dài hoặc alert chưa được route vẫn có thể tạo rủi ro. | Certificate lifetime theo security policy, alert nhiều ngưỡng, rotation/renew rolling được diễn tập và private key được bảo vệ; không dùng validity cực dài để tránh renew. | PAT-A11, PAT-D13 |
| II.4.1.3-II.4.1.5: bắt buộc Prometheus/Grafana | Tên sản phẩm không phải outcome; exporter tồn tại không chứng minh scrape, retention hoặc alert delivery. | Dùng observability backend được phê duyệt; đủ metrics/SLO/alert/dashboard cho API, etcd, node, CNI, DNS, storage và workload; synthetic alert end-to-end. | PAT-A16, PAT-B13, PAT-P22 |
| II.4.2.1: Enable Dynamic Kubelet Configuration | Tính năng bị deprecate ở 1.22 và loại bỏ ở 1.24. | Quản lý kubelet config bằng kubeadm/Ansible/IaC; kiểm drift, schema/version, rolling apply, health gate và rollback. | PAT-P02-P03 |
| II.4.2.2: image GC high/low cố định (ví dụ 65/60) | Một ngưỡng không phù hợp mọi imagefs, tốc độ pull và workload. | High > low; ngưỡng dựa trên disk capacity/growth; kiểm free-space guardrail, GC thực sự thu hồi image và không gây pull storm. | PAT-A14, PAT-E04 |
| II.4.2.3: chỉ giới hạn CPU/RAM/Pod PID | Thiếu ephemeral storage, memory-backed `emptyDir`, namespace quota và system reserve. | Requests/limits theo policy cho CPU, memory, ephemeral storage; `emptyDir.sizeLimit`, PID, LimitRange/ResourceQuota, kube/system reserved và eviction alert. | PAT-B09, PAT-P19 |
| II.4.2.4: Java phải set Xms/Xmx bằng `JAVA_OPTS` | JVM hiện đại có container awareness; biến môi trường không phải cách duy nhất và tỷ lệ 50% không phổ quát. | Heap/non-heap/direct memory phải nằm trong memory limit với headroom, được chứng minh bằng load/GC/OOM test; chấp nhận mọi cơ chế cấu hình có bằng chứng. | PAT-B09, PAT-E05 |
| II.5.3: luôn `--anonymous-auth=false` | Từ Kubernetes 1.34 có thể giới hạn anonymous vào riêng health endpoints bằng AuthenticationConfiguration. | Protected API không bao giờ anonymous. Hoặc tắt hoàn toàn, hoặc chỉ allow `/livez`, `/readyz`, `/healthz` bằng cấu hình có điều kiện; negative request phải 401/403. | PAT-C01 |
| II.5.4: grep `enable-admission-plugins` | Admission có thể built-in, CEL policy hoặc webhook; process flag không chứng minh policy sống và an toàn. | Functional reject/allow test; webhook HA, latency, timeout, scope, dependency loop và failure behavior phù hợp availability policy. | PAT-C02, PAT-P07 |
| II.5.6/II.5.7: dùng Clair hoặc Falco để scan image | Falco chủ yếu là runtime threat detection, không thay image vulnerability scanner; tool name nhanh lỗi thời. | Scan build và image đang chạy; pin digest hoặc verify signature/provenance khi admission; registry allowlist, immutable artifact và CVE gate có exception expiry. | PAT-B15, PAT-P17 |
| II.5.8: toàn bộ pod phải immutable filesystem | Một số component hệ thống cần quyền ghi; chỉ kiểm field không chứng minh ứng dụng chạy được. | Mặc định `readOnlyRootFilesystem=true`; thư mục cần ghi mount volume tối thiểu; exception có policy; test ghi rootfs bị chặn nhưng ứng dụng vẫn hoạt động. | PAT-C04 |
| II.5.9: tắt `subPath` để né CVE-2021-25741 | Đây là workaround cho version cũ; áp dụng trên bản mới làm mất chức năng không cần thiết. | Chạy bản Kubernetes đã vá và scanner xác nhận không bị ảnh hưởng; không tắt `subPath` trên bản hỗ trợ nếu workload cần. | PAT-C09, PAT-P01 |
| II.6.3: mọi stateful app phải remote storage, cấm local | Một hệ thống distributed storage/database có thể dùng local PV nhưng vẫn đạt durability nhờ replication; “remote” không tự bảo đảm HA. | Storage architecture phải đạt RPO/RTO và failure-domain requirement; ưu tiên CSI, topology-aware binding, snapshot/restore, volume health; local chỉ khi replication và node-loss test chứng minh an toàn. | PAT-B14, PAT-D11, PAT-P16 |
| II.6.4: có object HPA là đạt | HPA có thể không lấy được metrics hoặc không scale. | HPA condition healthy; load thật làm scale-out và scale-in đúng window; request/resource metric đúng, không oscillation và không vượt capacity/quota. | PAT-B11, PAT-E04 |

PL20 còn có các dòng không có mã tiêu chí, ô loại M/O bị thiếu và kết quả mong
đợi của mục ConfigMap bị lẫn nội dung log. Tài liệu này đặt mã `I-Rxx` cho các
dòng bổ sung và dùng hành vi cần kiểm chứng làm chuẩn.

### Tham chiếu chính thức cập nhật

- [Production environment considerations](https://kubernetes.io/docs/setup/production-environment/)
- [Version skew policy](https://kubernetes.io/releases/version-skew-policy/)
- [Patch support and EOL](https://kubernetes.io/releases/patch-releases/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Liveness, readiness and startup probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/)
- [NetworkPolicy behavior](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Ingress frozen; Gateway API recommended](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Pod disruptions and PDB](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
- [Topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
- [Swap memory management](https://kubernetes.io/docs/concepts/cluster-administration/swap-memory-management/)
- [API Priority and Fairness](https://kubernetes.io/docs/concepts/cluster-administration/flow-control/)
- [Admission webhook good practices](https://kubernetes.io/docs/concepts/cluster-administration/admission-webhooks-good-practices/)
- [RBAC good practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
- [API server bypass risks](https://kubernetes.io/docs/concepts/security/api-server-bypass-risks/)
- [Encrypting confidential data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [ServiceAccount token guidance](https://kubernetes.io/docs/concepts/security/service-accounts/)
- [Container image security](https://kubernetes.io/docs/concepts/security/security-checklist/)
- [StorageClass topology and binding](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Operating etcd and backup](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- [NSA/CISA Kubernetes Hardening Guidance](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)

## 6. Đối chiếu nhanh với repository hiện tại

Đây là phát hiện từ cấu hình tĩnh, chưa phải kết quả chạy trên cluster:

| Mức | Phát hiện | Case chặn/xác minh |
|---|---|---|
| Blocker | `k8s_version: v1.31.4`; nhánh 1.31 đã EOL và không còn nhận security/bug fix. | PAT-A04, PAT-C09, PAT-D15, PAT-P01 |
| Blocker | `kubelet_readOnlyPort: 10255` đang bật. Đây là cổng không có authentication/authorization; nên tắt bằng `0`. | PAT-C01, PAT-C06, PAT-P12 |
| High | Certificate và cluster signing duration đang đặt `876000h` (xấp xỉ 100 năm), làm giảm ý nghĩa rotation/expiry control. | PAT-A11, PAT-D13 |
| High | Không thấy `EncryptionConfiguration`/`--encryption-provider-config`; Secret mặc định có nguy cơ được lưu plaintext trong etcd. | PAT-C08, PAT-P11 |
| High | Có Local Path Provisioner và Elasticsearch được thiết kế phụ thuộc local path; chỉ phù hợp production khi kiến trúc replication và node-loss test chứng minh đạt RPO/RTO. | PAT-B06, PAT-B14, PAT-D11, PAT-P16 |
| High | Có exporter và Fluent Bit nhưng không thấy Prometheus/Grafana trong service plan; chưa thể kết luận đạt PL20 về metrics, dashboard và alert. | PAT-A16, PAT-B13 |
| High | Có plaintext credential trong `group_vars/services.yml`; cần chuyển sang Ansible Vault/external secret và rotate credential đã lộ. | PAT-B10, PAT-C08 |
| Medium | `shutdownGracePeriod` và `shutdownGracePeriodCriticalPods` đang là `0s`; graceful node shutdown chưa được kích hoạt. | PAT-P05 |
| Medium | API server chưa khai báo rõ anonymous policy; cần kiểm bằng request không credential, không chỉ grep process. Sau nâng cấp >=1.34 có thể giới hạn anonymous riêng cho health endpoints. | PAT-C01 |
| Medium | Audit policy loại trừ toàn bộ service account trong `kube-system`, có thể bỏ sót hành động cần truy vết. | PAT-A12, PAT-C10 |
| Positive | HAProxy + Keepalived, 3 nhóm control-plane component, Calico, Multus/Whereabouts, Kyverno, etcd jobs, cert exporter và Fluent Bit đã có luồng cài/check tương ứng. | PAT-A05-A15, PAT-B01-B04, PAT-C02, PAT-D05-D09 |

## 7. Phân lớp chạy đề xuất

1. `pat_preflight`: PAT-A01 đến PAT-A16, PAT-C01, PAT-C03, PAT-C05,
   PAT-C06, PAT-C08, PAT-C09. Chỉ đọc, chạy trước mọi đợt nghiệm thu.
2. `pat_production`: PAT-P01 đến PAT-P22. Mặc định chỉ bật các case `PROD-RO`;
   `PROD-SYN` yêu cầu namespace/quota riêng, QPS guardrail và cleanup.
3. `pat_smoke`: PAT-B01 đến PAT-B13, PAT-C02, PAT-C04, PAT-C10. Tạo tài
   nguyên trong namespace PAT và tự cleanup.
4. `pat_security_external`: PAT-B15, PAT-C07 và PAT-F01 đến PAT-F05.
5. `pat_resilience`: PAT-D01 đến PAT-D11; yêu cầu opt-in, maintenance window
   và health gate trước/sau từng case.
6. `pat_dr_lab`: PAT-D12 đến PAT-D15, chỉ chạy trên lab/clone.
7. `pat_performance`: PAT-E01 đến PAT-E05; chạy riêng để tránh nhiễu với chaos.

`k8s_checklist` hiện tại có thể tái sử dụng làm nền cho một phần
`pat_preflight`, nhưng chưa thay thế các synthetic test, policy rejection,
backup restore, HA failover, performance và soak trong tài liệu này.

### Health gate bắt buộc trước `PROD-SYN`

Chỉ bắt đầu một case production synthetic khi đồng thời thỏa mãn:

- API `/readyz` pass qua VIP và từng backend; etcd không alarm và đủ quorum.
- Tất cả node expected Ready, không node pressure; không có P0/P1 alert đang mở.
- Không có control-plane upgrade, node drain, CNI/storage maintenance hoặc
  production rollout đang chạy.
- Namespace PAT có ResourceQuota, LimitRange, NetworkPolicy và TTL/cleanup job.
- QPS, replica, log volume, PVC size và runtime của case không vượt guardrail
  được cấu hình.

Dừng ngay case và chạy cleanup nếu API xuất hiện 5xx, p99 vượt 2 lần baseline,
etcd đổi leader/alarm bất thường, node xuất hiện pressure, hoặc một production
workload mất Ready ngoài error budget.

### Lịch chạy production đề xuất

| Chu kỳ | Case |
|---|---|
| Mỗi ngày | PAT-P01-P04, PAT-P08-P14, PAT-P19, PAT-P21-P22 ở chế độ read-only |
| Mỗi tuần | PAT-P06-P07, PAT-P10-P13, PAT-P17, PAT-P20 với synthetic load nhỏ |
| Trước/sau thay đổi | Toàn bộ PAT-P01-P22 và các case chức năng liên quan component thay đổi |
| Hàng tháng | PAT-P15-P16, PAT-P18; đối chiếu drift, rollback, storage và north-south route |
| Hàng quý tại lab | PAT-D03-D15, gồm restore, certificate renewal và upgrade rehearsal |
