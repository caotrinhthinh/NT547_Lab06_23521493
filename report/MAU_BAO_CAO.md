# NT547 - LAB 06 - BÁO CÁO (TỰ ĐIỀN)

**MSSV:** 23521493  | **Họ tên:** Cao Trịnh Thịnh | **Lớp:** NT547
**Session code tự sinh:** SC-2B43EC | **Tên contract:** CrowdFund_1493
**Solidity / Slither:** 0.8.24 / 0.11.6 | **Ngày hoàn thành:** 26/11/2026
**URL GitHub repository:** https://github.com/caotrinhthinh/NT547_Lab06_23521493

## 1. Static scan (2,0 điểm)

- Lệnh raw: `python tools/scan.py --mode raw --tag before`
- Số lượng finding raw từ `evidence/before_raw/summary.json`:
  - High: 4; Medium: 2; Low: 0; Informational: 4; Optimization: 0
- Chạy configured: `python tools/scan.py --mode configured --tag before`
- So sánh raw/configured: Bản raw xuất hiện đầy đủ 10 issues (bao gồm 4 Informational là `low-level-calls` và `naming-convention`). Bản configured kích hoạt bộ lọc trong `slither.config.json` giúp ẩn các cảnh báo Informational nhiễu, nhưng giữ nguyên toàn bộ 4 lỗi High và 2 lỗi Medium, không làm biến mất hay che giấu các lỗ hổng nghiêm trọng.
- 3 detector **khác tên**: `suicidal`, `reentrancy-eth`, `tx-origin`

| ID finding | Detector | Impact | Confidence | Source (file:dòng) | Luồng dữ liệu: đầu vào -> thao tác -> tác hại |
|---|---|---|---|---|---|
| F01 | `suicidal` | High | High | AuditTarget.sol:78-80 | Caller bất kỳ -> Gọi hàm `closeVault()` không có access control -> Thực thi `selfdestruct(payable(msg.sender))` -> Chiếm đoạt toàn bộ ETH trong hợp đồng |
| F02 | `reentrancy-eth` | High | Medium | AuditTarget.sol:71-76 | User gọi `withdrawSafe()` -> Thực hiện external call `.call{value: a}("")` trước khi cập nhật `safeBalances[msg.sender] = 0` -> Attacker lợi dụng fallback re-enter rút cạn quỹ |
| F03 | `tx-origin` | Medium | Medium | AuditTarget.sol:57-61 | Owner bị lừa gọi contract độc hại -> Contract độc hại gọi `setAdmin(attacker)` -> `tx.origin == owner` thỏa mãn -> Attacker chiếm đoạt quyền quản trị contract |

## 2. Triage và sửa lỗi (2,5 điểm)

Đọc toàn bộ AuditTarget.sol: nhận diện **4 mẫu lỗi thật + 2 đoạn cần đánh giá ngữ cảnh**,
kể cả khi Slither không hiển thị đủ 6 cảnh báo. Với mẫu không có detector,
ghi “Manual review / Not reported”, KHÔNG sửa slither.json hoặc tạo finding giả.

| Detector + vị trí | TP / FP / Chưa kết luận | Bằng chứng kiểm soát/khả năng khai thác | Biện pháp (Fix / Accept có lý do) | Sau sửa |
|---|---|---|---|---|
| `suicidal` (closeVault, L78-80) | TP | Hàm public không có modifier kiểm tra quyền, bất kỳ ai cũng có thể gọi để kích hoạt selfdestruct và rút cạn quỹ. | Fix: Thêm modifier `onlyOwner`, thay thế `selfdestruct` bằng lệnh chuyển tiền an toàn cho `owner`. | Resolved (0) |
| `reentrancy-eth` (withdrawSafe, L71-76) | TP | Ghi state `safeBalances[msg.sender] = 0` nằm sau lệnh gọi ngoài `.call`. Vi phạm nghiêm trọng mô hình Checks-Effects-Interactions (CEI). | Fix: Áp dụng CEI, gán `safeBalances[msg.sender] = 0` trước khi thực hiện low-level call chuyển ETH. | Resolved (0) |
| `unchecked-transfer` (redeemPoints, L51-55) | TP | Bỏ qua giá trị trả về của `usdt.transfer` và không kiểm tra `usdt != address(0)`. Nếu token trả về false thay vì revert, trạng thái bị sai lệch. | Fix: Kiểm tra token khác 0, hứng biến bool kết quả `ok` và `require(ok, "transfer failed")`. | Resolved (0) |
| `tx-origin` (setAdmin, L57-61) | TP | Dùng `tx.origin` để cấp quyền thay đổi admin, dễ bị tấn công qua phishing contract trung gian. | Fix: Đổi sang kiểm tra người gọi trực tiếp `require(msg.sender == owner, "not owner")`. | Resolved (0) |
| `unchecked-lowlevel` (rescueEth, L82-85) | TP | Bỏ qua kết quả trả về của `to.call{value: ...}("")`, dẫn đến giao dịch không revert nếu chuyển tiền thất bại. | Fix: Kiểm tra `(bool ok, ) = ...` và `require(ok, "rescue failed")`. | Resolved (0) |
| `weak-prng` (dayOfWeek, L63-65) | Accepted (Contextual) | Hàm `view` dùng timestamp thuần túy để tính thứ trong tuần cho hiển thị, không dùng làm nguồn ngẫu nhiên cấp quyền hay phân phối tài sản. | Accept có lý do: Giữ nguyên logic hiển thị và thêm suppression inline `// slither-disable-next-line weak-prng`. | Suppressed (0) |

