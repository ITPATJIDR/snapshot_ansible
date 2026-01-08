# Patch Report Playbook - คู่มือการใช้งาน

## ภาพรวม

Playbook นี้ใช้สำหรับสร้างรายงานผลการ patch ในรูปแบบ JSON โดยรวบรวมข้อมูลจาก patch playbooks ที่รันก่อนหน้า (เช่น `patch-linux.yml`, `patch-wsus.yml`)

## ไฟล์ที่เกี่ยวข้อง

- **patch-report-json.yml** - Playbook หลักสำหรับสร้างรายงาน
- **patch-linux.yml** - Patch playbook สำหรับ Linux (แก้ไขเพิ่มการเก็บข้อมูล)
- **patch-wsus.yml** - Patch playbook สำหรับ Windows (แก้ไขเพิ่มการเก็บข้อมูล)
- **example_patch_report.json** - ตัวอย่างไฟล์รายงานที่ได้

## วิธีการใช้งาน

### 1. รัน Patch Playbook ก่อน

ก่อนสร้างรายงาน ต้องรัน patch playbook ก่อนเพื่อเก็บข้อมูล:

```bash
# สำหรับ Linux servers
ansible-playbook -i inventory patch-linux.yml -e "install_updates=true"

# สำหรับ Windows servers
ansible-playbook -i inventory patch-wsus.yml -e "install_updates=true"
```

### 2. สร้างรายงาน

หลังจากรัน patch playbook แล้ว ให้รัน report playbook:

```bash
# สร้างรายงานทั้งหมด
ansible-playbook -i inventory patch-report-json.yml

# หรือรันจาก localhost เฉพาะ
ansible-playbook patch-report-json.yml
```

### 3. ตรวจสอบรายงาน

รายงานจะถูกบันทึกที่ `~/patch-report/patch_report_YYYYMMDD_HHMMSS.json`

```bash
# ดูรายงานล่าสุด
ls -lt ~/patch-report/ | head -5

# อ่านรายงานด้วย jq
cat ~/patch-report/patch_report_*.json | jq '.'
```

## การ Filter ข้อมูล

### Filter ตาม Server

```bash
ansible-playbook patch-report-json.yml -e "filter_server=web-server-01"
```

### Filter ตาม Job Name

```bash
# แสดงเฉพาะ Linux patches
ansible-playbook patch-report-json.yml -e "filter_job=patch-linux"

# แสดงเฉพาะ Windows patches
ansible-playbook patch-report-json.yml -e "filter_job=patch-wsus"
```

### Filter ตาม Status

```bash
# แสดงเฉพาะที่สำเร็จ
ansible-playbook patch-report-json.yml -e "filter_status=success"

# แสดงเฉพาะที่ล้มเหลว
ansible-playbook patch-report-json.yml -e "filter_status=failed"
```

### Filter หลายเงื่อนไข

```bash
ansible-playbook patch-report-json.yml \
  -e "filter_job=patch-linux" \
  -e "filter_status=failed"
```

## กำหนด Directory สำหรับบันทึกรายงาน

```bash
# บันทึกที่ตำแหน่งอื่น
ansible-playbook patch-report-json.yml -e "report_dir=/var/log/patch-reports"
```

## โครงสร้างของรายงาน JSON

```json
{
  "report_name": "Patch Result Report",
  "generated_date": "23/12/2025",
  "generated_time": "17:22:07",
  "filters_applied": {
    "server": "All servers",
    "job": "All jobs",
    "status": "All statuses"
  },
  "summary": {
    "total_servers": 5,
    "successful_patches": 3,
    "failed_patches": 2,
    "success_rate": "60.0%"
  },
  "results": [
    {
      "server": "server-name",
      "job_name": "patch-linux",
      "status": "success",
      "patch_date": "23/12/2025",
      "patch_time": "17:15:30",
      ...
    }
  ]
}
```

## Attributes ในรายงาน

### ข้อมูลทั่วไป (ทุก job)
- **server** - ชื่อ server
- **job_name** - ชื่อ job ที่รัน (patch-linux, patch-wsus)
- **status** - สถานะ (success, failed)
- **patch_date** - วันที่ patch (DD/MM/YYYY)
- **patch_time** - เวลาที่ patch (HH:MM:SS)

### สำหรับ Linux (patch-linux)
- **version_before** - Version ก่อน patch
- **version_after** - Version หลัง patch
- **service_status** - สถานะ service
- **updates_available** - มี updates หรือไม่ (Yes/No)
- **updates_installed** - ติดตั้ง updates หรือไม่ (Yes/No)
- **reboot_required** - ต้อง reboot หรือไม่ (true/false)

### สำหรับ Windows (patch-wsus)
- **wsus_server** - WSUS server ที่ใช้
- **services_checked** - Services ที่ตรวจสอบ
- **services_status_before** - สถานะ services ก่อน patch
- **services_status_after** - สถานะ services หลัง patch
- **available_updates** - จำนวน updates ที่มี
- **updates_installed** - จำนวน updates ที่ติดตั้ง
- **reboot_required** - ต้อง reboot หรือไม่ (Yes/No/N/A)

## ตัวอย่างการใช้งานใน AWX

### 1. สร้าง Job Template สำหรับ Patch

- **Name**: Patch Linux Servers
- **Playbook**: patch-linux.yml
- **Extra Variables**:
  ```yaml
  install_updates: true
  ```

### 2. สร้าง Job Template สำหรับ Report

- **Name**: Generate Patch Report
- **Playbook**: patch-report-json.yml
- **Extra Variables** (ถ้าต้องการ filter):
  ```yaml
  filter_status: failed
  ```

### 3. สร้าง Workflow

1. Run: Patch Linux Servers
2. Run: Patch Windows Servers
3. Run: Generate Patch Report (รันเสมอ - always)

## Tips

- รายงานจะถูกบันทึกที่เครื่องที่รัน playbook (localhost/AWX server)
- สามารถรัน report playbook หลายครั้งด้วย filter ต่างกันได้
- ไฟล์รายงานจะมี timestamp ไม่ซ้ำกัน
- ใช้ `jq` เพื่อ query และ format JSON ได้สะดวก

## ตัวอย่างการ Query ด้วย jq

```bash
# แสดงเฉพาะ summary
cat ~/patch-report/patch_report_*.json | jq '.summary'

# แสดง servers ที่ failed
cat ~/patch-report/patch_report_*.json | jq '.results[] | select(.status=="failed")'

# นับจำนวน success/failed
cat ~/patch-report/patch_report_*.json | jq '.results | group_by(.status) | map({status: .[0].status, count: length})'

# แสดง server และ status
cat ~/patch-report/patch_report_*.json | jq '.results[] | {server, status}'
```

## Troubleshooting

### ไม่มีข้อมูลในรายงาน

- ตรวจสอบว่ารัน patch playbook ก่อนหรือยัง
- ตรวจสอบว่า patch playbook มี task "Store patch result for reporting" หรือไม่

### รายงานไม่ถูกสร้าง

- ตรวจสอบว่า directory `~/patch-report` สามารถสร้างได้หรือไม่
- ตรวจสอบ permissions ของ directory

### Filter ไม่ทำงาน

- ตรวจสอบชื่อ server/job/status ว่าถูกต้องหรือไม่
- ใช้ exact match (case-sensitive)
