# common/feature_flags.py
# ============================================================
# Small, dependency-free module for cross-cutting feature
# switches that both portal/app.py and modules/*.py need to
# agree on without importing each other (avoids circular imports
# — portal/app.py imports modules.analysis_report_generator,
# so that module can't import back from portal/app.py).
# ============================================================

# Exadata UI + analysis-report Exadata section master switch.
#
# The Wave 1-4 Exadata parsers were built/validated against synthetic
# AWR reports modeled on the Mar-2024 Oracle whitepaper. Real customer
# Exadata AWR reports use a materially different section structure
# (confirmed via screenshots 2026-08-18 — see
# /areas/awr-insight-portal.md in project memory for the full writeup),
# so several parsers/tables are unreliable and the Exadata UI is paused
# until the parsers are rebuilt against a real AWR HTML source.
#
# Flip this one flag back to True to restore:
#   - the Exadata Analysis card on the portal home page
#   - the Exadata license controls in Settings
#   - the "Exadata statistics" copy on the Analysis Report picker page
#   - the Exadata sections/hotspots/recommendations in the generated
#     Analysis Report (modules/analysis_report_generator.py forces
#     exa_licensed=False while this is off, regardless of the
#     portal_config.license_exadata DB value, so no Exadata content
#     leaks into report text even if that config value is still 'true'
#     from before this was paused)
#
# No other code changes should be needed to restore the feature.
EXADATA_FEATURE_ENABLED = False