- Mô tả ít nhất 01 kịch bản khai thác TP: Kẻ tấn công gọi trực tiếp hàm `closeVault()` trên contract `CrowdFund_1493`. Do hàm hoàn toàn không có ràng buộc kiểm tra danh tính người gọi, opcode `selfdestruct(payable(msg.sender))` lập tức được thực thi, chuyển toàn bộ số dư ETH lưu trữ trong hợp đồng về địa chỉ ví của kẻ tấn công, khiến người dùng gửi tiền bị mất trắng tài sản.
- Phân tích 01 finding có severity cao nhưng risk thực tế không tương ứng: Cảnh báo `weak-prng` (High) tại hàm `dayOfWeek()`. Slither đánh dấu High do phát hiện toán tử modulo trên `block.timestamp`. Trong các hợp đồng xổ số hay game, việc này cho phép miner gian lận kết quả ngẫu nhiên. Tuy nhiên trong ngữ cảnh của `CrowdFund_1493`, hàm `dayOfWeek()` chỉ là hàm view dùng để chuyển đổi mốc thời gian sang thứ trong tuần (0-6) cho mục đích đọc dữ liệu, hoàn toàn không ảnh hưởng tới logic tài chính hay phân quyền, do đó rủi ro thực tế bằng 0.
- Dẫn bằng chứng `git diff`, scan before/after và giải thích cảnh báo còn lại: `git diff -- AuditTarget.sol` chứng minh toàn bộ các điểm vi phạm CEI, access control và unchecked call đã được xử lý chuẩn mực. Kết quả `after_configured` đưa toàn bộ High/Medium về 0 (đạt chuẩn CI Green). Cảnh báo Low còn lại ở raw là `events-access` (khuyên emit event khi đổi owner) không gây lỗi bảo mật.
- Lý do của mọi `slither-disable-next-line`: Đặt `// slither-disable-next-line weak-prng` ngay phía trước hàm `dayOfWeek()`. Lý do: Hàm chỉ đọc `block.timestamp` để chia lấy dư tính thứ trong tuần, không dùng làm nguồn sinh ngẫu nhiên cho bất kỳ hoạt động cấp tiền hay bảo mật nào.

## 3. Kiến trúc / Inheritance (1,5 điểm)

- Lệnh printer đã chạy: `python tools/print_arch.py`
- Ảnh `evidence/architecture/inheritance.png` (hoặc .dot, nếu Graphviz chưa có): Đã lưu `evidence/architecture/ArchitectureDemo.sol.dot` và `evidence/architecture/human_summary.txt`.
- Access control nằm ở `AccessManaged` (quản lý biến `admin` và modifier `onlyAdmin`); logic số dư nằm ở `BalanceLedger` (quản lý mapping nội bộ `balances` và hàm `_credit`); contract triển khai nằm ở `StudentAsset` (kế thừa cả hai lớp trên và đóng vai trò entrypoint cho người dùng).
- Giải thích 3–5 câu điểm audit cần bắt đầu: Quá trình audit phải bắt đầu từ các hợp đồng cơ sở cấp thấp là `AccessManaged` và `BalanceLedger` trước khi đánh giá `StudentAsset`. Lý do là vì logic bảo mật cốt lõi (kiểm tra phân quyền trong modifier `onlyAdmin` và logic cập nhật biến trạng thái `balances`) đều nằm tại hai hợp đồng cha này. Nếu nền tảng phân quyền hoặc sổ cái cơ sở có sơ hở, mọi hàm nghiệp vụ ở lớp con kế thừa đều sẽ bị xâm phạm. Sau khi đảm bảo các contract cha an toàn, việc audit entrypoint `StudentAsset` sẽ tập trung vào việc xác nhận hàm `mint` có gọi đúng các modifier và hàm internal theo chuẩn CEI hay không.

## 4. Red -> Green CI (2,5 điểm)

