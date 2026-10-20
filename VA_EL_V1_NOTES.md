# VA_EL_V1 v1.30

Bản này cải thiện cách đọc khối lượng và độ ổn định của phép tính. Màu thể hiện
khối lượng tương đối cùng hướng nến; đây không phải tín hiệu mua/bán hay xác suất thắng.

## Những thay đổi chính

- Không trộn real volume và tick volume trong cùng một đường trung bình.
  Chế độ Real dùng real volume cho toàn bộ chuỗi khi có dữ liệu dương; nếu toàn
  bộ dữ liệu real bằng 0 thì dùng tick volume. Tên chỉ báo ghi rõ nguồn đang dùng.
  Một nến real bằng 0 không bị thay bằng tick volume lớn của nến đó.
- `inpRequireFullPeriod=true`: chờ đủ số nến quá khứ bằng `inpAveragePeriod`
  trước khi phân loại. Với chu kỳ 20, 20 nến đầu giữ màu trung tính. Đặt `false`
  nếu muốn dùng trung bình khởi động từng phần như v1.29.
- Cửa sổ Data Window (Ctrl+D) có `Relative volume (prior MA)`.
  Giá trị 2.0 nghĩa là khối lượng nến gấp đôi MA của nến trước.
  Nến đang tính không tự làm tăng mức chuẩn so sánh của chính nó.
  Khi chưa đủ dữ liệu, MA trước bằng 0 hoặc tỷ lệ vượt giới hạn số có thể biểu
  diễn, tỷ lệ để trống. Trường hợp vượt giới hạn vẫn được phân loại cực lớn.
- `inpClosedColorsOnly=true` giữ nến hiện tại màu trung tính; tỷ lệ của nến này
  vẫn cập nhật theo volume đang nhận. Màu được xác định khi nến đóng.
- Tính tổng có trọng số trong thời gian khởi động bằng công thức cập nhật,
  bỏ vòng lặp lồng nhau. Lần đầu xử lý O(N); tick thông thường xử lý O(1);
  thêm K nến xử lý O(K). Bộ nhớ dùng 6 buffer, không tạo đối tượng biểu đồ.
- Xóa đúng buffer khi tắt chỉ báo, phát hiện lịch sử dịch chuyển, kiểm tra
  tham số và kết quả cấp buffer, trả đúng số nến đã xử lý khi bị dừng.

Khi nguồn dữ liệu đổi từ tick dự phòng sang real, hoặc broker sửa mất mẫu real
dương cuối cùng, chỉ báo tính lại toàn bộ để thống nhất đơn vị. Việc này có thể
đổi màu lịch sử. Broker nạp/sửa lịch sử hoặc người dùng đổi tham số cũng có thể
làm kết quả lịch sử thay đổi.

## Cài vào MT5

1. Giải nén bản tải; chỉ lấy `VA_EL_V1.mq5` để giữ nguyên các chỉ báo khác.
2. Trong MT5, chọn **File → Open Data Folder → MQL5 → Indicators** và chép tệp vào đó.
   Có thể đổi tên thành `VA_EL_V1_fixed.mq5` để giữ bản cũ.
3. Mở tệp bằng MetaEditor, nhấn **F7**. Chỉ dùng khi biên dịch không có lỗi.
4. Refresh danh sách Indicators trong MT5 rồi gắn chỉ báo lên biểu đồ.

Mặc định dùng tick volume; đây là số lần giá cập nhật, không phải khối lượng
giao dịch thực. Với thị trường/broker cung cấp real volume, có thể chọn Real.
Giữ SMA 20 và hai tùy chọn chờ đủ dữ liệu/nến đóng để bắt đầu; đánh giá các
ngưỡng trên dữ liệu của đúng mã và khung thời gian trước khi dùng giao dịch.

## Giao diện buffer

`0`: volume, `1`: chỉ số màu, `2`: MA, `3`: relative volume,
`4`: tổng trượt nội bộ, `5`: tổng có trọng số nội bộ.
EA đọc các buffer tính toán cũ 3/4 cần điều chỉnh; buffer volume và MA giữ vị trí.

## Mức kiểm chứng

Các kiểm thử trong `tests/` chạy thân hàm được trích trực tiếp từ mã MQL5 qua
bộ chuyển đổi C++17 và đối chiếu công thức tham chiếu độc lập. Chúng kiểm tra
logic số học, cập nhật dữ liệu và lượng truy cập buffer; không thay thế biên dịch
MetaEditor hoặc chạy với dữ liệu/biểu đồ MT5. Môi trường đám mây hiện chưa cài
được MetaEditor do máy chủ tải của MetaQuotes bị chặn; chưa có bản `.ex5` được
biên dịch hoặc kết quả kiểm chứng lợi nhuận.
