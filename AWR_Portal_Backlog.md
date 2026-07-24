# AWR Insight Portal v3 — Backlog & Status Report
**Last updated:** 2026-07-24

---

## ✅ Completed

### Core Functionality
- AWR HTML report parsing (all sections: Wait Events, SQL, Segments, Load Profile, Instance Efficiency, I/O, Time Model, SGA/PGA)
- SAR report parsing (CPU, Memory, Disk, Network, Context Switch, Load Avg, Paging, Swap, Socket, HugePage)
- Queue-based processing (AWRQueueProcessor, AWRWatcher, SARWatcher services)
- License enforcement with resource-specific flags (allow_parse_awr, allow_parse_sar, allow_ai_new_awr, allow_ai_new_sar)

### Rules Engine
- 61-rule JSON-based recommendation engine (recommendation_rules_v2.json)
- Rule categories: Wait Events (43), SQL (5), Segment (9), Instance Efficiency (4)
- awr_object_metadata enrichment in stored recommendations (BLEVEL, CF, num_rows, partitioned)
- Replaced old awr_recommendation_rules table — all rules now in JSON

### Correlation Panel (awr-unified-intelligence, awr-intelligence-ai)
- Wait event → segment routing via awr_wait_event_master (corr_type, seg_filter, guidance_text, has_specific_rule)
- 393 events seeded with specific guidance; ~1525 Other/Idle use class-level fallback
- seg_filter: index_only for db file sequential read; table_only for direct path read
- SQL focus → segment correlation via awr_sql_object_map_mv + co-occurrence scoring
- Segment focus → SQL correlation via text map + co-occurrence
- No segment correlation for background/network/redo events — shows specific guidance text instead

### Portal UI
- Nav bar restructured: Upload ▼ (AWR/SAR/Plan/Metadata), Analysis ▼ (Compare/Plan/SQL Search), Queue Monitor, AI Recs, AWR Trends
- AWR Trends Navigator page (/awr-trends): card grid, 6 sections, Option B styling (coloured top border + tint)
- Snap selection on AWR Trends page propagates to child dashboards with epoch_ms for timezone-correct time picker alignment
- api/snaps: HH24:MI:SS format, regular hyphen separator, epoch_ms for IST→UTC conversion

### Dashboards
- Separate Rules and AI mode dashboards for all main dashboards (suffix -ai)
- Navigation Hub (AWR Trends Navigator): card grid, 6 colour-coded sections, inline-block CSS
- Child dashboards: start_snap/end_snap refresh changed from 2 to 1 (prevents zoom-to-data variable reset)
- Disclaimer panel added to Rules and AI intelligence dashboards
- Contextual nav bars on all Tier 1 dashboards (no portal_home link — Grafana variable limitation)
- ?kiosk on all cross-dashboard navigation links (hides Grafana top bar)

### Infrastructure
- patch_grafana_urls.py: auto-detects server IP, patches portal/static/ dashboards
- _auto_patch_grafana_dashboards() in app.py: patches variable defaults AND hardcoded IPs in href content on service restart — handles IP changes seamlessly
- Schema: awr_portal_schema_owner.sql (awr_owner + awr_readonly roles)
- Schema: awr_portal_consolidated_schema.sql (single installation script)

### Bug Fixes (Testing Round)
- AWR Anomaly Detection: extra closing bracket removed from 3 panel queries
- SAR Overview / SAR Correlation: time range changed from now-1d to now-30d
- SAR Correlation CPU query: replaced awr_sql_cpu_time with awr_load_profile pivot (DB CPU % of DB Time + Oracle DB CPU s/sec alongside OS User % + OS System %)
- comparison.html: ai_mode routing for awr-comparison vs awr-comparison-ai dashboard UID
- app.py comparison routes: _load_config() → _get_config() (was causing Internal Server Error)
- AWR+SAR Correlation: variable order changed (hostname → dbname → instance); UPPER() added for case-insensitive hostname matching

---

## 🔄 In Progress / Pending

### Testing
- [ ] Complete full tool testing pass after all fixes
- [ ] Verify correlation panel behaviour across all wait event types with live AWR data

