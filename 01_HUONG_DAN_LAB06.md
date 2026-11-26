# NT547 – BÀI THỰC HÀNH 06: SECURITY AUTOMATION & CI/CD

> NT547 – Blockchain: Nền tảng, ứng dụng và bảo mật | 2026
> Tài liệu thực hành độc lập • Solidity 0.8.24 • Slither 0.11.6 • GitHub Actions

## Kết quả cần đạt

Sinh viên tạo hợp đồng cá nhân theo MSSV, chạy kiểm thử phân tích tĩnh, phân loại finding theo ngữ cảnh, sửa mã, đọc đồ thị kế thừa và thiết lập quality gate **RED → GREEN → RED → GREEN** trên GitHub.

| Nội dung | Kết quả nộp | Điểm |
|---|---|---|
| 1. Quét | Slither JSON + CSV + mô tả 3 detector | 2,0 |
| 2. Triage / Fix | Bảng TP/accepted + diff + scan sau sửa | 2,5 |
| 3. Printers | Human summary + inheritance graph | 1,5 |
| 4. CI Red/Green | 2 GitHub run URL + 2 commit SHA | 2,5 |
| 5. Mutation | Đổi 1 dòng → RED → revert GREEN | 1,5 |

Thời lượng đề xuất: 1 buổi 150–180 phút, hoặc làm tiếp tại nhà.

**THỨ TỰ BẮT BUỘC:** Cài → tạo target → scan before → commit/push CI RED → sửa/triage → scan after → commit/push CI GREEN → printers → mutation CI RED → revert CI GREEN → nộp.
Đặc biệt: phải làm RED baseline ở mục 7.1 **TRƯỚC** khi sửa theo mục 5.

## Quy tắc an toàn và minh chứng

- Tuyệt đối không triển khai hợp đồng cố ý có lỗi lên mainnet/testnet có giá trị; chỉ phân tích nguồn cục bộ.
- Không sử dụng seed phrase, private key, mật khẩu hoặc token GitHub trong mã, ảnh chụp và báo cáo.
- Chụp ảnh terminal/Actions nguyên ngữ cảnh có lệnh chạy, lỗi/cảnh báo, commit SHA hoặc run URL; không cắt chỉ con số.
- Mỗi SV tự sinh Session Code `SC-XXXXXX`; đây là mã đánh dấu artefact, không phải mã bí mật bảo mật.

---

## 1. Kiểm tra bộ file trước khi chạy

Giải nén `Lab06_SinhVien.zip`. Mọi lệnh trong tài liệu chạy từ thư mục `01_SINH_VIEN`. Nếu thấy thông báo "cannot find tools/…", em đang đứng sai thư mục.

| Tệp/thư mục | Công dụng |
|---|---|
| `README_BAT_DAU.md` | Bản tóm tắt thao tác và lệnh cần chạy |
| `tools/create_lab.py` | Tạo `AuditTarget.sol` và `lab_identity.json` |
| `tools/scan.py` | Quét, lưu stdout/JSON/CSV và số lượng finding |
| `tools/print_arch.py` | Tạo báo cáo kiến trúc và inheritance graph |
| `contracts/ArchitectureDemo.sol` | Mẫu 3 contract đủ để chạy printers độc lập |
| `slither.config.json` / `config/slither.raw.json` | Bản lọc cảnh báo và bản không lọc |
| `.github/workflows/slither.yml` | GitHub Actions chạy Slither và đặt ngưỡng Medium |
| `report/MAU_BAO_CAO.md` | Biểu mẫu nộp kết quả từng nhiệm vụ |

## 2. Chuẩn bị môi trường

### 2.1. Yêu cầu

Python 3.11/3.12, git, Graphviz (lệnh `dot`), Slither 0.11.6 và compiler solc 0.8.24. Cần tài khoản GitHub để push. Không dùng Remix, ví MetaMask hay node blockchain.

### 2.2. Windows 10/11

