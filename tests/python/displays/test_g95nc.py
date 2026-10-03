import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.support.python import ROOT

SCRIPT = ROOT / 'home/dot_config/raycast/scripts/executable_g95nc.sh'
TOOLS = r'''
import json, os, pathlib, sys, time
root=pathlib.Path(os.environ['G95_TEST_ROOT'])
state_path=root/'state.json'
s=json.loads(state_path.read_text())
name=pathlib.Path(sys.argv[0]).name
args=sys.argv[1:]
with (root/'events').open('a') as f: f.write(json.dumps([name,*args])+'\n')
def save(): state_path.write_text(json.dumps(s))
if name=='sleep': sys.exit()
if name=='pgrep': sys.exit(0 if s['running'] else 1)
if name=='osascript': s['running']=False; save()
elif name=='open': s['running']=True; save()
elif name=='sw_vers': print('macOS test version')
elif name=='system_profiler':
    displays=[]
    for d in s['devices']:
        if d['UUID']=='unrelated': continue
        width,height=map(int,d['resolution'].split('x'))
        displays.append(dict(_spdisplays_displayID=format(int(d['displayID']),'x'),
            _spdisplays_resolution=f"{width} x {height} @ {s.get('native_refresh_override',d['refreshRate'])}",
            _spdisplays_pixels='7680 x 2160' if s.get('reject_native') else f'{width*2} x {height*2}',
            spdisplays_main='spdisplays_yes' if d.get('main')=='on' else 'spdisplays_no',
            spdisplays_mirror_status='spdisplays_master_mirror' if d['UUID']=='managed' else 'spdisplays_hardware_mirror'))
    print(json.dumps({'SPDisplaysDataType':[{'spdisplays_ndrvs':displays}]}))
elif name=='defaults':
    if args[0]=='read':
        if args[2]!='enable16K':
            print(s.get('preferences',{}).get(args[2],'')); sys.exit()
        if not s['enable16K']: print('missing preference',file=sys.stderr); sys.exit(1)
        print('1')
    else:
        if args[2]=='enable16K': s['enable16K']=True
        else: s.setdefault('preferences',{})[args[2]]=args[4]
        save()
elif name=='bd':
    if s.get('hang'): time.sleep(20)
    op=args[0]
    flags=dict(a[2:].split('=',1) if '=' in a else (a[2:],'') for a in args[1:])
    if op=='help': print('BetterDisplay Version test'); sys.exit()
    devices=s['devices']
    selected=devices
    if 'UUID' in flags: selected=[d for d in selected if d['UUID']==flags['UUID']]
    if 'tagID' in flags: selected=[d for d in selected if d.get('tagID')==flags['tagID']]
    if 'nameLike' in flags: selected=[d for d in selected if flags['nameLike'] in d['name']]
    if 'type' in flags: selected=[d for d in selected if d['deviceType']==flags['type']]
    if op=='get':
        if 'identifiers' in flags:
            if not selected: print('Failed.'); sys.exit(1)
            print(','.join(json.dumps(d) for d in [*selected,dict(deviceType='DisplayGroup',name='Default Group',tagID='-1001')])); sys.exit()
        if not selected: sys.exit(1)
        if 'displayModeList' in flags:
            rates=s.get('preferences',{}).get('refreshRates@VirtualScreen:44')=='[60,120]'
            if not s.get('missing_120') and (selected[0]['deviceType']=='Display' or rates):
                print('10 - 3840x1080 HiDPI 120Hz 8bpc\n20 - 4096x1152 HiDPI 120Hz 8bpc\n30 - 4480x1260 HiDPI 120Hz 8bpc\n40 - 4608x1296 HiDPI 120Hz 8bpc')
            sys.exit()
        keys=[k for k in flags if k not in ('UUID','type','nameLike')]
        print(','.join(('true' if selected[0].get(k)=='on' else 'false') if k=='main' else ('on,on' if k=='connected' else ('3840x1080' if k=='resolution' and selected[0]['UUID']=='panel' and s.get('stale_physical_resolution') else str(selected[0].get(k,'on')))) for k in keys))
    elif op=='discard':
        s['devices']=[d for d in devices if d not in selected]; save()
    elif op=='create':
        devices.append(dict(UUID='UNKNOWN',tagID='44', name=flags['virtualScreenName'], deviceType='VirtualScreen',
            vendor='2198', model=flags['virtualScreenModelNumber'], serial=flags['virtualScreenSerial'],
            displayID='0',resolution='3840x1080',hiDPI='on',refreshRate='60Hz',main='false',mirror='off',connected='on'))
        save()
    elif op=='set':
        if not selected: sys.exit(1)
        for d in selected:
            if 'displayModeNumber' in flags:
                resolution={'10':'3840x1080','20':'4096x1152','30':'4480x1260','40':'4608x1296'}[flags['displayModeNumber']]
                d.update(resolution=resolution,hiDPI='on',refreshRate='120Hz')
                if d['deviceType']=='VirtualScreen' and d.get('mirror')=='on':
                    next(x for x in devices if x['UUID']=='panel').update(resolution=resolution,hiDPI='on',refreshRate='120Hz')
            for k,v in flags.items():
                if k not in ('UUID','targetUUID'):
                    if k=='resolution' and d['UUID']=='managed' and (not s['enable16K'] or s.get('reject_resolution')):
                        print('resolution refused',file=sys.stderr); sys.exit(1)
                    d[k]=v
            if flags.get('connected')=='on' and d['deviceType']=='VirtualScreen':
                d.update(UUID='managed',displayID='3')
            if flags.get('mirror')=='on':
                target=next(d for d in devices if d['UUID']==flags['targetUUID'])
                target.update(resolution=d['resolution'],hiDPI=d['hiDPI'],refreshRate=d['refreshRate'],mirror='on')
        save()
'''