### Correlation Panel — Redesign Required
- **Status: PARKED** — redesign from scratch for better accuracy
- Current wait→segment correlation works for User I/O, Application, Concurrency, Cluster
- 3-way correlation (wait↔SQL↔segment) needs complete architectural rethink
- Specific gap: Host CPU / Instance CPU section not parsed (AWR report has %Total CPU, %Busy CPU, host CPU cores/load data)
- Plan: design proper fact-based 3-way correlation when capacity allows

### SAR Dashboard Enhancements
- [ ] OS Disk utilisation: show only top 10 disks by utilisation, descending order
- [ ] OS Disk: tooltip should show utilisation in descending order

### Schema & Database
- [ ] Separate schema owner (awr_owner) — script created (awr_portal_schema_owner.sql), needs deployment
- [ ] Migrate existing objects to awr_owner ownership
- [ ] awr_recommendation_rules table: can be dropped after confirming no references remain
- [ ] Host CPU / Instance CPU parser: new module needed for AWR host/instance CPU section

### Cleanup Pass (after testing)
- [ ] Remove stray backup files confirmed as unused
- [ ] Fresh bulk_export.py after all dashboard fixes — final verification
- [ ] Verify no files reference awr_recommendation_rules table

---

## 📋 Upcoming — Documentation & Packaging

### Priority: HIGH (demo next week)
- [ ] **Installation Guide** — system requirements, tech stack versions, Python dependencies, step-by-step install commands, service setup, first-run configuration
- [ ] **User Manual** — detailed guide covering all features, dashboards, upload workflows, AI modes, comparison tags, AWR Trends page
- [ ] **Management Presentation (2-3 slides)**:
  - Slide 1: Objective — what the tool does, problem it solves
  - Slide 2: Functionalities — AWR/SAR parsing, Rules/AI recommendations, correlation, dashboards, AWR Trends, comparison
  - Slide 3: Benefits — time savings for DBA, proactive issue detection, historical trend analysis, AI-assisted tuning

### Priority: MEDIUM
- [ ] **Installation Bundle** — options being evaluated:
  - ZIP with installer batch script (simplest, Windows-compatible)
  - MSI installer using WiX or Inno Setup (professional but complex)
  - Code obfuscation using PyArmor (prevents unauthorized access to source)
  - Recommendation: ZIP + install.bat + PyArmor obfuscation for Python files

---

## 🏗️ Architecture Notes

### Tech Stack
- Python 3.13, FastAPI, uvicorn (portal service)
- PostgreSQL (all parsed AWR/SAR data)
- Grafana 12 OSS (dashboards — embedded, not standalone)
- NSSM (Windows service manager)
- BeautifulSoup4 + pandas (AWR HTML parsing)
- Jinja2 (portal templates)

### Service Architecture
- **AWRPortal**: FastAPI web portal (port 8000)
- **AWRWatcher**: Watches awr_reports/ folder, enqueues new files
- **AWRQueueProcessor**: Processes AWR queue, calls master_parser.py
- **SARWatcher**: Watches SAR upload folder, enqueues SAR files
- **Grafana**: Dashboard server (port 3000, embedded in portal)

### Dashboard Structure
- **Rules mode**: awr-unified-intelligence, awr-anomalies, awr-memory-advisory, awr-comparison, sar-overview, sar-anomalies, sar-awr-correlation
- **AI mode**: awr-intelligence-ai + duplicate -ai suffix dashboards for all above
- **AWR Trends child dashboards**: 50 dashboards linked from AWR Trends Navigator page
- **Navigation**: Portal nav bar → AWR Trends page → child dashboards (all open with ?kiosk)

### Known Limitations
- Grafana text panel: ${portal_url} variable not resolved in href attributes — workaround: hardcode portal URL in nav panels, auto-patched by _auto_patch_grafana_dashboards() on restart
- Grafana nav bar cannot be hidden via JSON alone — ?kiosk URL parameter used on all cross-dashboard links
- CSS grid/flex may not work in Grafana iframe — inline-block with percentage widths used instead
