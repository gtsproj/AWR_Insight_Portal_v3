import sys
sys.path.insert(0, 'C:\\AWR_Insight_Portal_v3')
sys.path.insert(0, 'C:\\AWR_Insight_Portal_v3\\common')
try:
    import portal.app
    print('OK')
except Exception as e:
    import traceback
    traceback.print_exc()
