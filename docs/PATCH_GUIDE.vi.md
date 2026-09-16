# Hướng dẫn Patch workspace

Patch của 3105 ánh xạ tới Application hoặc App Group bằng identifier ổn định. Gói patch không lưu UUID container vì UUID này thay đổi theo từng máy và mỗi lần cài lại ứng dụng.

## Cấu trúc workspace

Khi tạo patch tên `ABC`, 3105 tạo sẵn hai vùng ánh xạ có thể chỉnh sửa như sau:

```text
Trên iPhone của tôi/
└── 3105/
    └── Patches/
        └── ABC/
            ├── settings.json
            ├── Application/
            │   ├── com.abc.xyz/
            │   │   └── Documents/
            │   │       └── config.json
            │   └── com.example.second/
            │       └── Library/
            │           └── config.plist
            └── AppGroup/
                └── group.com.example.shared/
                    └── Library/
                        └── ConfigurationProfiles/
                            └── SharedDeviceConfiguration.plist
```

Mỗi folder ngay dưới `Application` là một bundle identifier ứng dụng. Mỗi folder ngay dưới `AppGroup` là một identifier bắt đầu bằng `group.`. Mọi thứ bên dưới folder identifier là đường dẫn tương đối trong container tương ứng. Một patch có thể chứa nhiều identifier ở cả hai vùng. Không dùng UUID của container App Group vì UUID khác nhau giữa các thiết bị.

`settings.json` nằm ở gốc workspace và chỉ khai báo các trường mà người dùng có thể điền. File này được đóng gói trong `.3105`; nó không phải là một file đích và không tạo thêm `3105.plist` trên thiết bị.

## Tạo patch

### Tạo từ tab Patch

1. Mở **Patch**, bấm **+**, sau đó chọn **Tạo patch**.
2. Nhập tên dự án. Mật khẩu có thể để trống để tạo gói không mật khẩu.
3. Bấm **Xong**. 3105 sẽ tạo workspace với `settings.json` cùng hai folder `Application` và `AppGroup`.
4. Mở **Tệp → Workspace 3105 → Patches → tên patch**.
5. Tự tạo folder identifier trong vùng phù hợp, sau đó tạo đúng cây đường dẫn đích và đặt file thay thế vào vị trí tương ứng.

Ví dụ muốn thay `Library/Preferences/com.abc.xyz.plist`, hãy đặt file mới tại `Application/com.abc.xyz/Library/Preferences/com.abc.xyz.plist`. Với App Group, dùng dạng `AppGroup/group.com.example.shared/Library/Preferences/shared.plist`. Nếu muốn thêm cả folder, hãy chép folder vào đúng thư mục cha; mọi file thường bên trong sẽ trở thành nội dung của patch. Quay lại chi tiết patch, bấm **Đồng bộ workspace**, sau đó chạm từng ánh xạ để chọn **Thay thế toàn bộ file**, **Sửa nội dung plist** hoặc **Sửa nội dung JSON**.

Gói beta cũ có ánh xạ `SystemAppGroup/systemgroup.*` vẫn được đọc để không làm mất khả năng khôi phục. 3105 không tạo loại ánh xạ đó cho patch mới.

## Tạo tuỳ chỉnh bằng settings.json

Tác giả có thể sửa `settings.json` trực tiếp trong workspace. Ví dụ:

```json
{
  "schemaVersion": 1,
  "fields": [
    {
      "id": "display_name",
      "label": "Tên hiển thị",
      "type": "string",
      "default": "3105",
      "multiline": false,
      "canRemove": true
    },
    {
      "id": "enabled",
      "label": "Bật tính năng",
      "type": "boolean",
      "default": true
    },
    {
      "id": "mode",
      "label": "Chế độ",
      "type": "string",
      "default": "compact",
      "options": [
        { "label": "Gọn", "value": "compact" },
        { "label": "Lớn", "value": "large" }
      ]
    }
  ]
}
```

Các `type` hỗ trợ là `string`, `boolean`, `integer`, `double`, `date` và `data`. Với `data`, dùng `encoding: "utf8"` để sửa dữ liệu dạng chữ hoặc `encoding: "base64"` cho dữ liệu nhị phân; mặc định là Base64. `id` phải duy nhất; `options` là tuỳ chọn và biến trường đó thành danh sách chọn. Đặt `canRemove: true` để hiện thêm công tắc **Xoá trường này**. Khi người dùng bật công tắc, key có giá trị toàn phần là placeholder tương ứng sẽ bị xoá; khi tắt, giá trị đã nhập vẫn được giữ để dùng lại. Sau khi đồng bộ, các trường này xuất hiện trong chi tiết patch ở mục **Đã cài**. Giá trị và lựa chọn xoá của mỗi patch được lưu riêng trên máy.

