# Hướng dẫn chạy bản Portal 3105

Bản này mở màn giới thiệu, sau đó yêu cầu key. Khi key hợp lệ, app hiển thị các tiện ích, thông báo và thông tin tài khoản. Quản trị viên thêm liên kết chức năng trong trang web; app tải danh mục qua API và mở nội dung HTTPS bên trong app.

## 1. Chọn nơi chạy server

Đề xuất cho bản thử nghiệm: **Render** chạy API và trang quản trị, **Supabase** lưu Postgres. Đây là hai dịch vụ riêng; GitHub Actions chỉ biên dịch app iOS.

- Render miễn phí có thể ngủ sau 15 phút không có truy cập, và dữ liệu trên ổ đĩa cục bộ của dịch vụ miễn phí bị xóa khi khởi động lại. Vì vậy cấu hình này dùng Postgres bên ngoài, không lưu key trong tệp của server.
- Supabase miễn phí có thể tạm dừng project sau một tuần ít hoạt động. Phù hợp để thử trước; nếu cần hoạt động liên tục, dùng gói có trả phí hoặc host có database bền vững.

## 2. Tạo database và server

1. Tạo project Supabase, mở SQL Editor và chạy `server/schema.sql`.
2. Sao chép connection string Postgres trong phần kết nối database của Supabase.
3. Đẩy mã nguồn này lên fork GitHub của bạn. Trên Render, tạo Web Service từ fork và dùng `render.yaml` ở thư mục gốc.
4. Trong phần Environment của Render, đặt `DATABASE_URL`, `DATABASE_SSL=true`, `ADMIN_PASSWORD` và `TOKEN_SECRET`. Hai giá trị bí mật nên dài, ngẫu nhiên và không được commit vào GitHub.
5. Mở URL Render; `/health` xác nhận API hoạt động, `/` mở trang quản trị.
6. Trong `ThreeOneOSFive/ContentView.swift`, thay `https://YOUR-API-HOST` bằng URL HTTPS Render rồi đẩy thay đổi lên GitHub.

## 3. Tạo key và chức năng

1. Đăng nhập trang quản trị bằng `ADMIN_PASSWORD`.
2. Tạo key với ngày hết hạn và số thiết bị cho phép. Key đầy đủ chỉ hiện một lần; lưu lại để gửi cho người dùng.
3. Thêm chức năng bằng nhóm, tên, mô tả, biểu tượng SF Symbol và địa chỉ HTTPS. Chức năng sẽ xuất hiện trong tab **Tiện ích** của app.
4. Có thể ẩn/hiện hoặc xóa chức năng, đăng thông báo, thu hồi key và gỡ các thiết bị đã ghép với key.

## 4. Build trên GitHub

Workflow `.github/workflows/ios-build.yml` chạy khi có push lên nhánh `main` hoặc khi bấm **Run workflow** trong tab **Actions**. Kết quả nằm trong artifact `3105-ios-simulator` và chỉ chạy trên iOS Simulator. Artifact này không cài trực tiếp được lên iPhone; cài trên iPhone cần chứng chỉ và provisioning phù hợp.

## Bảo mật và dữ liệu

- Database chỉ lưu hash SHA-256 của key; key gốc chỉ hiện khi tạo.
- Giới hạn thiết bị được kiểm tra nguyên tử ở server. Mã thiết bị lấy từ `identifierForVendor` của iOS; khi Apple đặt lại mã này, quản trị viên có thể gỡ liên kết thiết bị trong trang web.
- Không đặt mật khẩu quản trị, token secret hoặc database URL trong app hay repo công khai.
- Bản gốc 3105 có giấy phép GPL-3.0 và thông báo thành phần bên thứ ba; giữ lại các tệp giấy phép và ghi công khi phân phối bản sửa đổi.