class G95Tests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.bin=self.root/'bin'
        self.bin.mkdir()
        for name in ('bd','pgrep','osascript','open','defaults','sw_vers','system_profiler','sleep'):
            p=self.bin/name
            p.write_text(f'#!{sys.executable}\n'+TOOLS)
            p.chmod(0o755)
        self.env={**os.environ,'G95_TEST_ROOT':str(self.root),'BD_CLI':str(self.bin/'bd'),
                  'PATH':f'{self.bin}:{os.environ["PATH"]}','XDG_STATE_HOME':str(self.root/'state'),
                  'G95_POLL_ATTEMPTS':'1','G95_COMMAND_TIMEOUT':'2'}
        self.state={'running':True,'enable16K':True,'devices':[
            dict(UUID='panel',tagID='66',displayID='2',name='Odyssey G95NC',deviceType='Display',vendor='19501',model='29813',serial='123',
                 resolution='3840x1080',hiDPI='on',refreshRate='120Hz',main='true',mirror='off'),
            dict(UUID='unrelated',name='Other virtual',deviceType='VirtualScreen',vendor='2198',model='1',serial='2')]}
        self.save()

    def save(self):
        (self.root/'state.json').write_text(json.dumps(self.state))

    def invoke(self,*args):
        result=subprocess.run(['/bin/bash',str(SCRIPT),*args],env=self.env,text=True,capture_output=True,timeout=45)
        self.state=json.loads((self.root/'state.json').read_text())
        return result

    def events(self):
        return [json.loads(line) for line in (self.root/'events').read_text().splitlines()]

    def test_butter_selects_90_percent_hidpi_at_120hz(self):
        result=self.invoke('butter')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        for uuid in ('panel','managed'):
            device=next(d for d in self.state['devices'] if d['UUID']==uuid)
            self.assertEqual((device['resolution'],device['hiDPI'],device['refreshRate']),
                             ('4608x1296','on','120Hz'))
        self.assertIn('unrelated',[d['UUID'] for d in self.state['devices']])
        self.assertEqual(self.state['preferences'], {
            'useCustomRefreshRates@VirtualScreen:44':'true',
            'refreshRates@VirtualScreen:44':'[60,120]'})

    def test_switching_butter_and_sharp_preserves_requested_refresh(self):
        for mode,resolution,rate in [('butter','4608x1296','120Hz'),
                                     ('set','4864x1368','60Hz'),
                                     ('butter','4608x1296','120Hz')]:
            result=self.invoke(mode)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            for uuid in ('panel','managed'):
                device=next(d for d in self.state['devices'] if d['UUID']==uuid)
                self.assertEqual((device['resolution'],device['refreshRate']),(resolution,rate))

    def test_butter_uses_macos_dimensions_when_physical_cli_cache_is_stale(self):
        self.state['stale_physical_resolution']=True
        self.save()
        result=self.invoke('butter')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('[ok] Butter',result.stdout)

    def test_butter_repeated_setup_is_read_only(self):
        self.assertEqual(self.invoke('butter').returncode,0)
        (self.root/'events').write_text('')
        result=self.invoke('butter')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('Already',result.stdout)
        self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1] in ('set','create','discard')])
        self.assertFalse([e for e in self.events() if e[0] in ('osascript','open')])

    def test_butter_rejects_macos_60hz_despite_cli_120hz(self):
        self.state['native_refresh_override']='60Hz'
        self.save()
        result=self.invoke('butter')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        panel=next(d for d in self.state['devices'] if d['UUID']=='panel')
        self.assertEqual(panel['refreshRate'],'60Hz')
        self.assertIn('Setup failed',result.stdout)

    def test_butter_requires_an_advertised_120hz_mode(self):
        self.state['missing_120']=True
        self.save()
        result=self.invoke('butter')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertNotIn('[ok] Butter',result.stdout)
        self.assertNotIn('managed',[d['UUID'] for d in self.state['devices']])

    def test_missing_8k_setting_is_enabled_before_sharp_mode(self):
        self.state['enable16K']=False
        self.save()
        result=self.invoke('set')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertTrue(self.state['enable16K'])
        virtual=next(d for d in self.state['devices'] if d['UUID']=='managed')
        self.assertEqual((virtual['resolution'],virtual['hiDPI'],virtual['mirror'],virtual['main']),
                         ('4864x1368','on','on','on'))
        self.assertIn('unrelated',[d['UUID'] for d in self.state['devices']])
        logs=list((self.root/'state/g95nc').glob('*.log'))
        self.assertEqual(len(logs),1)
        log=logs[0].read_text()
        self.assertIn('missing preference',log)
        self.assertIn('defaults write',log)
        self.assertIn('finished exit=0',log)
        self.assertEqual(logs[0].stat().st_mode & 0o777,0o600)

    def test_failed_setup_returns_failure_after_successful_recovery(self):
        self.state['reject_resolution']=True
        self.save()
        result=self.invoke('set')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        panel=next(d for d in self.state['devices'] if d['UUID']=='panel')
        self.assertEqual((panel['resolution'],panel['hiDPI'],panel['refreshRate']),('3840x1080','on','60Hz'))
        self.assertIn('unrelated',[d['UUID'] for d in self.state['devices']])
        self.assertNotIn('managed',[d['UUID'] for d in self.state['devices']])
        self.assertIn('resolution refused',next((self.root/'state/g95nc').glob('*.log')).read_text())

    def test_already_correct_setup_does_not_mutate_displays(self):
        self.assertEqual(self.invoke('set').returncode,0)
        (self.root/'events').write_text('')
        result=self.invoke('set')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('Already',result.stdout)
        self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1] in ('set','create','discard')])

    def test_check_is_read_only_even_when_8k_setting_is_missing(self):
        self.state['enable16K']=False
        self.save()
        original=json.loads(json.dumps(self.state))
        result=self.invoke('check')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.state,original)

    def test_invalid_resolution_is_rejected_before_display_changes(self):
        result=self.invoke('set','4864x1368junk')
        self.assertEqual(result.returncode,2)
        self.assertIn('positive WxH',result.stderr)
        self.assertFalse([e for e in self.events() if e[0]=='bd'])

    def test_duplicate_physical_identity_stops_before_mutation(self):
        self.state['devices'].append({**self.state['devices'][0],'UUID':'second-panel'})
        self.save()
        result=self.invoke('set')
        self.assertEqual(result.returncode,1)
        self.assertIn('exactly one',result.stderr)
        self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1] in ('set','create','discard')])

    def test_disconnected_reset_only_discards_owned_virtual_screen(self):
        self.assertEqual(self.invoke('set').returncode,0)
        self.state['devices']=[d for d in self.state['devices'] if d['UUID']!='panel']
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual([d['UUID'] for d in self.state['devices']],['unrelated'])

    def test_hung_cli_has_a_deadline_and_diagnostic(self):
        self.state['hang']=True
        self.save()
        result=self.invoke('check')
        self.assertEqual(result.returncode,1)
        self.assertIn('unresponsive',result.stderr)
        self.assertIn('command timed out',next((self.root/'state/g95nc').glob('*.log')).read_text())

    def test_existing_lock_is_preserved(self):
        lock=self.root/'state/g95nc/lock'
        lock.mkdir(parents=True)
        (lock/'pid').write_text('12345')
        result=self.invoke('set')
        self.assertEqual(result.returncode,1)
        self.assertEqual((lock/'pid').read_text(),'12345')
        self.assertFalse((self.root/'events').exists())

    def test_log_retention_keeps_latest_thirty(self):
        directory=self.root/'state/g95nc'
        directory.mkdir(parents=True)
        for i in range(35): (directory/f'20000101-{i:02}.log').write_text('old')
        self.assertEqual(self.invoke('check').returncode,0)
        self.assertEqual(len(list(directory.glob('*.log'))),30)
        self.assertFalse((directory/'20000101-00.log').exists())

    def test_macos_framebuffer_disagreement_is_a_setup_failure(self):
        self.state['reject_native']=True
        self.save()
        result=self.invoke('set')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn('macOS mirror/framebuffer verification failed',
                      next((self.root/'state/g95nc').glob('*.log')).read_text())

    def test_matching_name_with_different_identity_survives_reset(self):
        self.state['devices'][1]['name']='G95-HiDPI'
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('unrelated',[d['UUID'] for d in self.state['devices']])

    def test_duplicate_owned_identity_stops_before_mutation(self):
        self.assertEqual(self.invoke('set').returncode,0)
        owned=next(d for d in self.state['devices'] if d['UUID']=='managed')
        self.state['devices'].append({**owned,'UUID':'duplicate'})
        self.save()
        (self.root/'events').write_text('')
        result=self.invoke('set')
        self.assertEqual(result.returncode,1)
        self.assertIn('ambiguous managed',result.stderr)
        self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1] in ('set','create','discard')])

    def test_missing_owned_tag_cannot_broaden_discard(self):
        self.assertEqual(self.invoke('set').returncode,0)
        owned=next(d for d in self.state['devices'] if d['UUID']=='managed')
        del owned['tagID']
        self.save()
        (self.root/'events').write_text('')
        result=self.invoke('reset')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1]=='discard'])
        self.assertIn('unrelated',[d['UUID'] for d in self.state['devices']])

    def test_optimized_python_does_not_disable_native_verification(self):
        self.env['PYTHONOPTIMIZE']='1'
        self.state['reject_native']=True
        self.save()
        self.assertEqual(self.invoke('set').returncode,1)