Khuyến nghị WSL2 Ubuntu để bảo đảm `solc-select` chạy đúng. Mở PowerShell bằng quyền Administrator để cài WSL2 (nếu chưa có), sau đó khởi động lại khi Windows yêu cầu:

```powershell
wsl --install -d Ubuntu
```

Mở Ubuntu từ Start menu, tạo username/password Linux, sau đó làm đúng các lệnh ở mục 2.3 trong terminal Ubuntu (thư mục Windows có thể truy cập tại `/mnt/c/...`). Không nhập lệnh `source` của Linux vào PowerShell.

### 2.3. Ubuntu / WSL2 Ubuntu / macOS / Linux

Ubuntu/WSL2 cài các gói nền:

```bash
sudo apt update && sudo apt install -y python3 python3-venv python3-pip git graphviz
```

macOS có thể dùng Homebrew để cài git, graphviz và python@3.11 nếu máy chưa có. Sau đó mở terminal, `cd` đến thư mục bài thực hành và chạy:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
solc-select install 0.8.24
solc-select use 0.8.24
solc --version
slither --version
python tools/preflight.py
```

Kết quả cần thấy: solc 0.8.24; Slither 0.11.6; git, dot được tìm thấy. Nếu pip lỗi mạng, chạy lại khi kết nối Internet; nếu solc không tìm thấy, tắt/mở terminal và kích hoạt lại `.venv`.

## 3. Tạo mục tiêu cá nhân theo MSSV

Thay `23520104` bằng MSSV. Không nhập MSSV của người khác:

```bash
python tools/create_lab.py 23520104
```

Script tạo `AuditTarget.sol` và `lab_identity.json` (MSSV, mã phiên SC-XXXXXX, tên contract, hash SHA256 của baseline). Generator dùng MSSV làm seed để chọn **4 lỗi tiềm ẩn + 2 đoạn cần đánh giá theo ngữ cảnh**. Không phải mọi đoạn đều chắc chắn được Slither in thành finding. Nhớ copy Session Code vào báo cáo.

> **CẢNH BÁO:** Không dùng `--force` để sinh lại sau khi đã sửa, vì sẽ ghi đè toàn bộ thay đổi. Đây là một bài phân tích tĩnh: không cần deploy hay gửi ETH.

### Cách đọc 1 finding

| Thuật ngữ | Hiểu như thế nào |
|---|---|
| Detector / check | Tên quy tắc kiểm tra, VD: `tx-origin` |
| Impact | Mức hậu quả chuẩn hoá của tool: High / Medium / Low / Informational |
| Confidence | Độ tin cậy phát hiện theo cơ chế rule, không phải xác suất khai thác |
| Location | File, dòng, hàm hoặc biến liên quan |
| True positive (TP) | Có vấn đề thật trong phạm vi contract; cần sửa hoặc giải thích ràng buộc |
| Accepted / contextual | Cảnh báo không gây nguy cơ tương ứng trong ngữ cảnh đã chứng minh |

---

## 4. Nhiệm vụ 1: Quét Slither & lấy JSON (2,0 điểm)

Chạy lần 1 KHÔNG LỌC để có baseline thực, rồi chạy lần 2 dùng config để quan sát khác biệt:

```bash
python tools/scan.py --mode raw --tag before
python tools/scan.py --mode configured --tag before
```

Mỗi thư mục `evidence/before_raw/` hoặc `evidence/before_configured/` có 4 file: `slither.json`, `findings.csv`, `summary.json` và `command_and_output.txt`. Lệnh scan dùng `--fail-none` để lưu kết quả ngay cả khi hợp đồng có vấn đề: exit code 0 ở bước này **KHÔNG** có nghĩa contract an toàn.

1. Mở `before_raw/summary.json`, ghi số High / Medium / Low / Informational (nếu có Optimization thì ghi riêng); không tự suy luận tổng số từ tên file.
2. Mở `findings.csv`, chọn ít nhất 3 detector khác nhau xuất hiện trong kết quả; chỉ rõ `file:hàm:dòng` và confidence. Nếu thực tế ít hơn 3, báo cáo chính xác detector có được, giải thích theo output thay vì bịa thêm.
3. Viết 1 câu "đầu vào/điều kiện → đoạn xử lý → hậu quả" cho mỗi finding; ví dụ khái niệm: Caller → check sai danh tính → thao tác bị cho phép. Không chép lại nguyên mô tả tool.

Nếu `slither.json` không được sinh ra, đọc `command_and_output.txt`. Thường do thiếu solc, version khác pragma, hoặc pip chưa cài đúng môi trường.

## 5. Nhiệm vụ 2: Triage, sửa & quét lại (2,5 điểm)

Không dùng Slither như một "máy phán quyết". Phân tích điều kiện đường gọi và tác động thật; phân loại từng finding thành **TP** hoặc **accepted** có dẫn chứng. Một tình huống có thể bị báo High nhưng không khai thác được ở đường gọi hiện tại (ngữ cảnh, mutex, chỉ trả dữ liệu view).

**YÊU CẦU BỔ SUNG:** Đọc cả source để xác định 4 mẫu có lỗi theo thiết kế và 2 đoạn cần triage theo ngữ cảnh. Mẫu nào Slither không báo, ghi "Manual review / Not reported", không tự tạo finding giả trong JSON.

4. Với mỗi High/Medium trong `before_raw`, tìm hàm, đường gọi, yêu cầu quyền và cập nhật state. Ghi TP hoặc accepted cùng lý do cụ thể vào bảng mẫu.
5. Sửa toàn bộ TP trong phạm vi bài. Các kỹ thuật phổ biến: Checks-Effects-Interactions; `require` kiểm soát quyền bằng `msg.sender`; kiểm tra kết quả external call; kiểm soát địa chỉ đích, khởi tạo state; tránh sai số phép tính; dùng `abi.encode` thay cho `encodePacked` nếu hai trường biến độ dài.
6. Với accepted finding: ưu tiên thay đổi mã để tool không còn cảnh báo; nếu không cần sửa, chỉ dùng suppression theo detector + đúng vị trí khi có chứng minh đầy đủ trong báo cáo. Tuyệt đối không bật `exclude_high`, `exclude_medium` hoặc tắt cả detector thiếu lý do.
7. Chạy lại 2 chế độ, ghi bảng before/after, dùng `git diff` hoặc so sánh file để minh hoạ thay đổi.

```bash
python tools/scan.py --mode raw --tag after
python tools/scan.py --mode configured --tag after
git diff -- AuditTarget.sol
```

Ví dụ suppression có kiểm soát: đặt `// slither-disable-next-line weak-prng` ngay trước biểu thức bị báo, và nêu rõ hàm chỉ dùng timestamp để HIỂN THỊ, không làm nguồn ngẫu nhiên cấp quyền/tiền. Không dùng suppression cho lỗi đang khai thác được. Nếu GitHub CI vẫn RED, đọc detector và làm rõ mã, không bỏ qua bằng cách loại cả severity.

