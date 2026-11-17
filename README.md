# Corp Portal UI (Flutter)

หน้าบ้านเวอร์ชัน **Flutter + flutter_bloc + go_router** ใช้ API ชุดเดียวกับ `corp-portal-ui` (Angular) ซึ่งยังเก็บไว้ใช้คู่กันจนกว่าจะย้ายเสร็จ

## คำสั่งที่ใช้บ่อย

| คำสั่ง | หน้าที่ |
| --- | --- |
| `flutter pub get` | ติดตั้ง package |
| `flutter analyze` | ตรวจโค้ด |
| `flutter test` | รัน unit/widget tests |
| `flutter run -d chrome` | รันบนเว็บที่ http://localhost:4300 ด้วยค่า dev พร้อม proxy `/api/v1` ไปหลังบ้าน |
| `flutter build web --release --dart-define-from-file=config/dev.json` | Build เว็บ dev (ไฟล์อยู่ที่ `build/web`) |
| `flutter build web --release --dart-define-from-file=config/prod.json` | Build เว็บ prod |

IntelliJ (เปิดโฟลเดอร์ `D:\projects\mvno`): เลือก run config **UI Flutter - dev** หรือ **UI Flutter - prod**

### แยก environment

ค่าของแต่ละ environment อยู่ใน `config/dev.json` และ `config/prod.json` (เทียบได้กับ `src/environments/environment.*.ts` ของ Angular) ส่งเข้าแอปตอน build ด้วย `--dart-define-from-file` แล้ว `AppConfig` อ่านค่า ไม่ส่งไฟล์ = ใช้ค่า dev (รันในเครื่องใช้ dev)

| Key | ใช้ทำอะไร |
| --- | --- |
| `APP_ENV` | `dev` / `prod` แสดงท้ายเวอร์ชันใน footer เมื่อไม่ใช่ prod |
| `API_BASE_URL` | ที่อยู่ API ค่าเริ่มต้น `/api/v1` (โดเมนเดียวกับหน้าเว็บ) |
| `PORTAL_WEB_URL` | URL เว็บสำหรับสร้างลิงก์ตั้งรหัสผ่าน ว่างได้บนเว็บ (ใช้ URL ที่เปิดอยู่) |
| `APP_VERSION` | ไม่อยู่ในไฟล์ ให้ CI ส่ง `--dart-define=APP_VERSION=...` |

- ไม่ต้องมีไฟล์ `.env` และ Flutter ไม่อ่าน `.yml` สำหรับค่าเหล่านี้ (`--dart-define-from-file` รับ `.json` หรือ `.env` เราใช้ JSON)
- ทุกค่าถูกฝังในไฟล์ที่ผู้ใช้ดาวน์โหลด **ห้ามใส่ secret** ไฟล์เหล่านี้จึง commit ได้
- ค่าจาก `--dart-define` ที่ส่งเพิ่มจะทับค่าในไฟล์ แอป native (Android/iOS/desktop) ต้องใช้ URL เต็ม เช่น
  `flutter build appbundle --dart-define-from-file=config/prod.json --dart-define=API_BASE_URL=https://<โดเมน>/api/v1`

### รันในเครื่องคู่กับหลังบ้าน

เปิดหลังบ้านทั้ง 4 services ก่อน (ดู `corp-portal-api/README.md`) แล้วรัน `flutter run -d chrome`
dev server ของ Flutter อ่าน `web_dev_config.yaml` และส่งต่อ `/api/v1/*` ตาม mapping เดียวกับ Angular `proxy.conf.json`:

| Path | Service |
| --- | --- |
| `auth`, `users`, `roles` | Identity `:4101` |
| `corporates` | Corporate `:4102` |
| `pools`, `sims`, `packages`, `sim-operations` | Telecom `:4103` |
| `dashboard`, `usage`, `reports`, `report-jobs` | Reporting `:4104` |

### บัญชีสำหรับ login

ไม่มีบัญชีสำเร็จรูป ผู้ดูแลคนแรกสร้างจากหลังบ้าน (ฐานข้อมูลต้อง `migrate` และ `crm-sync` แล้ว):

```powershell
cd ..\corp-portal-api
$env:IDENTITY_ADMIN_EMAIL = 'admin@example.com'; $env:IDENTITY_ADMIN_NAME = 'System Admin'
cargo run --locked -p identity-service --bin create-admin
```

คำสั่งพิมพ์ token ตั้งรหัสผ่าน (ใช้ได้ครั้งเดียว) เปิด `http://localhost:4300/set-password?token=<token>` ตั้งรหัสอย่างน้อย 12 ตัวอักษร แล้ว login ด้วยอีเมลนั้น ผู้ใช้อื่น (sales / corporate) สร้างจากหน้า Users ถ้าอีเมลนี้มีอยู่แล้ว `create-admin` จะไม่ทำอะไร ให้ admin คนอื่นกด "สร้างลิงก์ใหม่" ในหน้า Users แทน

เพิ่ม endpoint กลุ่มใหม่ในหลังบ้าน ต้องเพิ่มทั้งใน `web_dev_config.yaml` และ `proxy.conf.json` ของ Angular
Proxy ใช้เฉพาะตอน dev; ไฟล์จาก `flutter build web` เรียก `API_BASE_URL` ตรง ๆ ตอน deploy จึงต้องมี gateway หรือ CloudFront ส่งต่อให้

## โครงสร้าง

| ตำแหน่ง | ใช้ทำอะไร |
| --- | --- |
| `lib/app/` | ธีม, router + guard, เมนู, โครงหน้า (sidebar/header/footer) |
| `lib/core/` | API client (refresh token, idempotency key), config, ภาษา |
| `lib/features/<โมดูล>/` | หน้าจอ + bloc/cubit + repository ของแต่ละโมดูล |
| `lib/shared/business/` | ตาราง, การ์ด, สถานะ, ตัวจัดรูปแบบ, `ResourceBloc` สำหรับหน้าที่อ่านอย่างเดียว |
| `lib/shared/widgets/` | `CorporateScope`, `PageHeader`, `Notice`, กราฟ, สลับภาษา |

- หน้าที่ขึ้นกับองค์กรครอบด้วย `CorporateScope` เปลี่ยนองค์กรแล้ว bloc ของหน้าจะสร้างใหม่ ข้อมูลไม่ปนกัน
- ข้อความแปลเขียนแบบ `context.tr('English', 'ไทย')` ค่าเริ่มต้นเป็นภาษาไทย
- เว็บใช้ hash routing ลิงก์ตั้งรหัสผ่านเป็น `/#/set-password?token=...` และ `web/index.html` แปลงลิงก์แบบ `/set-password?token=...` (แบบของ Angular และหลังบ้าน) ให้อัตโนมัติ ตอน deploy server ต้องคืน `index.html` สำหรับ path `/set-password`
- มีโหมดสว่าง / มืด / ตามอุปกรณ์ (ปุ่มในเมนูบัญชีและหน้า login) สีที่เปลี่ยนตามโหมดอ่านจาก `context.palette` (`lib/app/theme.dart`) อย่าใส่สีพื้นหรือสีตัวอักษรตรง ๆ ใน widget
- Refresh token บนเว็บเก็บใน sessionStorage (ต่อแท็บ) ส่วน native ใช้ secure storage

## หน้าที่ย้ายแล้ว

Login, ลืมรหัสผ่าน, ตั้งรหัสผ่าน, Dashboard, Corporate/Inventory, SIM, Data pooling, Users (admin), Reports + ส่งออก CSV, Roles (admin), API docs
