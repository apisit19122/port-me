# Tickets: Port me

Menu bar app บน macOS 14+ (Swift/SwiftPM ล้วน ไม่มี external dependency — โครงเดียวกับ Pood) สำหรับดูและ kill dev process (node, bun, pnpm, yarn ฯลฯ) ที่ถือ TCP port ค้างอยู่ Design สรุปจาก grilling session: dev process = process ของ user ปัจจุบันที่ LISTEN TCP, binary ไม่อยู่ใน path ระบบและไม่อยู่ใน GUI .app bundle; kill = SIGTERM ทั้ง tree → รอ 2-3 วิ → SIGKILL ถ้า port ยังค้าง; ไม่มี confirm; สแกนเฉพาะตอน menu เปิด

**สถานะ: เสร็จครบทุกใบ** — `swift test` ผ่าน 59 tests, `dist/PortMe.app` build ได้และรันอยู่

Work the **frontier**: ticket ไหน blockers เสร็จครบแล้วเริ่มได้เลย ใบ 5 กับ 6 ทำขนานกันได้หลังใบ 4

## Scaffold + Port scanner core

**What to build:** SwiftPM package ครบโครง (`PortMeKit` library + `PortMe` executable + tests + `CONTEXT.md` glossary ตาม domain model ข้างบน) พร้อม scanner ที่รัน `swift run` แล้วพิมพ์รายการ process ของ user ปัจจุบันที่ LISTEN TCP port ออก terminal: PID, ชื่อ process, ports ทั้งหมด (รวม IPv4+IPv6 แล้ว dedupe), binary path, working directory (cwd)

**Blocked by:** None — can start immediately.

- [x] `swift test` ผ่านบนเครื่อง dev
- [x] `swift run` พิมพ์รายการ process ที่ LISTEN TCP ของ user ปัจจุบัน โดยหนึ่งรายการ = หนึ่ง process (port หลายตัวรวมอยู่ในรายการเดียว ไม่ซ้ำ IPv4/IPv6)
- [x] แต่ละรายการมี PID, ชื่อ, ports, binary path, cwd
- [x] ไม่นับ UDP และไม่นับ socket ที่ไม่ใช่สถานะ LISTEN
- [x] ไม่มี external dependency ใน Package.swift
- [x] มี `CONTEXT.md` นิยามศัพท์: Dev process, GUI app, Kill

## Dev-process filter

**What to build:** เกณฑ์คัดกรอง "app ไม่ใช่ของระบบ" — จากผล scan ตัด process ที่ binary อยู่ใน path ระบบ (`/System`, `/usr/libexec`, `/sbin`) และตัด process ที่ binary อยู่ใน GUI `.app` bundle ออก เหลือเฉพาะ dev process (node, bun, python, go ฯลฯ) โดย filter เป็น pure function ที่ปิด/เปิดได้ (รองรับ toggle "Show all" ในใบถัดไป)

**Blocked by:** Scaffold + Port scanner core

- [x] `swift run` แสดงเฉพาะ dev process — Chrome/OrbStack/Postman ที่ LISTEN port อยู่ไม่โผล่
- [x] Unit tests ครอบเคส: binary ใต้ nvm/homebrew/mise path (ผ่าน), binary ใน `/Applications/*.app` (ถูกตัด), binary ใน `/System` (ถูกตัด)
- [x] Filter มีโหมด "show all" ที่คืน process ทุกตัวของ user (ยังไม่มี UI — แค่ API)

## Kill engine (tree + escalation)

**What to build:** ฟังก์ชัน kill ที่รับ process แล้วฆ่าทั้ง tree (แม่ + ลูกหลานทุกตัว) ด้วย SIGTERM ก่อน รอ 2-3 วินาที ถ้า port ยังถูกถืออยู่ค่อยส่ง SIGKILL ซ้ำทั้ง tree — จัดการเคส `pnpm dev` spawn node ลูกเป็นตัวถือ port ได้ครบ ไม่เหลือ orphan ถือ port ต่อ