**Lưu ý `selfdestruct`:** từ Cancun/EIP-6780, trong trường hợp thông thường opcode chuyển toàn bộ ETH chứ không tự động xoá code/storage; vì vậy giải thích tác hại cần đúng mạng/EVM, không chỉ viết "xoá hợp đồng".

## 6. Nhiệm vụ 3: Printers & inheritance graph (1,5 điểm)

Không cần dùng LabNFT/StudentToken từ lab cũ: đã kèm sẵn `contracts/ArchitectureDemo.sol` có 3 lớp: `AccessManaged` (quyền), `BalanceLedger` (số dư), `StudentAsset` (entrypoint).

```bash
python tools/print_arch.py
```

Mở `evidence/architecture/human_summary.txt`, `inheritance.png` và `.dot`. Nếu không có PNG, xác nhận `dot -V` và chạy lại. Có thể render bằng:

```bash
dot -Tpng evidence/architecture/ArchitectureDemo.sol.dot -o evidence/architecture/inheritance.png
```

8. Chỉ ra contract quản lý quyền, contract quản lý mapping số dư và contract được gọi từ bên ngoài; đánh dấu node tương ứng trong ảnh.
9. Viết 3–5 câu: logic security-critical có thể nằm ở contract cha nào, hàm nào là entrypoint, nên audit bắt đầu từ đâu và tại sao.

