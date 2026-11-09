# HB Cheat — mod menu cho Arena of Valor (iOS)

Thương hiệu: **HB**. Giao diện tự thiết kế (không dùng layout của TUMADAM).

## Cách bật/tắt menu
- **Gõ 2 ngón tay** vào bất kỳ đâu trên màn hình → ẩn/hiện menu.
- Hoặc bấm nút tròn **HB** nổi trên màn hình (kéo để di chuyển).

## Giao diện (v2 — ngang, 2 cột)
- Thẻ **ngang rộng** (chơi game xoay ngang), chia **2 cột**: trái là BẢN ĐỒ +
  NGẮM (AIMBOT), phải là SKIN + TỰ ĐỘNG + HIỆU NĂNG.
- Header: logo HB + "HB Cheat" + v1.0, nút **HIDE HACK: OFF**, chọn **FPS
  30/60/90/120**, nút đóng.
- Mỗi chức năng là một dòng có **icon SF Symbol** (bản đồ, mắt, camera,
  tâm ngắm, sao, refresh, sét), tiêu đề + mô tả, công tắc bật/tắt bên phải.
- Nền xanh navy tối, điểm nhấn cyan. Cài đặt được lưu lại.

## Cách build (không cần Mac)
1. Tạo repo GitHub mới, đẩy toàn bộ thư mục này lên nhánh `main`.
2. Vào tab **Actions** → chạy workflow **Build HBMenu.dylib** (hoặc nó tự chạy khi push).
3. Tải file `HBMenu.dylib` trong mục Artifacts.

## Cách chèn vào IPA gốc (cần máy tính)
1. Dùng **lcsign** (hoặc Azule/E-Sign trên iPhone) chèn `HBMenu.dylib`
   vào IPA gốc đã giải mã của Liên Quân (`com.tumadam.aovz`, v1.64.1).
2. Ký lại IPA và sideload bằng AltStore / SideStore / ESign.
3. Mở game → nút **HB** nổi lên, gõ 2 ngón để mở menu.

## Trạng thái các chức năng
- **FPS unlock**: đã làm xong (dùng Unity `UnitySetTargetFrameRate`).
- **Hack Map / Unlock Skin / Cam Xa**: đã làm bằng **runtime resolution** —
  dylib tự tìm hàm trong game lúc chạy bằng tên class/method (IL2CPP API
  `il2cpp_class_from_name` + `il2cpp_class_get_method_from_name`), rồi thay
  `methodPointer` bằng hàm của mình. Không dùng địa chỉ cứng nên không sợ
  game update đổi địa chỉ. Các tên hàm đã xác nhận có trong metadata của
  game (xem `hb-mod/RE_FINDINGS.md`):
  - Hack Map: `NucleusDrive.Logic.HorizonMarker::IsVisibleForEnermyCamp`
    (ép trả về true → hiện hết địch).
  - Unlock Skin: `GameSystem.CDimensionSystem::IsOwnDimensionByUnitID`
    (ép trả về true → mở skin; lưu ý skin còn bị server kiểm tra, có thể
    bị văng lúc kết trận như menu TUMADAM đã cảnh báo).
  - Cam Xa: `set_currentZoomAmount` (ép giá trị zoom).
- **Aimbot / Auto**: đã xác định được điểm móc (hàm gửi skill
  `SendRequestUseSkillTarget/Dir/Pos`), phần ngắm vào tướng địch đang
  hoàn thiện (cần đọc vị trí tướng qua `GetTargetPosition`).
- **Fake Name**: chưa tìm ra hàm lấy tên người chơi, đang để trống.
- **Vì sao không dùng Il2CppDumper**: game dùng metadata IL2CPP tùy biến
  của Tencent (magic `0xeab11baf`, header không chuẩn) nên Il2CppDumper
  không đọc được — đã thử, kể cả sửa magic vẫn lỗi `EndOfStreamException`.
  Vì vậy dùng runtime resolution thay vì địa chỉ tĩnh.

## Cấu trúc
- `HBMenu/HBMenu.h` + `HBMenu.m` — giao diện menu + gõ 2 ngón + nút HB nổi.
- `HBMenu/HBHooks.h` + `HBHooks.m` — các hook vào game.
- `.github/workflows/build.yml` — build dylib trên GitHub Actions (macOS runner).
