# CallForward 1.0.0

Tweak chuyển hướng cuộc gọi **theo từng số gọi** cho iPhone 2 SIM (package `com.anhdang.callforward`).

## Ý tưởng (đã chốt với anh Quoc)

- Có một số hay nhá máy / làm phiền (gọi là số X). Anh **gán** cho số X một số đích.
- Lần sau X gọi vào: cuộc gọi **chuyển qua số đích trước** — máy đích reo, nghe bình thường; nếu máy đích đang bận thì bên X nghe bận của máy đích.
- Nếu **chuyển hỏng** (nhà mạng không chạy được) thì **máy anh báo bận cho X**, không reo chuông làm phiền anh.
- Người **không** nằm trong danh sách gán gọi vào vẫn reo bình thường. Không chuyển cả SIM.

## Cách gán luật

1. Mở app Điện thoại → tab **Gần đây**.
2. **Vuốt sang phải** trên dòng số đó → **Chuyen huong**, hoặc chạm chữ **(i)** của số đó.
3. Bảng "Chuyen huong cuoc goi" hiện: nhập **số đích** → chọn **Lưu — áp cho SIM chính** hoặc **SIM phụ**.
4. Muốn nhà mạng chuyển thật, quay mã `**67*<số đích>#` **bằng đúng line SIM đó** rồi bấm Gọi (bảng gán có nút "Quay ma ngay", hoặc vào Cài đặt → CallForward để quay). Mỗi SIM chỉ chứa 1 số đích cho mã 67 tại một thời điểm.
5. Đường dự phòng: Cài đặt → CallForward → **Thêm luật thủ công** (nhập số gọi + số đích), xem/xoá luật cũng tại đó.

## Cơ chế

- Nhà mạng không có chuyển-hướng-theo-từng-người-gọi. Tweak dùng đường vòng: set sẵn mã **chuyển khi bận** (`**67*`) cho SIM + tự cho cuộc gọi của số đã gán "bận" ngay khi nó gọi tới → nhà mạng đẩy cuộc gọi sang số đích. Nếu nhà mạng không đẩy, bên gọi nhận tín hiệu bận tại máy này — đúng luật dự phòng đã chốt.
- Nhận diện số gọi + cắt cuộc gọi qua TelephonyUtilities (TUCallCenter/TUCall, gọi bằng runtime) trong SpringBoard/InCallService, dự phòng CallKit CXCallController. Mọi bước đều ghi log.

## Kiểm tra sau khi cài (gửi lại file log cho em)

1. Cài .deb xong **respring** rồi mở Điện thoại 1 lần, gọi thử vào SIM chính từ số chưa gán → phải reo bình thường.
2. Gán luật cho số máy phụ đang cầm (số gọi = số máy phụ, số đích = một số khác), set mã `**67*` cho SIM chính bằng nút trong bảng gán.
3. Dùng máy phụ gọi vào SIM chính → kỳ vọng: máy chính không reo, máy đích reo. Máy đích đang nghe cuộc khác → máy phụ nghe bận.
4. Tắt mã 67 (quay `##67#`) rồi gọi lại → kỳ vọng: máy phụ nghe bận, máy chính không reo (lớp dự phòng).
5. Gửi em file `/var/mobile/Documents/CallForward.log` — trong đó phải có dòng `KHOP LUAT:` và dòng `cat cuoc:` cho lần gọi test.

## Giới hạn đã biết (bản 1.0.0 là bản dò + thử)

- Việc nhà mạng có kích hoạt chuyển khi "từ chối = bận" hay không tuỳ nhà mạng của SIM; lớp bận-tại-máy không phụ thuộc nhà mạng.
- Số gọi ẩn số (không hiện số) thì không khớp luật được.
- Nếu nhiều luật dùng **số đích khác nhau trên cùng 1 SIM**, chỉ số đích đang set trong mã 67 của SIM đó mới chuyển thật được; các luật còn lại rơi xuống lớp báo bận.
- Bản này **chưa được build Theos / test trên máy thật** — mới kiểm tra tĩnh. Log trên máy anh quyết định vòng sửa tiếp theo.

## Build

Đẩy cả cây lên repo, file workflow nằm sẵn ở `.github/workflows/build.yml` (bản rời `build-callforward-1.0.0.yml` giao kèm là cùng một nội dung) → commit mới → Actions build 3 scheme: rootful / rootless / roothide.