## 7. Nhiệm vụ 4: GitHub Actions: RED → GREEN (2,5 điểm)

### 7.1. RED baseline

Thực hiện ngay SAU nhiệm vụ 1, TRƯỚC khi sửa `AuditTarget.sol`. Nếu đã sửa, lấy lại baseline từ git hoặc tạo thư mục làm lại; không push hợp đồng đã sửa để đòi trạng thái RED.

```bash
git init -b main
git add .
git commit -m "lab06: vulnerable baseline"
```

Trên GitHub, tạo một repository mới **RỖNG** (không tick "Add README/license/.gitignore" vì các file đã có). Copy URL HTTPS của repo rồi chạy (thay địa chỉ bằng URL thật; KHÔNG gõ dấu `< >`):

```bash
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```

Mở GitHub → repository → Actions → "Lab06 Slither gate" → run gần nhất. Kết quả RED hợp lệ **chỉ khi** log cho thấy Slither phát hiện severity Medium/High; lỗi `solc not found`, authentication, action timeout… KHÔNG tính RED hợp lệ. Lưu run URL và commit SHA.

### 7.2. GREEN sau khi fix

Sau khi hoàn thành nhiệm vụ 2, bảo đảm GitHub nhìn thấy bản `AuditTarget.sol` đã sửa. Workflow có `fail-on: medium`: mọi High và Medium không được chấp nhận/sửa đúng vẫn có thể làm job fail.

```bash
git add .
git commit -m "lab06: fix and triage findings"
git push
```

Mở run mới, xác nhận GREEN. Nếu RED, mở step Slither, xác định lỗi compiler/action hay finding. Không chỉnh workflow để `fail-on: none` hay loại Medium/High. Ghi URL và SHA thứ hai. Lệnh `--fail-none` ở local chỉ giúp thu evidence, khác hoàn toàn với ngưỡng fail của CI.

## 8. Nhiệm vụ 5: Mutation tự phục vụ (1,5 điểm)

Không cần mã do GV công bố. Khi pipeline đã GREEN, mở `AuditTarget.sol`, tìm `modifier onlyOwner()` và sửa **DUY NHẤT một dòng** bảo vệ quyền:

```solidity
// TRƯỚC (an toàn):
require(msg.sender == owner, "not owner");
// SAU (cố ý tạo lỗi):
require(tx.origin == owner, "not owner");
```

Giữ nguyên các dòng khác. `tx.origin` có thể bị lợi dụng khi chủ sở hữu bị dụ gọi qua hợp đồng trung gian; Slither dự kiến báo `tx-origin` mức Medium. CI vì vậy phải RED ở ngưỡng Medium.

```bash
git add AuditTarget.sol
git commit -m "lab06: one-line mutation tx-origin"
git push
```

Lưu URL / SHA run RED và tên detector. Sau đó hồi phục đúng mutation bằng commit mới:

```bash
git revert --no-edit HEAD
git push
```

Run cuối phải GREEN. Ghi đủ 4 trạng thái: **baseline RED → fix GREEN → mutation RED → revert GREEN**, 4 commit SHA và 4 URL. Nếu `git revert` báo conflict, vì HEAD không còn là mutation commit: xem `git log --oneline` rồi revert đúng commit.

## 9. Nộp bài & rubric (10 điểm)

Điền `report/MAU_BAO_CAO.md` (hoặc chuyển PDF theo LMS). Sau khi đủ evidence, chạy:

```bash
python tools/package_submission.py
```

để tạo `submissions/NT547_Lab06_<MSSV>.zip`. Nộp ZIP cùng URL repo, bốn URL Actions run và commit SHA. Script chỉ kiểm tra evidence có tồn tại, không thay thế việc kiểm tra nội dung báo cáo. **KHÔNG** nộp teacher answer hoặc file chứa đáp án.