**Blocked by:** Scaffold + Port scanner core

- [x] Integration test: spawn process แม่ที่ spawn ลูกเปิด listener จริง → เรียก kill → port หลุดและทั้งแม่ลูกตายหมด
- [x] Process ที่รับ SIGTERM แล้วปิดตัวเองสวย ๆ ไม่โดน SIGKILL ซ้ำ
- [x] Process ที่ trap SIGTERM ไว้เฉย ๆ โดน SIGKILL หลังครบเวลารอ และ port หลุด
- [x] Kill รายงานผลกลับ (สำเร็จ / ยังค้าง) ให้ผู้เรียกใช้ได้

## Menu bar app MVP

**What to build:** แอป menu bar จริง — ไอคอน NSStatusItem คลิกแล้วสแกน ณ ตอนนั้น แสดงแถวละ process: ชื่อ + port badges + ชื่อโฟลเดอร์โปรเจกต์ (จาก cwd) พร้อมปุ่ม Kill ต่อแถว กดแล้วฆ่าเลยไม่มี confirm แถวหายจาก list เมื่อ kill สำเร็จ — ครบ loop เปิด → เห็น → ฆ่า → หาย

**Blocked by:** Dev-process filter, Kill engine (tree + escalation)

- [x] `swift run` ขึ้นไอคอนบน menu bar (ไม่มี Dock icon)
- [x] เปิด menu แล้วเห็นเฉพาะ dev process แถวละ process ตาม design (ชื่อ + ports + โฟลเดอร์)
- [x] กด Kill แล้ว process ตายจริง (ทั้ง tree) และแถวหายโดยไม่ต้องปิด-เปิด menu ใหม่
- [x] ไม่มี dialog ยืนยันใด ๆ
- [x] ไม่มี port ค้าง = แสดงข้อความว่างที่อ่านรู้เรื่อง

## Kill All + Show all + auto-refresh

**What to build:** ความสะดวกครบชุดบน menu — ปุ่ม Kill All ฆ่าทุก process ใน list ทีเดียว, toggle "Show all" สลับไปเห็น GUI app ที่ถูกซ่อน, และ list refresh ตัวเองทุก ~3 วินาทีเฉพาะตอน menu เปิดอยู่ (ปิด menu แล้วไม่มี background polling)

**Blocked by:** Menu bar app MVP

- [x] Kill All ฆ่าทุก process ที่แสดงอยู่ (ตาม filter ปัจจุบัน) แล้ว list ว่าง
- [x] Toggle "Show all" เปิดแล้วเห็น GUI app ด้วย ปิดกลับมาเหลือ dev process — ค่าที่เลือกจำข้ามการเปิดแอป
- [x] เปิด menu ทิ้งไว้ แล้ว process ใหม่ที่เพิ่ง LISTEN โผล่เองภายใน ~3 วิ / ตัวที่ตายหายเอง
- [x] ปิด menu แล้วไม่มี timer/polling ทำงานต่อ

## Launch at Login + bundle.sh

**What to build:** สคริปต์ bundle แบบเดียวกับ Pood — ได้ `dist/PortMe.app` ad-hoc signed ที่ดับเบิลคลิกใช้ได้ — และ toggle "Launch at Login" ใน menu (SMAppService, default ปิด) ซึ่งทำงานได้เฉพาะเมื่อรันจาก `.app` bundle จริง จึงอยู่ใบเดียวกัน

**Blocked by:** Menu bar app MVP

- [x] `scripts/bundle.sh` ผลิต `dist/PortMe.app` ที่เปิดใช้ได้จริงบนเครื่อง dev
- [x] เปิด toggle Launch at Login แล้วแอปขึ้นเองหลัง login / ปิด toggle แล้วไม่ขึ้น
- [x] Default = ปิด และสถานะ toggle ตรงกับสถานะจริงใน System Settings เสมอ
- [x] รันจาก `swift run` (ไม่ใช่ bundle) toggle ถูก disable พร้อมคำอธิบาย ไม่ crash