| Phase | Commit (full/short SHA) | Run URL | Kết quả | Detector khiến RED / lý do GREEN |
|---|---|---|---|---|
| Baseline vulnerable | a208c0831d211044163741d9f8430472094dd3c3 | https://github.com/caotrinhthinh/NT547_Lab06_23521493/actions/runs/45840285851 | RED | Slither phát hiện 4 lỗi High (`suicidal`, `reentrancy-eth`, `unchecked-transfer`, `weak-prng`) và 2 lỗi Medium (`tx-origin`, `unchecked-lowlevel`), vượt ngưỡng `fail-on: medium`. |
| Patched | cfda25566a755a49bd081374641f777d2be24026 | https://github.com/caotrinhthinh/NT547_Lab06_23521493/actions/runs/45844941189 | GREEN | Toàn bộ 4 lỗi High và 2 lỗi Medium đã được khắc phục triệt để và triage đúng kỹ thuật, đưa số lỗi High/Medium về 0. |

- So sánh local `--fail-none` (thu thập findings) với CI `fail-on: medium`: Cờ `--fail-none` ở local luôn trả về exit code 0 để script thu thập đầy đủ báo cáo JSON/CSV phục vụ quá trình phân tích mà không làm gián đoạn pipeline. Ngược lại, trên CI thiết lập `fail-on: medium` đóng vai trò là một quality gate nghiêm ngặt: bất kỳ finding nào có mức độ Medium hoặc High xuất hiện sẽ lập tức đánh fail job (exit code khác 0), chặn đứng mã nguồn có lỗi được tích hợp vào nhánh chính.
- `exclude_low/informational` thay đổi kết quả hiển thị ra sao: Tùy chọn này loại bỏ các cảnh báo cấp thấp và thông tin (như chuẩn đặt tên, low-level call an toàn), giúp giảm thiểu tối đa nhiễu cảnh báo (alert fatigue), cho phép đội ngũ bảo mật và CI/CD tập trung xử lý các rủi ro bảo mật thực sự (High/Medium).

## 5. Mutation RED -> GREEN (1,5 điểm)

- Mutation một dòng: `require(msg.sender == owner, "not owner")` -> `require(tx.origin == owner, "not owner")` trong hàm xác thực quản trị.
- Detector kỳ vọng: `tx-origin` (mức Medium); xác nhận của em từ CI: Job Slither gate thất bại (exit code 1) do detector `tx-origin` phát hiện sử dụng `tx.origin` cho mục đích authorization.

| Phase | Commit SHA | Run URL | Kết quả |
|---|---|---|---|
| Mutation | cc8ecdfcd76bfb72d4c9c0ac1959c4b576e8f9cd | https://github.com/caotrinhthinh/NT547_Lab06_23521493/actions/runs/45848991446 | RED |
| Revert mutation | ea222fbabcb9538fbd8f5994f443dd9f1d18096a | https://github.com/caotrinhthinh/NT547_Lab06_23521493/actions/runs/45849628532 | GREEN |

- Giải thích sự thay đổi về nguồn định danh/authorization: Khi chuyển từ `msg.sender` sang `tx.origin`, cơ chế xác thực không còn kiểm tra đối tượng gọi trực tiếp hiện tại mà kiểm tra địa chỉ tài khoản EOA đầu tiên khởi tạo transaction. Nếu `owner` bị dẫn dụ tương tác với một smart contract trung gian độc hại, contract độc hại đó có thể gọi đến hàm được bảo vệ của `CrowdFund_1493`, và kiểm tra `tx.origin == owner` vẫn hợp lệ, dẫn đến lỗ hổng leo thang đặc quyền nghiêm trọng.

## 6. Bằng chứng, tự kiểm

- [x] `AuditTarget.sol`, `lab_identity.json`
- [x] `evidence/before_raw/` và `evidence/before_configured/`
- [x] `evidence/after_raw/` và `evidence/after_configured/`
- [x] `evidence/architecture/`
- [x] 04 URL Actions run RED/GREEN/RED/GREEN + 04 commit SHA
- [x] Link repo và ảnh màn hình có terminal / URL / commit SHA; không cắt mất ngữ cảnh
- [x] Các finding được triage, không chép lại mô tả detector thay cho suy luận
- [x] Tuyệt đối không có seed phrase, private key, credentials

**Nhận xét cuối cùng (5–7 câu):** 
Bài thực hành Lab 06 giúp sinh viên hiểu rõ tầm quan trọng của việc tích hợp công cụ phân tích tĩnh (Slither) vào quy trình CI/CD tự động bằng GitHub Actions. Thay vì coi công cụ bảo mật là quyết định tuyệt đối, sinh viên học được kỹ năng triage phân biệt giữa True Positive cần khắc phục ngay và các cảnh báo ngữ cảnh cần tài liệu hóa và suppression có kiểm soát. Việc thiết lập quality gate với ngưỡng `fail-on: medium` đảm bảo ngăn chặn triệt để các lỗ hổng nghiêm trọng được merge vào codebase. Thí nghiệm mutation test một dòng `tx.origin` đã minh chứng sinh động cho khả năng phát hiện hồi quy tự động của CI/CD. Toàn bộ quy trình từ baseline RED đến patched GREEN phản ánh chính xác chu trình DevSecOps thực tế trong phát triển ứng dụng blockchain.
