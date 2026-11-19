# Corp Portal UI (Flutter) — agent guide

**หยุดแก้ไว้ก่อน:** frontend หลักคือ Angular (`../corp-portal-ui`) ห้ามเพิ่มฟีเจอร์ที่นี่ถ้าผู้ใช้ไม่ได้สั่งชัดเจน ฟีเจอร์ CRM ขั้น 3–6 (inventory status, ข้อมูลองค์กร, แพ็กเกจ, pool จาก CRM, chart) มีเฉพาะใน Angular

ถ้าได้รับคำสั่งให้แก้:
- งานเดินตาม `~/Documents/home/docs/ai-native-sdlc.md` และใช้ intent/spec ของงานเดียวกันใน `../corp-portal-api/docs/work/`
- ตรวจด้วย skill `flutter-check` (`flutter analyze`, `flutter test`)
- `web_dev_config.yaml` ต้องตรงกับ `../corp-portal-ui/proxy.conf.json`
- งานเข้า `main` ผ่าน PR เท่านั้น
