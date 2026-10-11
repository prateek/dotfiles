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
import json, os, pathlib, plistlib, sys, time
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
        if d['UUID']=='unrelated' or d.get('displayID')=='0': continue
        width,height=map(int,d['resolution'].split('x'))
        displays.append(dict(_spdisplays_displayID=format(int(d['displayID']),'x'),
            _spdisplays_resolution=f"{width} x {height} @ {s.get('native_refresh_override',d['refreshRate'])}",
            _spdisplays_pixels='7680 x 2160' if s.get('reject_native') else f'{width*2} x {height*2}',
            spdisplays_main='spdisplays_yes' if d.get('main')=='on' else 'spdisplays_no',
            spdisplays_mirror_status='spdisplays_master_mirror' if d['UUID']=='managed' else 'spdisplays_hardware_mirror'))
    print(json.dumps({'SPDisplaysDataType':[{'spdisplays_ndrvs':displays}]}))
elif name=='defaults':
    if args[0]=='domains':
        print('pro.betterdisplay.BetterDisplay' if s.get('domain_exists',True) else '')
    elif args[0]=='export':
        if s.get('backup_failure'): sys.exit(1)
        data={'enable16K':s['enable16K'], **s.get('preferences',{})} if s.get('domain_exists',True) and not s.get('preferences_cleared') else {}
        pathlib.Path(args[2]).write_bytes(plistlib.dumps(data))
    elif args[0]=='delete':
        if s['running'] or s.get('delete_failure'): sys.exit(1)
        s.update(enable16K=False,preferences={},domain_exists=True,preferences_cleared=True)
        s['devices']=[d for d in s['devices'] if d['deviceType']=='Display']
        for d in s['devices']: d.update(mirror='off',hiDPI='off')
        save()
    elif args[0]=='read':
        if args[2]!='enable16K':
            value=s.get('preferences',{}).get(args[2],'')
            print({'true':'1','false':'0'}.get(value,value)); sys.exit()
        if not s['enable16K']: print('missing preference',file=sys.stderr); sys.exit(1)
        print('1')
    else:
        s['domain_exists']=True
        s['preferences_cleared']=False
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
            print(','.join(json.dumps(d) for d in [*selected,dict(deviceType='DisplayGroup',name='Default Group',tagID='-1001')])); sys.exit()
        if not selected: sys.exit(1)
        if 'i2cEDID' in flags:
            if s.get('unreadable_edid'): sys.exit(1)
            print('factory-edid'); sys.exit()
        if 'osEDID' in flags: print(s.get('active_edid','factory-edid')); sys.exit()
        if 'displayModeList' in flags:
            if selected[0]['deviceType']=='Display':
                print('1 - 7680x2160 60Hz 10bpc Default Native')
                print('2 - 3840x1080 HiDPI '+s.get('fractional_60','60Hz')+' 10bpc')
            rates=s.get('preferences',{}).get('refreshRates@VirtualScreen:44')=='[60,120]'
            if not s.get('missing_120') and (selected[0]['deviceType']=='Display' or rates):
                print(('10 - 3840x1080 HiDPI 120Hz 8bpc\n20 - 4096x1152 HiDPI 120Hz 8bpc\n30 - 4480x1260 HiDPI 120Hz 8bpc\n40 - 4608x1296 HiDPI 120Hz 8bpc').replace('120Hz',s.get('fractional_120','120Hz')))
            sys.exit()
        if 'connectionModeListAll' in flags or 'connectionModeList' in flags:
            if not s.get('unsupported_link') and not ('connectionModeList' in flags and s.get('downscaled_link')):
                print('600 - 7680x2160 '+s.get('fractional_60','60Hz')+' Fixed 10bit SDR RGB Full SRGB')
                if not s.get('missing_120'):
                    print('1200 - 7680x2160 '+s.get('fractional_120','120Hz')+' Fixed 10bit SDR RGB Full SRGB')
            print('100 - 3840x1080 59.97Hz Fixed 10bit SDR RGB Full SRGB')
            sys.exit()
        if 'connectionMode' in flags:
            size='3840x1080' if s.get('unsupported_link') or s.get('downscaled_link') else '7680x2160'
            color='HDR10 RGB Full' if selected[0].get('hdr')=='on' else 'SDR '+s.get('encoding','RGB Full')
            print('600 - '+size+' '+selected[0]['refreshRate']+' Fixed 10bit '+color+' SRGB')
            sys.exit()
        keys=[k for k in flags if k not in ('UUID','type','nameLike')]
        print(','.join(('true' if selected[0].get(k)=='on' else 'false') if k=='main' else ('on,on' if k=='connected' else ('3840x1080' if k=='resolution' and selected[0]['UUID']=='panel' and s.get('stale_physical_resolution') else str(selected[0].get(k,'on')))) for k in keys))
    elif op=='perform':
        if 'applyFactoryEDID' in flags and not s.get('ignore_factory_edid'):
            s['active_edid']='factory-edid'
        save()
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
            if 'connectionMode' in flags: s['encoding']='RGB Full'
            if 'displayModeNumber' in flags:
                number=flags['displayModeNumber']
                resolution={'1':'7680x2160','2':'3840x1080','10':'3840x1080','20':'4096x1152','30':'4480x1260','40':'4608x1296'}[number]
                rate=s.get('fractional_60','60Hz') if number in ('1','2') else s.get('fractional_120','120Hz')
                if not s.get('ignore_default') or number!='1':
                    d.update(resolution=resolution,hiDPI='off' if number=='1' else 'on',refreshRate=rate)
                if d['deviceType']=='VirtualScreen' and d.get('mirror')=='on':
                    next(x for x in devices if x['UUID']=='panel').update(resolution=resolution,hiDPI='on',refreshRate=rate)
            for k,v in flags.items():
                if k not in ('UUID','targetUUID'):
                    if k=='resolution' and d['UUID']=='managed' and (not s['enable16K'] or s.get('reject_resolution')):
                        print('resolution refused',file=sys.stderr); sys.exit(1)
                    d[k]=v
            if flags.get('connected')=='on' and d['deviceType']=='VirtualScreen':
                d.update(UUID='managed',displayID='3')
            if flags.get('mirror')=='on':
                target=next(d for d in devices if d['UUID']==flags['targetUUID'])
                rate=s.get('fractional_60',d['refreshRate']) if d['refreshRate']=='60Hz' else s.get('fractional_120',d['refreshRate'])
                target.update(resolution=d['resolution'],hiDPI=d['hiDPI'],refreshRate=rate,mirror='on')
        if s.get('ignore_default') and flags.get('displayModeNumber')=='1':
            selected[0]['displayModeNumber']='99'
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
        self.assertEqual((panel['resolution'],panel['hiDPI']),('3840x1080','on'))
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
        self.assertEqual((panel['resolution'],panel['hiDPI'],panel['refreshRate']),('3840x1080','on','120Hz'))
        self.assertNotIn('unrelated',[d['UUID'] for d in self.state['devices']])
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

    def test_disconnected_reset_removes_all_virtual_screens(self):
        self.assertEqual(self.invoke('set').returncode,0)
        self.state['devices']=[d for d in self.state['devices'] if d['UUID']!='panel']
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.state['devices'],[])

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

    def test_reset_removes_every_virtual_identity(self):
        self.state['devices'][1]['name']='G95-HiDPI'
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual([d['UUID'] for d in self.state['devices']],['panel'])

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
        result=self.invoke('set')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1]=='discard'])
        self.assertIn('unrelated',[d['UUID'] for d in self.state['devices']])

    def test_reset_clears_all_preferences_with_private_backup_and_repeats(self):
        self.state['preferences']={'hideMenuIcon':'true','oldSetting':'sentinel-private-value'}
        self.save()
        for _ in range(2):
            result=self.invoke('reset')
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertFalse(self.state['enable16K'])
            self.assertEqual(self.state['preferences'],{})
            self.assertEqual([d['UUID'] for d in self.state['devices']],['panel'])
            panel=self.state['devices'][0]
            self.assertEqual((panel['resolution'],panel['hiDPI'],panel['refreshRate']),
                             ('3840x1080','on','120Hz'))
            self.assertEqual(panel['mirror'],'off')
            self.assertEqual(panel['main'],'on')
        backups=list((self.root/'state/g95nc/backups').glob('*.plist'))
        self.assertEqual(len(backups),1)
        self.assertIn(b'sentinel-private-value',backups[0].read_bytes())
        self.assertEqual(backups[0].stat().st_mode & 0o777,0o600)
        for log in (self.root/'state/g95nc').glob('*.log'):
            self.assertNotIn('sentinel-private-value',log.read_text())

    def test_reset_restores_factory_edid_and_hidpi_without_native_signal(self):
        self.state.update(active_edid='custom-edid',unsupported_link=True)
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.state['active_edid'],'factory-edid')
        panel=self.state['devices'][0]
        self.assertEqual((panel['resolution'],panel['hiDPI'],panel['refreshRate']),
                         ('3840x1080','on','120Hz'))

    def test_reset_rejects_an_edid_override_that_did_not_clear(self):
        self.state.update(active_edid='custom-edid',ignore_factory_edid=True)
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn('factory EDID',result.stderr)

    def test_reset_requires_readable_factory_edid_on_odyssey(self):
        self.state['unreadable_edid']=True
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn('factory EDID',result.stderr)

    def test_reset_accepts_fractional_120_refresh(self):
        self.state['fractional_120']='119.88Hz'
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.state['devices'][0]['refreshRate'],'119.88Hz')

    def test_reset_reports_unavailable_hidpi_120_mode(self):
        self.state['missing_120']=True
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn('3840x1080 HiDPI at 120 Hz',result.stderr)

    def test_reset_works_when_app_stopped_or_preferences_missing(self):
        self.state.update(running=False,domain_exists=False,enable16K=False)
        self.state['devices']=[]
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertTrue(self.state['running'])

    def test_reset_accepts_an_empty_domain_still_listed_by_macos(self):
        self.state.update(running=False,domain_exists=True,preferences_cleared=True,enable16K=False,preferences={})
        self.state['devices']=[]
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertTrue(self.state['running'])

    def test_failed_backup_does_not_clear_configuration(self):
        self.state['backup_failure']=True
        self.save()
        result=self.invoke('reset')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertTrue(self.state['enable16K'])
        self.assertFalse([e for e in self.events() if e[:2]==['defaults','delete']])

    def test_failed_preference_deletion_is_not_success(self):
        self.state['delete_failure']=True
        self.save()
        self.assertEqual(self.invoke('reset').returncode,1)
        self.assertTrue(self.state['enable16K'])

    def test_reset_verifies_the_default_mode_was_applied(self):
        self.state['devices'][0]['name']='Other monitor'
        self.state['ignore_default']=True
        self.save()
        self.assertEqual(self.invoke('reset').returncode,1)

    def test_unsupported_output_is_rejected_before_any_mutation(self):
        self.state.update(unsupported_link=True,enable16K=False)
        self.save()
        for mode in ('set','butter'):
            result=self.invoke(mode)
            self.assertEqual(result.returncode,1,result.stdout+result.stderr)
            self.assertIn('7680x2160',result.stderr)
        self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1] in ('set','create','discard')])
        self.assertFalse([e for e in self.events() if e[0] in ('osascript','open') or e[:2]==['defaults','write']])

    def test_fractional_refresh_is_accepted_and_repeat_setup_is_read_only(self):
        self.state.update(fractional_60='59.97Hz',fractional_120='119.88Hz',native_refresh_override='59.97Hz')
        self.save()
        for mode,rate in (('set','59.97Hz'),('butter','119.88Hz')):
            self.state['native_refresh_override']=rate
            self.save()
            result=self.invoke(mode)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            (self.root/'events').write_text('')
            result=self.invoke(mode)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertFalse([e for e in self.events() if e[0]=='bd' and e[1] in ('set','create','discard')])

    def test_sharp_alias_and_setup_after_full_reset(self):
        for mode in ('reset','sharp','reset','butter','sharp'):
            result=self.invoke(mode)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_setup_establishes_sdr_full_chroma_output(self):
        self.state['devices'][0]['hdr']='on'
        self.state['encoding']='YCbCr 4:2:2 Limited'
        self.save()
        result=self.invoke('sharp')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.state['devices'][0]['hdr'],'off')
        self.assertEqual(self.state['encoding'],'RGB Full')

    def test_hidpi_framebuffer_on_low_resolution_signal_is_failure(self):
        self.state['downscaled_link']=True
        self.save()
        result=self.invoke('set')
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn('Setup failed',result.stdout)
        self.assertFalse([d for d in self.state['devices'] if d['deviceType']=='VirtualScreen'])

    def test_optimized_python_does_not_disable_native_verification(self):
        self.env['PYTHONOPTIMIZE']='1'
        self.state['reject_native']=True
        self.save()
        self.assertEqual(self.invoke('set').returncode,1)