## Thêm, sửa và xoá nội dung plist hoặc JSON

File payload vẫn là plist/JSON bình thường nằm đúng đường dẫn đích; không tạo `3105.plist` phụ. Với plist, có thể thêm `%3105_Overwrite%` vào đầu **tên file trong workspace** để 3105 tự nhận đây là thao tác merge. Ví dụ:

```text
Application/com.locket.Locket/Library/Preferences/%3105_Overwrite%com.locket.Locket.plist
```

Khi đóng gói và áp dụng, tiền tố bị loại bỏ và file đích vẫn là `Library/Preferences/com.locket.Locket.plist`. Tên có tiền tố chỉ điều khiển cách áp dụng, không phải tên được ghi lên thiết bị. Các workspace cũ không có tiền tố vẫn giữ thao tác đã lưu trong metadata.

Ví dụ payload `com.locket.Locket.plist` chỉ cần chứa hai trường muốn thêm:

```xml
<dict>
    <key>/subscription_local_trial_started_at</key>
    <date>2026-09-05T08:26:04Z</date>
    <key>/subscription_local_trial_ended_at</key>
    <date>2099-12-31T23:59:59Z</date>
</dict>
```

### Đọc và sửa một key thay đổi theo từng máy

Khi tên key có một phần ID khác nhau trên mỗi thiết bị, đặt `%3105_MatchPrefix%` trước phần prefix ổn định. 3105 chỉ khớp đúng một key có phần còn lại là một đoạn không chứa `/`; vì vậy các endpoint con như `/attributes` hoặc `/offerings` không bị chọn.

Ví dụ file đích của Locket:

```text
Application/com.locket.Locket/Library/Preferences/
%3105_Overwrite%com.locket.Locket.revenuecat.etags.plist
```

Khai báo ô nhập trong `settings.json`:

```json
{
  "schemaVersion": 1,
  "fields": [
    {
      "id": "subscriber_cache",
      "label": "Subscriber cache",
      "type": "data",
      "encoding": "utf8",
      "default": "",
      "multiline": true
    }
  ]
}
```

Payload plist chỉ chứa selector và placeholder:

```xml
<dict>
    <key>%3105_MatchPrefix%https://api.revenuecat.com/v1/subscribers/</key>
    <string>{{subscriber_cache}}</string>
</dict>
```

Khi mở chi tiết patch, 3105 đọc plist thật trên máy, tìm key dạng `https://api.revenuecat.com/v1/subscribers/&lt;ID thiết bị&gt;`, giải mã `Data` UTF-8 và đưa nội dung hiện tại vào ô nhập. Khi áp dụng, nội dung đã sửa được mã hoá lại thành `Data` và ghi vào chính key vừa tìm thấy. Nếu không tìm thấy hoặc tìm thấy nhiều key phù hợp, 3105 dừng và không ghi file.

3105 lưu cách áp dụng trong metadata được mã hóa của gói `.3105`. Khi áp dụng, key mới được thêm, key trùng tên được cập nhật, Dictionary/Object lồng nhau được merge, còn key không nhắc tới được giữ nguyên. Array và giá trị đơn được thay toàn bộ. Payload và file đích phải có Dictionary/Object ở gốc.

Trong payload có thể dùng:

- `{{display_name}}`: nếu toàn bộ giá trị chỉ là placeholder, 3105 giữ đúng kiểu dữ liệu của trường như Boolean, Integer hoặc Date. Dùng trong chuỗi như `Xin chào {{display_name}}` thì kết quả luôn là String.
- Nếu `display_name` có `canRemove: true`, bật **Xoá trường này** sẽ xoá key đang chứa toàn bộ `{{display_name}}`. Placeholder nằm giữa một chuỗi hoặc trong phần tử Array không thể dùng để xoá và patch sẽ dừng an toàn.
- `%3105_Remove%`: đặt làm giá trị để xoá key tương ứng khỏi file đích.
- `%3105_Overwrite%`: đặt key này trong một Dictionary/Object để bỏ toàn bộ nội dung cũ của Dictionary/Object đó trước khi thêm các key còn lại.

Ví dụ plist động:

```xml
<dict>
    <key>DisplayName</key>
    <string>{{display_name}}</string>
    <key>Enabled</key>
    <string>{{enabled}}</string>
    <key>ObsoleteKey</key>
    <string>%3105_Remove%</string>
    <key>Appearance</key>
    <dict>
        <key>%3105_Overwrite%</key>
        <true/>
        <key>Mode</key>
        <string>{{mode}}</string>
    </dict>
</dict>
```