| Điểm thành phần | Nội dung kiểm tra | Điểm |
|---|---|---|
| N1 | Môi trường/scan (0,4); JSON+CSV (0,5); 3 detector (0,5); data-flow (0,6) | 2,0 |
| N2 | Triage (0,7); fix đúng (1,0); re-scan (0,4); lý luận risk (0,4) | 2,5 |
| N3 | Printers (0,5); graph (0,5); 3–5 câu phân tích (0,5) | 1,5 |
| N4 | RED baseline (0,8); GREEN fixed (1,0); URL/SHA (0,4); giải thích (0,3) | 2,5 |
| N5 | Đổi đúng 1 dòng (0,5); RED tx-origin (0,5); revert GREEN (0,5) | 1,5 |
| **TỔNG** | | **10,0** |

### Checklist trước khi nộp

- [ ] Đã chạy `create_lab.py` đúng MSSV và ghi mã phiên từ `lab_identity.json`.
- [ ] Có `before_raw`, `before_configured`, `after_raw`, `after_configured` với JSON/CSV/summary/log.
- [ ] Có 3 detector khác nhau hoặc đã giải thích vì sao analyzer chỉ xuất ra ít hơn.
- [ ] Bảng triage ghi bằng chứng và lý do cho mọi Medium/High được xử lý.
- [ ] Có human-summary, DOT và PNG của inheritance (nếu Graphviz được cài).
- [ ] Có link repo, 4 run URL và 4 SHA theo thứ tự R-G-R-G.
- [ ] Đã revert mutation, branch `main` ở trạng thái GREEN.
- [ ] Không có dữ liệu nhạy cảm hoặc đáp án GV trong repo.

## 10. Lỗi thường gặp (tự xử lý)

| Triệu chứng | Cách xử lý ngay |
|---|---|
| `python: command not found` | Dùng `python3`; kiểm tra `.venv` đã active và đang ở đúng thư mục. |
| `solc not found` / wrong version | `solc-select install 0.8.24; solc-select use 0.8.24; solc --version`. |
| Windows: `solc-select` không chạy | Chuyển WSL2 Ubuntu; thực hiện lệnh Linux trong Ubuntu, không phải PowerShell. |
| `slither.json` không xuất hiện | Mở `evidence/<tag>_<mode>/command_and_output.txt` để đọc nguyên nhân, kiểm tra phiên bản. |
| Không có PNG inheritance | `sudo apt install graphviz; dot -V;` chạy lại `tools/print_arch.py`. |
| Actions đỏ vì setup/network | Không tính là RED; đọc lỗi cụ thể, fix môi trường, rerun workflow. |
| CI không GREEN sau sửa | Đọc detector Medium/High, sửa mã hoặc documented accepted với suppression đúng dòng. |
| GitHub không push được | GitHub không nhận mật khẩu account thông thường qua HTTPS: dùng credential manager/PAT hoặc SSH. |
| Lỡ chạy generator lại | Đọc `git log`/`reflog` để phục hồi, không ghi đè tiếp; nếu chưa commit, phải tạo lại/sửa thủ công. |
| Không đủ 3 detector | Báo cáo số liệu thực, có ảnh+JSON chứng minh; không tự tạo findings. |

## Tài liệu chính thức và phạm vi bài

- Slither: https://github.com/crytic/slither (hướng dẫn, detector, printers)
- GitHub Action: https://github.com/crytic/slither-action (v0.4.2, `fail-on`)
- GitHub Actions: https://docs.github.com/en/actions
- Solidity 0.8.24: https://docs.soliditylang.org
- EIP-6780: https://eips.ethereum.org/EIPS/eip-6780

> Lưu ý: Kết quả detector thay đổi theo phiên bản tool, cấu hình và data/control flow. Tài liệu này không coi số lượng finding cố định là đáp án chuẩn; kết quả từ máy sinh viên + bằng chứng code là cơ sở chấm.