Một patch có thể thực hiện nhiều ánh xạ plist và JSON cho nhiều bundle trong cùng một lần Apply. Nếu một bundle không có trên máy, quy tắc của bundle đó được bỏ qua; các bundle tìm thấy vẫn được áp dụng.

Kết quả sau merge được ghi thành XML plist ổn định để việc kiểm tra hash và đặt lại patch không sai do thứ tự key của binary plist. Khi khôi phục, 3105 vẫn trả lại chính xác byte và định dạng ban đầu của file đích.

### Tạo nhanh từ file hoặc folder của ứng dụng

1. Mở **Tệp**, vào data container của ứng dụng rồi tìm file hoặc folder đích.
2. Giữ vào mục đó và chọn **Tạo patch**.
3. 3105 tự lấy bundle identifier ổn định và đường dẫn tương đối, sau đó mở bản nháp patch.
4. Lưu bản nháp, mở workspace rồi thay hoặc sắp xếp lại nội dung đã lấy theo nhu cầu.

## Áp dụng và khôi phục

- **Áp dụng** sẽ đồng bộ workspace vào gói `.3105`, kiểm tra các giá trị người dùng nhập, ánh xạ từng Application/App Group tới container hiện tại và kiểm tra an toàn từng đường dẫn.
- File đã tồn tại được sao lưu trước khi bị thay. File chưa tồn tại sẽ được thêm mới.
- Toàn bộ lần ghi có nhật ký và kiểm tra lại dữ liệu. Nếu lỗi giữa chừng, 3105 sẽ cố gắng rollback giao dịch.
- **Khôi phục file gốc** trả lại file đã có trước khi áp dụng, xóa file do patch thêm và xóa các folder do patch tạo sau khi chúng đã rỗng.
- Nếu file hiện tại hoặc dữ liệu khôi phục không còn khớp với nhật ký, app sẽ dừng an toàn thay vì ghi đè một đích chưa được xác minh.

Nên đóng các ứng dụng liên quan trong lúc áp dụng hoặc khôi phục patch. Không đổi tên hai folder vùng ánh xạ và không đặt identifier sai vùng.

## Xuất, nhập và mật khẩu

- **Xuất** luôn đồng bộ nội dung mới nhất trong workspace trước khi chia sẻ file `.3105`.
- Có thể nhập từ ứng dụng Tệp bằng cách mở hoặc chia sẻ gói `.3105` sang 3105.
- Website có thể mở app bằng `threeoneosfive://import?url=<URL HTTPS đã percent-encode>`. App chỉ nhận URL HTTPS không chứa tài khoản hoặc mật khẩu nhúng.
- Trên máy hoặc lần cài mới, gói có bảo vệ sẽ hỏi mật khẩu một lần. 3105 lưu content key đã mở khóa trong Keychain; file xuất ra vẫn được mã hóa và luôn gắn với mật khẩu ban đầu.
- Patch v1–v5 cũ vẫn sử dụng được và giữ hành vi cũ. Schema v6 thêm `settings.json`, placeholder có kiểu dữ liệu và thao tác sửa JSON; v7 thêm App Group; v8 thêm lựa chọn xoá động qua `canRemove`; v9 thêm key selector theo prefix và giá trị `Data` đọc từ thiết bị. App cũ sẽ từ chối schema mới an toàn thay vì hiểu sai thao tác.

## Quy tắc an toàn

- Chỉ dùng patch với ứng dụng và dữ liệu thuộc sở hữu của bạn.
- Luôn giữ một bản sao lưu riêng cho dữ liệu quan trọng.
- 3105 từ chối symbolic link, đường dẫn tuyệt đối, thành phần `..`, bundle không hợp lệ và nhiều mục trỏ đến cùng một đích.
- `settings.json` bị giới hạn số trường và kích thước; plist/JSON bị giới hạn độ sâu và số node để tránh payload không tin cậy làm cạn bộ nhớ.
- Không dùng trường nhập cho mật khẩu hoặc bí mật quan trọng. Giá trị được lưu cục bộ để dùng lại nhưng đây không phải kho bí mật.
- Bản 1.0.1 bỏ giới hạn cố định cũ về tổng dung lượng payload và số file; dung lượng trống, RAM, filesystem và giới hạn của iOS vẫn được áp dụng.
- Quyền truy cập trên thiết bị vẫn yêu cầu đúng build iOS được hỗ trợ và cách ký chứng chỉ doanh nghiệp được ghi trong README.
